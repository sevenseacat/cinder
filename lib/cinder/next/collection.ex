# SPDX-FileCopyrightText: 2026 Cinder contributors <https://github.com/sevenseacat/cinder/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Cinder.Next.Collection do
  @moduledoc false
  # The LiveComponent behind `Cinder.Next.collection/1`: its config, and the page of
  # records it shows.

  use Phoenix.LiveComponent

  alias Cinder.Engine
  alias Cinder.Next.Config

  @impl true
  def update(assigns, socket) do
    # The columns' inner blocks are new on every parent render, so they're always
    # taken; the config is only rebuilt, and the records reloaded, when what's
    # declared changes
    declarations = Config.declarations(assigns.options, assigns.columns)
    socket = assign(socket, id: assigns.id, columns: assigns.columns)

    if declarations == socket.assigns[:declarations] do
      {:ok, socket}
    else
      config = Config.build(assigns.options, assigns.columns)
      {:ok, socket |> assign(declarations: declarations, config: config) |> load()}
    end
  end

  # Synchronous, and a failed read crashes, until the slices for loading states and
  # errors
  defp load(socket) do
    %{config: config} = socket.assigns
    opts = Map.take(config, [:actor, :tenant, :scope, :query_opts]) |> Enum.to_list()
    {:ok, page} = Engine.run(config.source, config.fields, %Engine.Query{}, opts)
    assign(socket, :page, page)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <table id={@id}>
      <thead>
        <tr>
          <th :for={column <- @config.columns}>{column.label}</th>
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
end
