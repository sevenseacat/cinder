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
    # `render` is the `<:filter>` slot entry when it has an inner block to render instead.
    # `source` is :field for a filter, or :argument for a read action argument.
    defstruct [:type, :help, :render, source: :field, required?: false, options: []]
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
    # The layouts it can switch between (`:table` with columns, `:grid` with an item)
    layouts: [],
    default_layout: :table,
    # nil (fit as many as there's room for), a number, or breakpoints
    grid_columns: nil,
    columns: [],
    item_slot: [],
    # An inner block replaces the whole layout; `:toolbar` replaces only that region
    page_slot: [],
    # `nil`, or `%{field, direction, slot}`: rows grouped by a field on each page
    group: nil,
    # `false`, `true`, or a function of the record
    selectable: false,
    # Declared bulk actions in order, by name
    bulk_actions: [],
    toolbar_slot: [],
    search: %{enabled?: false},
    query_opts: [],
    page_size: 25,
    # :offset (numbered pages) or :keyset (cursors: previous and next only)
    pagination: :offset,
    pagination_slot: [],
    # The registry as the engine's column maps, built once
    engine_columns: [],
    # `<:argument>`s, which go to the read action rather than filtering a field
    argument_fields: []
  ]

  # `<:filter>` attrs that become the filter's options, as the engine expects them
  @filter_option_attrs [
    :options,
    :prompt,
    :placeholder,
    :operator,
    :match_mode,
    :case_sensitive,
    :max_results
  ]

  @doc "Builds the config from `Cinder.Next.collection/1`'s assigns."
  def build(assigns) do
    query =
      assigns[:query] || assigns[:resource] ||
        raise ArgumentError, "a :resource or :query is required"

    resource = Ash.Query.new(query).resource

    cols = Map.get(assigns, :col, [])
    filter_slots = Map.get(assigns, :filter, [])
    sort_slots = Map.get(assigns, :sort, [])
    argument_slots = Map.get(assigns, :argument, [])

    reject_duplicates!(filter_slots, "<:filter>")
    reject_duplicates!(sort_slots, "<:sort>")
    reject_duplicates!(Enum.map(argument_slots, &Map.put(&1, :field, &1.name)), "<:argument>")

    labels = declared_labels(cols ++ filter_slots ++ sort_slots)
    filter_decls = declarations(cols, :filter, filter_slots)
    sort_decls = declarations(cols, :sort, sort_slots)

    search_fields =
      Enum.uniq(
        option(assigns[:search], :fields, []) ++ for(col <- cols, col[:search], do: col.field)
      )

    filter_order = ordered_fields(filter_decls)
    sort_order = ordered_fields(sort_decls)
    # Layouts are inferred from the slots that render them, unless they're listed
    # (as they must be when the markup lives elsewhere, like a LiveView's template)
    explicit = explicit_layouts(assigns[:layouts])
    item? = (assigns[:item] || []) != [] or :grid in explicit
    declared = assigns[:layout] || List.first(explicit)
    {layout, grid_columns} = layout(declared, assigns[:grid_columns], item?)

    layouts =
      if explicit != [], do: explicit, else: layouts(layout, cols != [], item?)

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

    arguments = arguments(argument_slots, read_action(query, resource, assigns[:action]))

    for name <- Map.keys(arguments), Map.has_key?(fields, name) do
      raise ArgumentError, "#{inspect(name)} is declared as both an <:argument> and a field"
    end

    config = %__MODULE__{
      query: query,
      resource: resource,
      fields: Map.merge(fields, arguments),
      # Arguments come first: they're often required, and inputs to the whole query
      filter_order: Enum.map(argument_slots, & &1.name) ++ filter_order,
      sort_order: sort_order,
      columns:
        for(col <- cols, do: %Column{field: col.field, label: fields[col.field].label, slot: col}),
      search: search(assigns[:search], search_fields),
      layout: layout,
      layouts: layouts,
      # Also what a `<:page>` starts on: it renders `c.layout` itself
      default_layout: layout,
      grid_columns: grid_columns,
      item_slot: assigns[:item] || [],
      page_slot: assigns[:page] || [],
      group: group(assigns[:group] || []),
      selectable: assigns[:selectable] || false,
      bulk_actions: bulk_actions(assigns[:bulk_action] || []),
      toolbar_slot: assigns[:toolbar] || [],
      id: assigns[:id],
      form_id: assigns[:id] && "#{assigns[:id]}-filters",
      action: assigns[:action],
      scope: scope(assigns),
      query_opts: assigns[:query_opts] || [],
      page_size: assigns[:page_size] || 25,
      pagination: pagination_mode(assigns[:pagination_mode]),
      pagination_slot: assigns[:pagination] || []
    }

    %{
      config
      | engine_columns: engine_columns(config),
        argument_fields: Enum.map(argument_slots, & &1.name)
    }
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
      # Arguments go to the read action, so the engine mustn't filter on them
      filterable? = field.filter != nil and field.filter.source == :field

      %{
        field: name,
        label: field.label,
        filterable: filterable?,
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
    inferred =
      FilterManager.infer_filter_config(name, resource, %{
        filterable: true,
        filter_type: filter_type(slot[:type], name),
        filter_options: slot_options(slot)
      })

    %Filter{
      type: inferred.filter_type,
      options: inferred.filter_options,
      help: slot[:help],
      render: if(slot[:inner_block], do: slot)
    }
  end

  defp slot_options(slot) do
    for attr <- @filter_option_attrs, Map.has_key?(slot, attr) do
      {attr, if(attr in [:operator, :match_mode], do: to_atom(slot[attr]), else: slot[attr])}
    end
  end

  # `<:argument>`s as fields, inferring what they can from the action's own
  # declaration of the argument, the way filters infer from attributes
  defp arguments(slots, action) do
    Map.new(slots, fn slot ->
      argument =
        Enum.find(action.arguments, &(to_string(&1.name) == slot.name)) ||
          raise ArgumentError,
                "the #{inspect(action.name)} action has no argument #{inspect(slot.name)}"

      {type, options} = argument_input(argument)

      filter = %Filter{
        type: filter_type(slot[:type], slot.name) || type,
        options: Keyword.merge(options, slot_options(slot)),
        help: slot[:help],
        source: :argument,
        required?: not argument.allow_nil? and is_nil(argument.default)
      }

      label = slot[:label] || Helpers.humanize_embedded_field(slot.name)
      {slot.name, %Field{name: slot.name, label: label, filter: filter}}
    end)
  end

  # A choice of values is a select; numbers get a number input; anything else, text
  defp argument_input(%{constraints: constraints, type: type}) do
    cond do
      one_of = constraints[:one_of] ->
        {:select, options: Enum.map(one_of, &{to_string(&1), &1})}

      type in [Ash.Type.Integer, Ash.Type.Float, Ash.Type.Decimal] ->
        {:text, input_type: "number"}

      true ->
        {:text, []}
    end
  end

  # The read action the collection runs: the one asked for, the one a prepared
  # query already has, or the resource's primary read
  defp read_action(query, resource, action_name) do
    name =
      action_name ||
        (match?(%Ash.Query{action: %{}}, query) && query.action.name) ||
        Ash.Resource.Info.primary_action!(resource, :read).name

    Ash.Resource.Info.action(resource, name)
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

  @breakpoints [:xs, :sm, :md, :lg, :xl, :"2xl"]

  defp bulk_actions(slots) do
    actions =
      for slot <- slots do
        %{
          name: slot.name,
          action: slot.action,
          label: slot[:label] || Helpers.humanize_embedded_field(slot.name),
          confirm: slot[:confirm],
          action_opts: slot[:action_opts] || []
        }
      end

    case actions -- Enum.uniq_by(actions, & &1.name) do
      [] ->
        actions

      [duplicate | _] ->
        raise ArgumentError, "<:bulk_action> name #{inspect(duplicate.name)} is declared twice"
    end
  end

  # One group for now (the shape stays open to nesting later)
  defp group([]), do: nil

  defp group([slot | _]) do
    direction =
      case slot[:sort] do
        sort when sort in [nil, :asc, "asc"] -> :asc
        sort when sort in [:desc, "desc"] -> :desc
      end

    %{field: slot.field, direction: direction, slot: slot}
  end

  defp explicit_layouts(nil), do: []

  defp explicit_layouts(layouts) do
    for layout <- layouts do
      case to_string(layout) do
        "table" ->
          :table

        "grid" ->
          :grid

        other ->
          raise ArgumentError,
                "unknown layout #{inspect(other)} in layouts; they're :table and :grid"
      end
    end
  end

  defp pagination_mode(mode) when mode in [nil, :offset, "offset"], do: :offset
  defp pagination_mode(mode) when mode in [:keyset, "keyset"], do: :keyset

  defp pagination_mode(mode) do
    raise ArgumentError,
          "unknown pagination_mode #{inspect(mode)}; it's :offset or :keyset (or their strings)"
  end

  # `:list` is a one-column grid, the same way `actor`/`tenant` become a scope:
  # nothing past here sees it. A list with `grid_columns` contradicts itself.
  defp layout(layout, nil, _item?) when layout in [nil, :table, "table"], do: {:table, nil}
  defp layout(layout, nil, _item?) when layout in [:list, "list"], do: {:grid, 1}

  defp layout(layout, columns, _item?) when layout in [:grid, "grid"],
    do: {:grid, grid_columns(columns)}

  # A table with an `<:item>` can switch to a grid, which takes the columns
  defp layout(layout, columns, true) when layout in [nil, :table, "table"],
    do: {:table, grid_columns(columns)}

  defp layout(layout, _columns, _item?) when layout in [:list, "list"] do
    raise ArgumentError, "a list is one column, so it can't take grid_columns. Use layout={:grid}"
  end

  defp layout(layout, _columns, _item?) when layout in [nil, :table, "table"] do
    raise ArgumentError,
          "grid_columns only applies to grids: use layout={:grid}, or declare an <:item> to switch to one"
  end

  defp layout(layout, _columns, _item?) do
    raise ArgumentError,
          "unknown layout #{inspect(layout)}. Known layouts: :table, :grid, :list " <>
            "(for your own page markup, use a <:page> slot)"
  end

  # A table needs columns and a grid an item; the declared layout is always one
  defp layouts(layout, cols?, item?) do
    for candidate <- [:table, :grid],
        candidate == layout or (candidate == :table and cols?) or (candidate == :grid and item?),
        do: candidate
  end

  defp grid_columns(nil), do: nil
  defp grid_columns(count) when is_integer(count) and count > 0, do: count

  defp grid_columns(breakpoints) when is_list(breakpoints) do
    for {breakpoint, count} <- breakpoints do
      unless breakpoint in @breakpoints and is_integer(count) and count > 0 do
        raise ArgumentError,
              "grid_columns breakpoints are #{inspect(@breakpoints)} with positive counts, " <>
                "got #{inspect({breakpoint, count})}"
      end

      {breakpoint, count}
    end
  end

  defp grid_columns(other) do
    raise ArgumentError,
          "grid_columns takes a positive number or breakpoints, got #{inspect(other)}"
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
