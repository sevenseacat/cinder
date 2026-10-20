defmodule Cinder.Next.State do
  @moduledoc """
  The query state of a collection: filters, search, sort and page. Pure data, so
  every transition is testable without a socket.

  Any transition that changes which records match (filters, search, sort, page
  size) also goes back to the first page, so callers can't forget to.
  """

  alias Cinder.{QueryBuilder, UrlManager}

  @type sort :: [{String.t(), :asc | :desc}]

  @type t :: %__MODULE__{
          filters: %{String.t() => map()},
          search: String.t(),
          sort: sort(),
          page: pos_integer(),
          page_size: pos_integer(),
          default_sort: sort(),
          default_page_size: pos_integer()
        }

  defstruct filters: %{},
            search: "",
            sort: [],
            page: 1,
            page_size: 25,
            default_sort: [],
            default_page_size: 25

  @doc "A fresh state. `:page_size` and `:sort` are also what an empty URL goes back to."
  def new(opts \\ []) do
    page_size = Keyword.get(opts, :page_size, 25)
    sort = Keyword.get(opts, :sort, [])

    %__MODULE__{
      page_size: page_size,
      default_page_size: page_size,
      sort: sort,
      default_sort: sort
    }
  end

  @doc "Sets filters and search together, as one form submission carries both."
  def set_filters(state, filters, search) do
    reset_if_changed(state, %{state | filters: filters, search: search || ""})
  end

  def clear_filter(state, "search"), do: set_filters(state, state.filters, "")

  def clear_filter(state, field),
    do: set_filters(state, Map.delete(state.filters, field), state.search)

  def clear_all(state), do: set_filters(state, %{}, "")

  @doc "Cycles a field's sort, using the column's sort cycle if it has one."
  def toggle_sort(state, field, cycle \\ nil, mode \\ :additive) do
    sort = QueryBuilder.toggle_sort_with_cycle(state.sort, field, cycle, mode)
    reset_if_changed(state, %{state | sort: sort})
  end

  def go_to_page(state, page) when is_integer(page) and page > 0, do: %{state | page: page}
  def go_to_page(state, _page), do: state

  def set_page_size(state, size) when is_integer(size) and size > 0 do
    reset_if_changed(state, %{state | page_size: size})
  end

  @doc "Whether two states would query different records."
  def query_changed?(a, b), do: query_key(a) != query_key(b)

  @doc "Options for `Cinder.QueryBuilder.build_and_execute/2`."
  def query_options(state) do
    [
      filters: state.filters,
      search_term: state.search,
      sort_by: state.sort,
      current_page: state.page,
      page_size: state.page_size
    ]
  end

  @doc "URL params for this state, in the format `Cinder.UrlSync` expects."
  def to_url_params(state, filter_fields) do
    UrlManager.encode_state(%{
      filters: state.filters,
      search_term: state.search,
      sort_by: state.sort,
      current_page: state.page,
      page_size: state.page_size,
      default_page_size: state.default_page_size,
      filter_field_names: filter_fields
    })
  end

  @doc """
  Replaces the state's query with the one in the URL. Params the URL doesn't
  have fall back to the defaults, so removing them from the URL clears them.
  """
  def from_url_params(state, params, columns) do
    decoded = UrlManager.decode_state(params, columns)

    %{
      state
      | filters: decoded.filters,
        search: decoded.search_term,
        sort: if(Map.has_key?(params, "sort"), do: decoded.sort_by, else: state.default_sort),
        page: decoded.current_page,
        page_size:
          if(Map.has_key?(params, "page_size"),
            do: decoded.page_size,
            else: state.default_page_size
          )
    }
  end

  defp reset_if_changed(old, new) do
    if query_changed?(%{old | page: 1}, %{new | page: 1}), do: %{new | page: 1}, else: new
  end

  defp query_key(state),
    do: {state.filters, state.search, state.sort, state.page, state.page_size}
end
