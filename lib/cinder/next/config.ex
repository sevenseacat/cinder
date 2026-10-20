defmodule Cinder.Next.Config do
  @moduledoc """
  Spike: a collection's static configuration, normalised from its slots.

  Query capabilities are declared separately from display: `<:filter>` and
  `<:sort>` slots are the full declarations, while `filter`, `sort` and `search`
  on a `<:col>` are shorthands for "this field, with defaults". All of them are
  merged here into one registry of `%Field{}`s keyed by field name, so the rest of
  the shell never sees slots. `<:col>` only describes display.

  A field's label is resolved once: the declaring slot's own `label`, else any
  label another declaration of that field gave, else the humanised field name.
  """
  use Cinder.Messages

  alias Cinder.FilterManager
  alias Cinder.Filter.Helpers
  alias Cinder.Filters.Registry

  defmodule Field do
    @moduledoc false
    @enforce_keys [:name, :label]
    defstruct [:name, :label, filter: nil, sort: nil, search?: false]
  end

  defmodule Filter do
    @moduledoc false
    @enforce_keys [:type]
    # `render` is the `<:filter>` slot entry when it has an inner block to render instead
    defstruct [:type, :help, :render, options: []]
  end

  defmodule Sort do
    @moduledoc false
    defstruct cycle: [nil, :asc, :desc]
  end

  defmodule Column do
    @moduledoc false
    @enforce_keys [:field, :label, :slot]
    defstruct [:field, :label, :slot]
  end

  @enforce_keys [:query, :resource, :fields]
  defstruct [
    :query,
    :resource,
    :fields,
    :id,
    :form_id,
    :action,
    # The only auth the engine sees; `actor`/`tenant` attrs are normalised into it
    :scope,
    filter_order: [],
    sort_order: [],
    layout: :table,
    columns: [],
    item_slot: [],
    search: %{enabled?: false},
    query_opts: [],
    page_size: 25,
    pagination_slot: [],
    # The registry as the engine's column maps, built once
    engine_columns: []
  ]

  # `<:filter>` attrs that become the filter's options, as the engine expects them
  @filter_option_attrs [:options, :prompt, :placeholder, :operator, :match_mode, :case_sensitive]

  @doc "Builds the config from `Cinder.Next.collection/1`'s assigns."
  def build(assigns) do
    query =
      assigns[:query] || assigns[:resource] ||
        raise ArgumentError, "a :resource or :query is required"

    resource = Ash.Query.new(query).resource

    cols = Map.get(assigns, :col, [])
    filter_slots = Map.get(assigns, :filter, [])
    sort_slots = Map.get(assigns, :sort, [])

    reject_duplicates!(filter_slots, "<:filter>")
    reject_duplicates!(sort_slots, "<:sort>")

    labels = declared_labels(cols ++ filter_slots ++ sort_slots)
    filter_decls = declarations(cols, :filter, filter_slots)
    sort_decls = declarations(cols, :sort, sort_slots)

    search_fields =
      Enum.uniq(
        option(assigns[:search], :fields, []) ++ for(col <- cols, col[:search], do: col.field)
      )

    filter_order = ordered_fields(filter_decls)
    sort_order = ordered_fields(sort_decls)

    fields =
      (Enum.map(cols, & &1.field) ++ filter_order ++ sort_order ++ search_fields)
      |> Enum.uniq()
      |> Map.new(fn name ->
        field = %Field{
          name: name,
          label: labels[name] || Helpers.humanize_embedded_field(name),
          filter: filter(declaration(filter_decls, name), name, resource),
          sort: sort(declaration(sort_decls, name)),
          search?: name in search_fields
        }

        {name, field}
      end)

    config = %__MODULE__{
      query: query,
      resource: resource,
      fields: fields,
      filter_order: filter_order,
      sort_order: sort_order,
      columns:
        for(col <- cols, do: %Column{field: col.field, label: fields[col.field].label, slot: col}),
      search: search(assigns[:search], search_fields),
      layout: layout(assigns[:layout]),
      item_slot: assigns[:item] || [],
      id: assigns[:id],
      form_id: assigns[:id] && "#{assigns[:id]}-filters",
      action: assigns[:action],
      scope: scope(assigns),
      query_opts: assigns[:query_opts] || [],
      page_size: assigns[:page_size] || 25,
      pagination_slot: assigns[:pagination] || []
    }

    %{config | engine_columns: engine_columns(config)}
  end

  # Either a scope, or an actor and/or tenant made into one (Ash implements
  # `Ash.Scope.ToOpts` for maps). Only the keys given go in, so an absent actor
  # isn't mistaken for an explicit `actor: nil`. Both at once would need
  # precedence rules, so it's an error instead.
  defp scope(assigns) do
    auth = for key <- [:actor, :tenant], assigns[key] != nil, into: %{}, do: {key, assigns[key]}

    case {assigns[:scope], auth} do
      {nil, auth} when auth == %{} -> nil
      {nil, auth} -> auth
      {scope, auth} when auth == %{} -> scope
      _both -> raise ArgumentError, "pass either a scope, or an actor and/or tenant, but not both"
    end
  end

  @doc """
  The fields as the column maps the existing engine (`QueryBuilder`,
  `FilterManager`, `UrlManager`) expects, so the spike needs no engine changes.
  """
  def engine_columns(%__MODULE__{fields: fields}) do
    for {name, field} <- fields do
      %{
        field: name,
        label: field.label,
        filterable: field.filter != nil,
        filter_type: field.filter && field.filter.type,
        filter_options: (field.filter && field.filter.options) || [],
        filter_fn: nil,
        searchable: field.search?,
        sortable: field.sort != nil,
        sort_cycle: (field.sort && field.sort.cycle) || [nil, :asc, :desc]
      }
    end
  end

  # `{field, slot}` for each explicit slot, and `{field, :shorthand}` for each
  # `<:col>` with the capability set to true
  defp declarations(cols, capability, slots) do
    for(col <- cols, col[capability] == true, do: {col.field, :shorthand}) ++
      for(slot <- slots, do: {slot.field, slot})
  end

  # The explicit slot for a field if there is one, else `:shorthand`, else nil
  defp declaration(decls, name) do
    Enum.find_value(decls, fn
      {^name, slot} when is_map(slot) -> slot
      _ -> nil
    end) || if(List.keymember?(decls, name, 0), do: :shorthand)
  end

  # Phoenix hands each slot type over as its own list, so the order *between*
  # shorthands and explicit slots is lost. Shorthands come first, in column order.
  defp ordered_fields(decls) do
    explicit = for {field, slot} <- decls, is_map(slot), do: field
    shorthand = for {field, :shorthand} <- decls, field not in explicit, do: field
    shorthand ++ explicit
  end

  defp filter(nil, _name, _resource), do: nil
  defp filter(:shorthand, name, resource), do: filter(%{}, name, resource)

  defp filter(slot, name, resource) do
    options =
      for attr <- @filter_option_attrs, Map.has_key?(slot, attr) do
        {attr, if(attr in [:operator, :match_mode], do: to_atom(slot[attr]), else: slot[attr])}
      end

    inferred =
      FilterManager.infer_filter_config(name, resource, %{
        filterable: true,
        filter_type: filter_type(slot[:type], name),
        filter_options: options
      })

    %Filter{
      type: inferred.filter_type,
      options: inferred.filter_options,
      help: slot[:help],
      render: if(slot[:inner_block], do: slot)
    }
  end

  # The string form of a type (`type="select"`) is matched against the known types,
  # rather than made into a new atom
  defp filter_type(type, name) when is_binary(type) do
    Enum.find(Registry.filter_types(), &(Atom.to_string(&1) == type)) ||
      raise ArgumentError,
            "unknown filter type #{inspect(type)} for the field #{inspect(name)}. " <>
              "Known types: #{Enum.map_join(Registry.filter_types(), ", ", &inspect/1)}"
  end

  defp filter_type(type, _name), do: type

  defp layout(layout) when layout in [nil, :table, "table"], do: :table
  defp layout(layout) when layout in [:grid, "grid"], do: :grid

  defp layout(layout) do
    raise ArgumentError, "unknown layout #{inspect(layout)}. Known layouts: :table, :grid"
  end

  defp to_atom(value) when is_binary(value), do: String.to_existing_atom(value)
  defp to_atom(value), do: value

  defp sort(nil), do: nil
  defp sort(:shorthand), do: %Sort{}
  defp sort(slot), do: %Sort{cycle: slot[:cycle] || [nil, :asc, :desc]}

  defp declared_labels(slots) do
    Enum.reduce(slots, %{}, fn slot, labels ->
      if slot[:label], do: Map.put_new(labels, slot.field, slot.label), else: labels
    end)
  end

  defp reject_duplicates!(slots, name) do
    for {field, count} <- Enum.frequencies_by(slots, & &1.field), count > 1 do
      raise ArgumentError, "#{name} is declared #{count} times for the field #{inspect(field)}"
    end
  end

  defp search(false, _fields), do: %{enabled?: false}
  defp search(_search, []), do: %{enabled?: false}

  defp search(search, _fields) do
    %{
      enabled?: true,
      label: option(search, :label, dgettext("cinder", "Search")),
      placeholder: option(search, :placeholder, dgettext("cinder", "Search...")),
      fn: option(search, :fn, nil)
    }
  end

  defp option(opts, key, default) when is_list(opts), do: Keyword.get(opts, key, default)
  defp option(_opts, _key, default), do: default
end
