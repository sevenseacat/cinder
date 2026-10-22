defmodule Cinder.Next.Schema do
  @moduledoc """
  Spike: the `Spark.Options` schemas for a collection's declarations, shared by the
  slots of `Cinder.Next.collection/1` and the keyword lists of
  `Cinder.Next.LiveView.assign_collection/4`, and checked once when the config is
  built. Options that are an atom accept their string form too (`type="select"`),
  and come out as the atom; strings are only matched against known values, never
  made into atoms.

  Rules that involve more than one option (a list can't take `grid_columns`, a
  scope and an actor together) stay in `Cinder.Next.Config`.
  """

  @layouts [:table, :grid, :list]

  @collection [
    id: [type: :string, doc: "The collection's DOM id, and the base of its form's"],
    resource: [type: :atom, doc: "The Ash resource to read"],
    query: [type: :any, doc: "An `Ash.Query` to start from, instead of a resource"],
    action: [type: :atom, doc: "The read action (default: the query's, else the primary read)"],
    scope: [type: :any, doc: "An `Ash.Scope.ToOpts` scope"],
    actor: [type: :any, doc: "Shorthand for a scope with only an actor"],
    tenant: [type: :any, doc: "Shorthand for a scope with only a tenant"],
    query_opts: [type: :keyword_list, doc: "`:load`, `:select`, `:timeout` and so on"],
    page_size: [type: :pos_integer, doc: "Records per page (default 25)"],
    url_state: [
      type: :any,
      doc: "From `Cinder.UrlSync.handle_params/3`, to keep state in the URL"
    ],
    pagination_mode: [
      type: {:custom, __MODULE__, :one_of, [[:offset, :keyset]]},
      doc: "`:offset` (numbered pages, the default) or `:keyset` (previous and next)"
    ],
    layout: [
      type: {:custom, __MODULE__, :layout, []},
      doc: "`:table`, `:grid` or `:list` (a one-column grid): how records show, at first"
    ],
    layouts: [
      type: {:list, {:custom, __MODULE__, :one_of, [[:table, :grid]]}},
      doc: "The layouts to switch between, when no slots say (inferred otherwise)"
    ],
    grid_columns: [
      type: {:custom, __MODULE__, :grid_columns, []},
      doc: "A grid's columns: a count, or per breakpoint (`[xs: 1, md: 3]`)"
    ],
    search: [
      type: {:custom, __MODULE__, :search, []},
      doc: "`false`, the fields to search, or `[fields:, label:, placeholder:, fn:]`"
    ],
    selectable: [
      type: {:or, [:boolean, {:fun, 1}]},
      doc: "Rows can be selected: `true`, or a function of the record"
    ]
  ]

  # `assign_collection/4`'s own options: the slots as keyword lists, and the URL.
  # Their entries are checked as slots once they've been turned into them.
  @live_view @collection ++
               [
                 url: [type: :boolean, doc: "Keep the collection's state in the URL"],
                 load: [type: :any, doc: "Shorthand for `query_opts: [load: ...]`"],
                 filters: [
                   type: :keyword_list,
                   doc: "`[field: type]` or `[field: [type: ..., options: ...]]`"
                 ],
                 arguments: [
                   type: :keyword_list,
                   doc:
                     "The action's arguments to take as inputs: `[name: type]` or `[name: [label: ...]]`"
                 ],
                 sorts: [
                   type: {:list, :any},
                   doc: "`[field]` or `[field: [label: ..., cycle: ...]]`"
                 ],
                 bulk_actions: [
                   type: :keyword_list,
                   doc: "`[name: action]` or `[name: [action: ..., confirm: ...]]`"
                 ],
                 group: [
                   type: {:or, [:atom, :keyword_list]},
                   doc: "A field to group each page's rows by, or `[field: ..., sort: :desc]`"
                 ]
               ]

  @slots %{
    col: [
      field: [type: :string, required: true],
      label: [type: :string],
      sort: [type: :boolean],
      filter: [type: :boolean],
      search: [type: :boolean]
    ],
    filter: [
      field: [type: :string, required: true],
      type: [type: {:custom, __MODULE__, :filter_type, []}],
      label: [type: :string],
      help: [type: :string],
      options: [type: {:list, :any}],
      prompt: [type: :string],
      placeholder: [type: :string],
      operator: [type: {:or, [:atom, :string]}],
      match_mode: [type: {:custom, __MODULE__, :one_of, [[:any, :all]]}],
      case_sensitive: [type: :boolean],
      max_results: [type: :pos_integer]
    ],
    argument: [
      name: [type: :string, required: true],
      type: [type: {:custom, __MODULE__, :filter_type, []}],
      label: [type: :string],
      help: [type: :string],
      options: [type: {:list, :any}],
      prompt: [type: :string],
      placeholder: [type: :string]
    ],
    sort: [
      field: [type: :string, required: true],
      label: [type: :string],
      cycle: [type: {:list, :any}]
    ],
    header: [
      field: [type: :string, required: true]
    ],
    bulk_action: [
      name: [type: :string, required: true],
      action: [type: {:or, [:atom, {:fun, 2}]}, required: true],
      label: [type: :string],
      confirm: [type: :string],
      action_opts: [type: :keyword_list]
    ],
    group: [
      field: [type: :string, required: true],
      sort: [type: {:custom, __MODULE__, :one_of, [[:asc, :desc]]}]
    ]
  }

  @doc """
  Checks a collection's assigns (attrs and slots), returning them with values
  normalised (string forms as atoms). Raises `ArgumentError` naming the
  declaration at fault.
  """
  def validate!(assigns) do
    given = for {key, _spec} <- @collection, assigns[key] != nil, do: {key, assigns[key]}

    assigns =
      Map.merge(assigns, Map.new(validate!(given, @collection, "<Cinder.Next.collection>")))

    Enum.reduce(@slots, assigns, fn {slot, schema}, assigns ->
      case assigns[slot] do
        entries when is_list(entries) and entries != [] ->
          Map.put(assigns, slot, Enum.map(entries, &validate_slot!(&1, slot, schema)))

        _none ->
          assigns
      end
    end)
  end

  @doc "`assign_collection/4`'s options, as Markdown for its docs."
  def live_view_docs, do: Spark.Options.docs(@live_view)

  @doc "Checks `assign_collection/4`'s options, before they become slots."
  def validate_live_view!(opts), do: validate!(opts, @live_view, "assign_collection")

  # A slot entry is a map with Phoenix's own keys; only the attrs are checked
  defp validate_slot!(entry, slot, schema) do
    attrs = entry |> Map.drop([:__slot__, :inner_block]) |> Map.to_list()
    name = entry[:field] || entry[:name]
    where = if name, do: "<:#{slot}> for #{inspect(name)}", else: "<:#{slot}>"

    Map.merge(entry, Map.new(validate!(attrs, schema, where)))
  end

  defp validate!(opts, schema, where) do
    case Spark.Options.validate(opts, schema) do
      {:ok, validated} -> validated
      {:error, error} -> raise ArgumentError, "#{where}: " <> Exception.message(error)
    end
  end

  @doc false
  # An atom from `values`, given as itself or as its string
  def one_of(value, values) when is_atom(value) do
    if value in values, do: {:ok, value}, else: one_of_error(value, values)
  end

  def one_of(value, values) when is_binary(value) do
    case Enum.find(values, &(Atom.to_string(&1) == value)) do
      nil -> one_of_error(value, values)
      atom -> {:ok, atom}
    end
  end

  def one_of(value, values), do: one_of_error(value, values)

  defp one_of_error(value, values),
    do: {:error, "expected one of #{inspect(values)} (or their strings), got: #{inspect(value)}"}

  @doc false
  # A layout, pointing a would-be custom layout at `<:page>`
  def layout(layout) when layout in [:custom, "custom"],
    do: {:error, "there's no custom layout: for your own page markup, use a <:page> slot"}

  def layout(layout), do: one_of(layout, @layouts)

  @doc false
  # A built-in type (atom or string) or a custom filter module; a string is matched
  # against the known types rather than made into an atom
  def filter_type(type) when is_atom(type), do: {:ok, type}

  def filter_type(type) when is_binary(type) do
    known = Cinder.Filters.Registry.filter_types()

    case Enum.find(known, &(Atom.to_string(&1) == type)) do
      nil -> {:error, "unknown filter type #{inspect(type)}. Known types: #{inspect(known)}"}
      atom -> {:ok, atom}
    end
  end

  def filter_type(type), do: {:error, "expected a filter type, got: #{inspect(type)}"}

  @breakpoints [:xs, :sm, :md, :lg, :xl, :"2xl"]

  @doc false
  # A positive count, or counts per breakpoint
  def grid_columns(count) when is_integer(count) and count > 0, do: {:ok, count}

  def grid_columns(breakpoints) when is_list(breakpoints) do
    if Enum.all?(
         breakpoints,
         &match?({bp, n} when bp in @breakpoints and is_integer(n) and n > 0, &1)
       ),
       do: {:ok, breakpoints},
       else:
         {:error,
          "expected a positive count, or breakpoints #{inspect(@breakpoints)} with positive counts, " <>
            "got: #{inspect(breakpoints)}"}
  end

  def grid_columns(other),
    do: {:error, "expected a positive count or breakpoints, got: #{inspect(other)}"}

  @search [
    fields: [type: {:list, {:or, [:string, :atom]}}],
    label: [type: :string],
    placeholder: [type: :string],
    fn: [type: {:fun, 3}]
  ]

  @doc false
  # `false`, a list of fields, or options (`fields`, `label`, `placeholder`, `fn`)
  def search(false), do: {:ok, false}

  def search(opts) when is_list(opts) do
    cond do
      Keyword.keyword?(opts) and opts != [] ->
        with {:ok, opts} <- Spark.Options.validate(opts, @search) do
          {:ok, Keyword.update(opts, :fields, [], &Enum.map(&1, fn f -> to_string(f) end))}
        end
        |> case do
          {:error, error} -> {:error, Exception.message(error)}
          ok -> ok
        end

      Enum.all?(opts, &(is_binary(&1) or is_atom(&1))) ->
        {:ok, [fields: Enum.map(opts, &to_string/1)]}

      true ->
        {:error, "expected false, a list of fields, or search options, got: #{inspect(opts)}"}
    end
  end

  def search(other),
    do: {:error, "expected false, a list of fields, or search options, got: #{inspect(other)}"}
end
