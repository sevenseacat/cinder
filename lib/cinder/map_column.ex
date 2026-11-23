defmodule Cinder.MapColumn do
  @moduledoc """
  Helpers for rendering table columns backed by keys inside a JSONB `:map`
  attribute — a "map column" — so a resource can expose an open-ended,
  data-driven set of columns without a schema change per key.

  A *descriptor* is a plain map describing one key of the map attribute:

      %{key: "colour", type: :single_select, label: "Colour", options: ["red", "green"]}

  Supported `:type`s: `:text`, `:number`, `:date`, `:boolean`, `:single_select`,
  `:multi_select`, `:date_range`, `:number_range`. `:options` is only read for
  the select types. Slots stay the caller's: emit one `<:col>` per descriptor
  and delegate its `field`/`sort`/`filter`/body to the functions here:

      <:col
        :for={descriptor <- @descriptors}
        :let={record}
        field={Cinder.MapColumn.field(descriptor, :custom_fields)}
        label={descriptor.label}
        sort={Cinder.MapColumn.sortable?(descriptor)}
        filter={Cinder.MapColumn.filter(descriptor, :custom_fields)}
      >
        {Cinder.MapColumn.display(record, descriptor, :custom_fields)}
      </:col>

  Cinder already resolves a `field="source__key"` name to a JSONB `get_path`, so
  `field/2` builds that name and sort works for free. Filtering values that are
  not stored as text (numbers, dates, booleans, arrays) needs a cast in SQL, so
  `filter/2` attaches a custom `fn` for those, and for single-selects, which are
  filtered on several values at once; text compares as text and reuses the
  built-in filter unchanged.
  """

  require Ash.Expr
  require Ash.Query

  @typedoc "One key of a JSONB map attribute, described for the table."
  @type descriptor :: %{
          required(:key) => String.t(),
          required(:type) => atom(),
          required(:label) => String.t(),
          optional(:options) => [String.t()]
        }

  @doc """
  The Cinder field name for a descriptor. Ranges sort/filter on their `from`
  bound, everything else on the scalar value.
  """
  @spec field(descriptor(), atom()) :: String.t()
  def field(%{type: type, key: key}, source) when type in [:date_range, :number_range] do
    "#{source}__#{key}__from"
  end

  def field(%{key: key}, source), do: "#{source}__#{key}"

  @doc "Whether a descriptor maps to a single sortable value (multi-selects do not)."
  @spec sortable?(descriptor()) :: boolean()
  def sortable?(%{type: :multi_select}), do: false
  def sortable?(_descriptor), do: true

  @doc """
  The Cinder `filter` config for a descriptor. Text compares a string param
  against the JSONB text, so the built-in filter works as-is. A single-select
  offers its options as a multi-select, matching rows whose value is any of the
  chosen ones. Number/date/boolean/multi-select bind a non-string param against
  `->>` (text) and would blow up in Postgrex, so those get a custom `fn` that
  casts the JSONB value in SQL — which also makes number ranges compare
  numerically, not lexically.
  """
  @spec filter(descriptor(), atom()) :: atom() | keyword()
  def filter(%{type: :text}, _source), do: :text

  def filter(%{type: :single_select, options: options, key: key}, source) do
    [
      type: :multi_select,
      options: select_options(options),
      fn: single_select_filter_fn(source, key)
    ]
  end

  def filter(%{type: :multi_select, options: options, key: key}, source) do
    [
      type: :multi_select,
      options: select_options(options),
      fn: multi_select_filter_fn(source, key)
    ]
  end

  def filter(%{type: :number, key: key}, source) do
    [type: :number_range, fn: number_filter_fn(source, key, :scalar)]
  end

  def filter(%{type: :number_range, key: key}, source) do
    [type: :number_range, fn: number_filter_fn(source, key, :range)]
  end

  def filter(%{type: :date, key: key}, source) do
    [type: :date_range, fn: date_filter_fn(source, key, :scalar)]
  end

  def filter(%{type: :date_range, key: key}, source) do
    [type: :date_range, fn: date_filter_fn(source, key, :range)]
  end

  def filter(%{type: :boolean, key: key}, source) do
    [type: :boolean, fn: boolean_filter_fn(source, key)]
  end

  @doc "Formats a record's stored value for a descriptor as display text."
  @spec display(map(), descriptor(), atom()) :: String.t()
  def display(record, %{type: :boolean, key: key}, source) do
    if value_at(record, source, key) == true, do: "✓", else: "—"
  end

  def display(record, %{type: :multi_select, key: key}, source) do
    case value_at(record, source, key) do
      list when is_list(list) -> Enum.join(list, ", ")
      _ -> ""
    end
  end

  def display(record, %{type: type, key: key}, source)
      when type in [:date_range, :number_range] do
    case value_at(record, source, key) do
      %{} = range ->
        from = Map.get(range, "from")
        to = Map.get(range, "to")
        Enum.map_join([from, to], " – ", &(&1 || "…"))

      _ ->
        ""
    end
  end

  def display(record, %{key: key}, source) do
    case value_at(record, source, key) do
      nil -> ""
      value -> to_string(value)
    end
  end

  # ── Internals ──

  defp value_at(record, source, key) do
    record
    |> Map.get(source)
    |> Kernel.||(%{})
    |> Map.get(key)
  end

  defp select_options(options), do: Enum.map(options, &{&1, &1})

  # ── Custom filter functions (cast the JSONB value so params bind correctly) ──

  defp number_filter_fn(source, key, mode) do
    fn query, %{value: %{min: min, max: max}} ->
      query
      |> number_bound(source, key, mode, ">=", min)
      |> number_bound(source, key, mode, "<=", max)
    end
  end

  defp number_bound(query, _source, _key, _mode, _op, bound) when bound in [nil, ""], do: query

  defp number_bound(query, source, key, mode, op, bound) do
    case Float.parse(bound) do
      {number, _rest} -> filter_number(query, source, key, mode, op, number)
      :error -> query
    end
  end

  defp filter_number(query, source, key, :scalar, ">=", number) do
    import Ash.Expr
    Ash.Query.filter(query, fragment("(? ->> ?)::numeric >= ?", ^ref(source), ^key, ^number))
  end

  defp filter_number(query, source, key, :scalar, "<=", number) do
    import Ash.Expr
    Ash.Query.filter(query, fragment("(? ->> ?)::numeric <= ?", ^ref(source), ^key, ^number))
  end

  defp filter_number(query, source, key, :range, ">=", number) do
    import Ash.Expr

    Ash.Query.filter(
      query,
      fragment("(? -> ? ->> 'from')::numeric >= ?", ^ref(source), ^key, ^number)
    )
  end

  defp filter_number(query, source, key, :range, "<=", number) do
    import Ash.Expr

    # The max bound constrains the stored range's upper bound (`to`), not `from`,
    # so a stored {from: 1, to: 100} is excluded by a max of 50.
    Ash.Query.filter(
      query,
      fragment("(? -> ? ->> 'to')::numeric <= ?", ^ref(source), ^key, ^number)
    )
  end

  # The stored JSONB value may be a bare date (`2026-03-15`) or a full datetime
  # (`2026-03-15T10:00:00Z`), while the filter's bounds are dates. Comparing them
  # as text drops same-day datetimes (`"2026-03-15T…" > "2026-03-15"`), so cast
  # both the stored value and the bound to `date` and compare by day.
  defp date_filter_fn(source, key, mode) do
    fn query, %{value: %{from: from, to: to}} ->
      query
      |> date_bound(source, key, mode, ">=", from)
      |> date_bound(source, key, mode, "<=", to)
    end
  end

  defp date_bound(query, _source, _key, _mode, _op, bound) when bound in [nil, ""], do: query

  # Postgrex will not encode a string as a `date` parameter, so bind a `Date`.
  defp date_bound(query, source, key, mode, op, bound) when is_binary(bound) do
    case bound |> String.slice(0, 10) |> Date.from_iso8601() do
      {:ok, date} -> date_bound(query, source, key, mode, op, date)
      {:error, _reason} -> query
    end
  end

  defp date_bound(query, source, key, :scalar, ">=", bound) do
    import Ash.Expr
    Ash.Query.filter(query, fragment("(? ->> ?)::date >= ?::date", ^ref(source), ^key, ^bound))
  end

  defp date_bound(query, source, key, :scalar, "<=", bound) do
    import Ash.Expr
    Ash.Query.filter(query, fragment("(? ->> ?)::date <= ?::date", ^ref(source), ^key, ^bound))
  end

  defp date_bound(query, source, key, :range, ">=", bound) do
    import Ash.Expr

    Ash.Query.filter(
      query,
      fragment("(? -> ? ->> 'from')::date >= ?::date", ^ref(source), ^key, ^bound)
    )
  end

  # The `to` bound constrains the stored range's upper bound (`to`), not `from`.
  defp date_bound(query, source, key, :range, "<=", bound) do
    import Ash.Expr

    Ash.Query.filter(
      query,
      fragment("(? -> ? ->> 'to')::date <= ?::date", ^ref(source), ^key, ^bound)
    )
  end

  defp boolean_filter_fn(source, key) do
    fn
      query, %{value: value} when is_boolean(value) ->
        import Ash.Expr
        Ash.Query.filter(query, fragment("(? ->> ?) = ?", ^ref(source), ^key, ^to_string(value)))

      query, _config ->
        query
    end
  end

  defp single_select_filter_fn(source, key) do
    fn
      query, %{value: values} when is_list(values) and values != [] ->
        import Ash.Expr

        Ash.Query.filter(
          query,
          fragment("(? ->> ?) = ANY(?::text[])", ^ref(source), ^key, ^values)
        )

      query, _config ->
        query
    end
  end

  # A multi-select stores a JSONB array. Match rows whose array contains ANY (or
  # ALL) of the selected values via `@>` containment — the built-in `in` filter
  # compares a scalar and never matches an array. (`@>` avoids the `?|` operator,
  # whose `?` collides with fragment placeholders.)
  defp multi_select_filter_fn(source, key) do
    fn
      query, %{value: values} = config when is_list(values) and values != [] ->
        apply_multi_select(query, source, key, values, Map.get(config, :match_mode, :any))

      query, _config ->
        query
    end
  end

  defp apply_multi_select(query, source, key, values, mode) do
    import Ash.Expr

    conditions =
      Enum.map(values, fn value ->
        expr(fragment("(? -> ?) @> to_jsonb(?::text)", ^ref(source), ^key, ^value))
      end)

    Ash.Query.filter(query, ^combine_conditions(conditions, mode))
  end

  defp combine_conditions([first | rest], :all) do
    Enum.reduce(rest, first, fn condition, acc -> Ash.Expr.expr(^acc and ^condition) end)
  end

  defp combine_conditions([first | rest], _any) do
    Enum.reduce(rest, first, fn condition, acc -> Ash.Expr.expr(^acc or ^condition) end)
  end
end
