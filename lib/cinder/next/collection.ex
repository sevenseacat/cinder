# SPDX-FileCopyrightText: 2026 Cinder contributors <https://github.com/sevenseacat/cinder/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Cinder.Next.Collection do
  @moduledoc false
  # The LiveComponent behind `Cinder.Next.collection/1`: its config, what the user
  # has done (a `Cinder.Engine.Query`, for now), and the page of records it shows.

  use Phoenix.LiveComponent

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

  # A new collection starts with the default sort; when the declarations change
  # after mount, the user's sort and filters carry over
  defp query(%{config: old, query: query}, config) do
    sortable = for %Engine.Field{sortable?: true, name: name} <- config.fields, do: name
    filterable = for %{column: column} <- config.filters, do: column.field
    sort = State.carry_over_sort(query.sort, old.sort.default, config.sort.default, sortable)
    %{query | sort: sort, filters: State.carry_over_filters(query.filters, filterable)}
  end

  defp query(_assigns, config), do: %Engine.Query{sort: config.sort.default}

  @impl true
  def handle_event("sort", %{"field" => field}, socket) do
    %{config: config, query: query} = socket.assigns

    # A field that isn't a sortable column (from a tampered event) is ignored
    case Enum.find(config.columns, &(&1.field == field and &1.sort != nil)) do
      nil ->
        {:noreply, socket}

      column ->
        sort = State.toggle_sort(query.sort, field, column.sort.cycle, config.sort.mode)
        {:noreply, socket |> assign(:query, %{query | sort: sort}) |> load()}
    end
  end

  # Input for fields that aren't filtered (from a tampered event) is left out
  def handle_event("filter", params, socket) do
    %{config: config, query: query} = socket.assigns
    filters = Params.filters_from_params(params["filters"] || %{}, config.fields)
    {:noreply, socket |> assign(:query, %{query | filters: filters}) |> load()}
  end

  # Synchronous, and a failed read crashes, until the slices for loading states and
  # errors. The controls' values are worked out here, with the records, rather than
  # in `render/1`, where they'd be new on every render.
  defp load(socket) do
    %{config: config, query: query} = socket.assigns
    opts = Map.take(config, [:actor, :tenant, :scope, :query_opts]) |> Enum.to_list()
    {:ok, page} = Engine.run(config.source, config.fields, query, opts)
    filter_values = Params.filter_values(query.filters, config.fields)
    assign(socket, page: page, filter_values: filter_values)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id={@id}>
      <form :if={@config.filters != []} id={"#{@id}-filters"} phx-change="filter" phx-target={@myself}>
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
    </div>
    """
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
