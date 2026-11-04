# SPDX-FileCopyrightText: 2026 Cinder contributors <https://github.com/sevenseacat/cinder/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Cinder.Next.Collection do
  @moduledoc false
  # The LiveComponent behind `Cinder.Next.collection/1`: its config, what the user
  # has done (a `Cinder.Engine.Query`, for now), and the page of records it shows.

  use Phoenix.LiveComponent

  alias Cinder.Engine
  alias Cinder.Next.{Config, State}

  @impl true
  def update(assigns, socket) do
    # The fields' inner blocks are new on every parent render, so they're always
    # taken; the config is only rebuilt, and the records reloaded, when what's
    # declared changes. Every field is a column, for now.
    declarations = Config.declarations(assigns.options, assigns.fields)
    socket = assign(socket, id: assigns.id, columns: assigns.fields)

    if declarations == socket.assigns[:declarations] do
      {:ok, socket}
    else
      config = Config.build(assigns.options, assigns.fields)
      query = query(socket.assigns, config)
      {:ok, socket |> assign(declarations: declarations, config: config, query: query) |> load()}
    end
  end

  # A new collection starts with the default sort; when the declarations change
  # after mount, the user's sort carries over
  defp query(%{config: old, query: query}, config) do
    sortable = for %Engine.Field{sortable?: true, name: name} <- config.fields, do: name
    sort = State.carry_over_sort(query.sort, old.sort.default, config.sort.default, sortable)
    %{query | sort: sort}
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

  # Synchronous, and a failed read crashes, until the slices for loading states and
  # errors
  defp load(socket) do
    %{config: config, query: query} = socket.assigns
    opts = Map.take(config, [:actor, :tenant, :scope, :query_opts]) |> Enum.to_list()
    {:ok, page} = Engine.run(config.source, config.fields, query, opts)
    assign(socket, :page, page)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <table id={@id}>
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
