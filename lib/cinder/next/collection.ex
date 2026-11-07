# SPDX-FileCopyrightText: 2026 Cinder contributors <https://github.com/sevenseacat/cinder/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Cinder.Next.Collection do
  @moduledoc false
  # The LiveComponent behind `Cinder.Next.collection/1`: its config, what the user
  # has done (a `Cinder.Engine.Query`, for now), and the page of records it shows.

  use Phoenix.LiveComponent
  use Cinder.Messages

  alias Cinder.{Engine, Params}
  alias Cinder.Next.{Config, State}

  # Filter types render with a theme's classes, until theming is redone
  @impl true
  def mount(socket), do: {:ok, assign(socket, :theme, Cinder.Theme.merge("default"))}

  @impl true
  def update(assigns, socket) do
    # The fields' inner blocks are new on every parent render, so they're always
    # taken; the config is only rebuilt, and the records reloaded, when what's
    # declared changes. Only the fields that are columns have cells.
    declarations = Config.declarations(assigns.options, assigns.fields)
    columns = Enum.reject(assigns.fields, &(&1[:column] == false))
    socket = assign(socket, id: assigns.id, columns: columns)

    if declarations == socket.assigns[:declarations] do
      {:ok, socket}
    else
      config = Config.build(assigns.options, assigns.fields)
      query = query(socket.assigns, config)
      {:ok, socket |> assign(declarations: declarations, config: config, query: query) |> load()}
    end
  end

  # A rebuild, when the declarations change after mount: the user's sort, filters
  # and search carry over, and the page too if the records would be the same
  defp query(%{config: old, query: query}, config) do
    sortable = for %Engine.Field{sortable?: true, name: name} <- config.fields, do: name
    filterable = for %{column: column} <- config.filters, do: column.field
    searchable = for %Engine.Field{searchable?: true, name: name} <- config.fields, do: name
    sort = State.carry_over_sort(query.sort, old.sort.default, config.sort.default, sortable)

    carried = %{
      query
      | sort: sort,
        filters: State.carry_over_filters(query.filters, filterable),
        search: State.carry_over_search(query.search, searchable),
        page_size: page_size(config)
    }

    State.carry_over_page(carried, query, read(old) == read(config))
  end

  # The first build, on mount, before there's a config or query: a new collection
  # starts on page 1 with the default sort
  defp query(_assigns, config) do
    %Engine.Query{sort: config.sort.default, page_size: page_size(config)}
  end

  # An action that doesn't page reads every record, whatever the size
  defp page_size(%{pagination: nil}), do: %Engine.Query{}.page_size
  defp page_size(%{pagination: pagination}), do: pagination.size

  # What decides the records read, besides the query
  defp read(config) do
    {Map.take(config, [:source, :actor, :tenant, :scope, :query_opts]), config.search[:fn]}
  end

  @impl true
  def handle_event("sort", %{"field" => field}, socket) do
    %{config: config, query: query} = socket.assigns

    # A field that isn't a sortable column (from a tampered event) is ignored
    case Enum.find(config.columns, &(&1.field == field and &1.sort != nil)) do
      nil ->
        {:noreply, socket}

      column ->
        sort = State.toggle_sort(query.sort, field, column.sort.cycle, config.sort.mode)
        {:noreply, socket |> assign(:query, State.first_page(%{query | sort: sort})) |> load()}
    end
  end

  # The search box is in the filter form. Input for fields that aren't filtered (from
  # a tampered event) is left out, and a search without a box searches nothing.
  def handle_event("filter", params, socket) do
    %{config: config, query: query} = socket.assigns
    filters = Params.filters_from_params(params["filters"] || %{}, config.fields)
    query = State.first_page(%{query | filters: filters, search: params["search"] || ""})
    {:noreply, socket |> assign(:query, query) |> load()}
  end

  # The page comes from the client, so one that isn't a positive number is ignored
  def handle_event("page", %{"page" => page}, socket) do
    case Integer.parse(page) do
      {page, ""} when page > 0 ->
        {:noreply, socket |> assign(:query, %{socket.assigns.query | page: page}) |> load()}

      _not_a_page ->
        {:noreply, socket}
    end
  end

  # Synchronous, and a failed read crashes, until the slices for loading states and
  # errors. The controls' values are worked out here, with the records, rather than
  # in `render/1`, where they'd be new on every render.
  defp load(socket) do
    %{config: config, query: query} = socket.assigns
    opts = Map.take(config, [:actor, :tenant, :scope, :query_opts]) |> Enum.to_list()
    opts = [search_fn: config.search[:fn], count?: config.pagination[:count?] == true] ++ opts
    {:ok, page} = Engine.run(config.source, config.fields, query, opts)
    filter_values = Params.filter_values(query.filters, config.fields)
    assign(socket, page: page, filter_values: filter_values)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id={@id}>
      <form
        :if={@config.filters != [] or @config.search != nil}
        id={"#{@id}-filters"}
        phx-change="filter"
        phx-target={@myself}
      >
        <div :if={@config.search}>
          <label for={"#{@id}-search"}>{@config.search.label || dgettext("cinder", "Search")}</label>
          <input
            type="search"
            id={"#{@id}-search"}
            name="search"
            value={@query.search}
            placeholder={@config.search.placeholder || dgettext("cinder", "Search...")}
            phx-debounce="300"
          />
        </div>
        <div :for={%{column: column, module: module} <- @config.filters}>
          <label for={Cinder.Filter.filter_id(@id, column.field)}>{column.label}</label>
          {module.render(column, @filter_values[column.field], @theme, %{
            table_id: @id,
            target: @myself,
            filter_values: @filter_values
          })}
        </div>
      </form>
      <table>
        <thead>
          <tr>
            <th
              :for={column <- @config.columns}
              aria-sort={column.sort && aria_sort(direction(@query.sort, column.field))}
            >
              <%= if column.sort do %>
                <button
                  type="button"
                  phx-click="sort"
                  phx-value-field={column.field}
                  phx-target={@myself}
                >
                  {column.label}{indicator(direction(@query.sort, column.field))}
                </button>
              <% else %>
                {column.label}
              <% end %>
            </th>
          </tr>
        </thead>
        <tbody>
          <tr :for={record <- @page.records}>
            <td :for={column <- @columns}>{render_slot(column, record)}</td>
          </tr>
        </tbody>
      </table>
      <nav :if={@page.page && (@page.previous? or @page.more?)} aria-label="Pagination">
        <button
          type="button"
          phx-click="page"
          phx-value-page={@page.page - 1}
          phx-target={@myself}
          disabled={!@page.previous?}
        >
          {dgettext("cinder", "Previous page")}
        </button>
        <span>{page_of(@page)}</span>
        <button
          type="button"
          phx-click="page"
          phx-value-page={@page.page + 1}
          phx-target={@myself}
          disabled={!@page.more?}
        >
          {dgettext("cinder", "Next page")}
        </button>
      </nav>
    </div>
    """
  end

  # Without a count (the action can't count), there's no total
  defp page_of(%{count: nil, page: page}) do
    dgettext("cinder", "Page %{current}", current: page)
  end

  defp page_of(%{count: count, page: page, page_size: size}) do
    total = max(ceil(count / size), 1)
    dgettext("cinder", "Page %{current} of %{total}", current: page, total: total)
  end

  defp direction(sort, field) do
    case List.keyfind(sort, field, 0) do
      {^field, direction} when direction in [:asc, :asc_nils_first, :asc_nils_last] -> :asc
      {^field, _descending} -> :desc
      nil -> nil
    end
  end

  defp aria_sort(:asc), do: "ascending"
  defp aria_sort(:desc), do: "descending"
  defp aria_sort(nil), do: "none"

  defp indicator(:asc), do: " ▲"
  defp indicator(:desc), do: " ▼"
  defp indicator(nil), do: nil
end
