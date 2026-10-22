defmodule Cinder.Next.State do
  @moduledoc """
  The state of a collection: its query (filters, read action arguments, search,
  sort, page or cursor, page size), and what isn't query (the layout, the
  selection and a pending bulk action, raw form input, filter errors). Pure data,
  so every transition is testable without a socket.

  Any transition that changes which records match (filters, search, sort, page
  size) also goes back to the first page, so callers can't forget to.

  `raw` keeps the filter form's params as typed (`price_min`, `tags`, ...), so
  input that hasn't become a filter yet, or never will (half a range, an
  autocomplete's search text), survives a re-render. It isn't part of the query:
  changing it alone never reloads or touches the URL.
  """

  alias Cinder.{FilterManager, QueryBuilder, UrlManager}

  @type sort :: [{String.t(), :asc | :desc}]

  @type t :: %__MODULE__{
          filters: %{String.t() => map()},
          search: String.t(),
          sort: sort(),
          page: pos_integer(),
          cursor: nil | {:after | :before, String.t()},
          page_size: pos_integer(),
          default_sort: sort(),
          default_page_size: pos_integer(),
          raw: %{String.t() => term()},
          arguments: %{String.t() => String.t()},
          errors: %{String.t() => [String.t()]},
          layout: atom() | nil,
          default_layout: atom() | nil,
          layouts: [atom()],
          selected: MapSet.t(String.t()),
          pending_action: String.t() | nil
        }

  defstruct filters: %{},
            raw: %{},
            # Values for the read action's arguments: part of the query, like filters
            arguments: %{},
            # Per-filter messages from the last load (e.g. a required argument); not query
            errors: %{},
            search: "",
            sort: [],
            page: 1,
            # Keyset pagination's position instead of `page`: after or before a record
            cursor: nil,
            page_size: 25,
            default_sort: [],
            default_page_size: 25,
            # How the records are shown, from the layouts the collection can render. Not
            # part of the query: switching never reloads.
            layout: nil,
            default_layout: nil,
            layouts: [],
            # Ids of selected records, as strings. Not query and not in the URL: it
            # survives paging, sorting and filtering, so rows can be gathered across
            # searches.
            selected: MapSet.new(),
            # A bulk action waiting on its confirm, by name. Running one with a
            # `confirm` needs this set first, so a crafted event can't skip it.
            pending_action: nil

  @doc """
  A fresh state. `:page_size`, `:sort` and `:layout` are also what an empty URL goes
  back to; `:layouts` are the ones it can switch between.
  """
  def new(opts \\ []) do
    page_size = Keyword.get(opts, :page_size, 25)
    sort = Keyword.get(opts, :sort, [])
    layout = Keyword.get(opts, :layout)

    %__MODULE__{
      page_size: page_size,
      default_page_size: page_size,
      sort: sort,
      default_sort: sort,
      layout: layout,
      default_layout: layout,
      layouts: Keyword.get(opts, :layouts, [])
    }
  end

  @doc "Switches layout, to one of the collection's layouts (atom or string)."
  def set_layout(state, layout) do
    case find_layout(state, layout) do
      nil -> state
      layout -> %{state | layout: layout}
    end
  end

  @doc """
  Selects or deselects a record by id. Only ids in `selectable_ids` (those served
  on the current page, and selectable) can be added, so a client can't select a
  record it was never shown; anything can be deselected.
  """
  def toggle_selected(state, id, selectable_ids) do
    cond do
      MapSet.member?(state.selected, id) -> %{state | selected: MapSet.delete(state.selected, id)}
      id in selectable_ids -> %{state | selected: MapSet.put(state.selected, id)}
      true -> state
    end
  end

  @doc "Selects the whole page, or deselects it if it's all selected already."
  def toggle_page_selected(state, page_ids) do
    page = MapSet.new(page_ids)

    selected =
      if MapSet.size(page) > 0 and MapSet.subset?(page, state.selected),
        do: MapSet.difference(state.selected, page),
        else: MapSet.union(state.selected, page)

    %{state | selected: selected}
  end

  def clear_selected(state), do: %{state | selected: MapSet.new(), pending_action: nil}

  def request_action(state, name), do: %{state | pending_action: name}
  def cancel_action(state), do: %{state | pending_action: nil}

  # Matched against the known layouts, so a URL never creates an atom
  defp find_layout(state, layout),
    do: Enum.find(state.layouts, &(&1 == layout or to_string(&1) == layout))

  @doc """
  Sets filters and search together, as one form submission carries both, along
  with the form's raw params when there are any.
  """
  def set_filters(state, filters, search, raw \\ nil) do
    new = %{state | filters: filters, search: search || "", raw: raw || state.raw}
    reset_if_changed(state, new)
  end

  def clear_filter(state, "search"), do: set_filters(state, state.filters, "")

  def clear_filter(state, field) do
    raw = Map.reject(state.raw, fn {key, _value} -> param_field?(key, field) end)

    state
    |> set_filters(Map.delete(state.filters, field), state.search, raw)
    |> set_arguments(Map.delete(state.arguments, field))
  end

  def clear_all(state), do: %{set_arguments(set_filters(state, %{}, ""), %{}) | raw: %{}}

  @doc "Sets the read action's argument values. Blank ones are left out."
  def set_arguments(state, arguments) do
    arguments = Map.reject(arguments, fn {_name, value} -> value in [nil, ""] end)
    reset_if_changed(state, %{state | arguments: arguments})
  end

  @doc "Whether a form param (`price_min`, `tags`) belongs to a field (`price`, `tags`)."
  def param_field?(param, field), do: param == field or String.starts_with?(param, field <> "_")

  @doc "Cycles a field's sort, using the column's sort cycle if it has one."
  def toggle_sort(state, field, cycle \\ nil, mode \\ :additive) do
    sort = QueryBuilder.toggle_sort_with_cycle(state.sort, field, cycle, mode)
    reset_if_changed(state, %{state | sort: sort})
  end

  @doc "Replaces the whole sort, as an exclusive sort control (a dropdown) does."
  def set_sort(state, sort), do: reset_if_changed(state, %{state | sort: sort})

  def go_to_page(state, page) when is_integer(page) and page > 0, do: %{state | page: page}
  def go_to_page(state, _page), do: state

  @doc "Moves to the keyset page after or before a record's cursor."
  def go_to_cursor(state, direction, cursor)
      when direction in [:after, :before] and is_binary(cursor) and cursor != "",
      do: %{state | cursor: {direction, cursor}}

  def go_to_cursor(state, _direction, _cursor), do: state

  def set_page_size(state, size) when is_integer(size) and size > 0 do
    reset_if_changed(state, %{state | page_size: size})
  end

  @doc "Whether two states would query different records."
  def query_changed?(a, b), do: query_key(a) != query_key(b)

  @doc "Options for `Cinder.QueryBuilder.build_and_execute/2`."
  def query_options(state) do
    [
      filters: state.filters,
      arguments: state.arguments,
      search_term: state.search,
      sort_by: state.sort,
      current_page: state.page,
      page_size: state.page_size,
      after_keyset: cursor(state, :after),
      before_keyset: cursor(state, :before)
    ]
  end

  @doc "URL params for this state, in the format `Cinder.UrlSync` expects."
  def to_url_params(state, filter_fields) do
    # Argument values go in under their own names, like a text filter's would
    arguments = Map.new(state.arguments, fn {name, value} -> {String.to_atom(name), value} end)

    # `Cinder.UrlSync` keeps any param it isn't told the collection manages, so a
    # switchable collection names `layout`, or going back to the default (which
    # leaves it out) would keep the old one. Only when switchable, so an app's own
    # `layout` param survives otherwise.
    managed = if length(state.layouts) > 1, do: filter_fields ++ ["layout"], else: filter_fields

    %{
      filters: state.filters,
      search_term: state.search,
      sort_by: state.sort,
      current_page: state.page,
      after: cursor(state, :after),
      before: cursor(state, :before),
      page_size: state.page_size,
      default_page_size: state.default_page_size,
      filter_field_names: managed
    }
    |> UrlManager.encode_state()
    |> Map.merge(arguments)
    |> then(
      &if(state.layout == state.default_layout, do: &1, else: Map.put(&1, :layout, state.layout))
    )
  end

  @doc """
  Replaces the state's query with the one in the URL. Params the URL doesn't
  have fall back to the defaults, so removing them from the URL clears them.
  """
  def from_url_params(state, params, columns, argument_fields \\ []) do
    decoded = UrlManager.decode_state(params, columns)

    %{
      state
      | filters: decoded.filters,
        arguments:
          Map.new(
            for name <- argument_fields, params[name] not in [nil, ""], do: {name, params[name]}
          ),
        raw: current_raw(state.raw, decoded.filters, columns),
        search: decoded.search_term,
        sort: if(Map.has_key?(params, "sort"), do: decoded.sort_by, else: state.default_sort),
        page: decoded.current_page,
        cursor:
          cond do
            decoded.after -> {:after, decoded.after}
            decoded.before -> {:before, decoded.before}
            true -> nil
          end,
        page_size:
          if(Map.has_key?(params, "page_size"),
            do: decoded.page_size,
            else: state.default_page_size
          ),
        layout: find_layout(state, params["layout"]) || state.default_layout
    }
  end

  # Raw input is kept only for fields where it still describes the filter the URL
  # has. On browser back/forward it usually doesn't, and the URL wins.
  defp current_raw(raw, filters, columns) do
    from_raw = FilterManager.params_to_filters(raw, columns)

    Map.filter(raw, fn {param, _value} ->
      case Enum.find(columns, &(&1.filterable and param_field?(param, &1.field))) do
        nil -> false
        column -> from_raw[column.field] == filters[column.field]
      end
    end)
  end

  defp cursor(%{cursor: {direction, cursor}}, direction), do: cursor
  defp cursor(_state, _direction), do: nil

  defp reset_if_changed(old, new) do
    first = &%{&1 | page: 1, cursor: nil}
    if query_changed?(first.(old), first.(new)), do: first.(new), else: new
  end

  defp query_key(state) do
    {state.filters, state.arguments, state.search, state.sort, state.page, state.cursor,
     state.page_size}
  end
end
