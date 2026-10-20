defmodule Cinder.Next.Component do
  @moduledoc """
  Spike: the stateful part of the new shell. Holds the config from
  `Cinder.Next.collection/1` and a `Cinder.Next.State`, and loads data through
  the existing `Cinder.QueryBuilder`.
  """
  use Phoenix.LiveComponent

  alias Cinder.Next.{Parts, State, View}
  alias Cinder.QueryBuilder

  @impl true
  def update(%{config: config} = assigns, socket) do
    socket = assign(socket, id: assigns.id, config: config)

    if socket.assigns[:state] do
      {:ok, socket}
    else
      state =
        State.new(
          page_size: config.page_size,
          sort: QueryBuilder.extract_query_sorts(config.query, config.columns)
        )

      {:ok, socket |> assign(state: state, page: nil) |> load()}
    end
  end

  @impl true
  def handle_async(:load, {:ok, {:ok, page}}, socket) do
    {:noreply, assign(socket, page: page, status: :idle)}
  end

  def handle_async(:load, _error_or_exit, socket) do
    {:noreply, assign(socket, status: :error)}
  end

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :view, View.build(assigns))

    ~H"""
    <div id={@id} {@view.attrs}>
      <Parts.table view={@view} />
    </div>
    """
  end

  defp load(socket) do
    %{config: config, state: state} = socket.assigns

    opts =
      [
        actor: config.actor,
        tenant: config.tenant,
        scope: config.scope,
        action: config.action,
        query_opts: config.query_opts,
        columns: config.columns
      ] ++ State.query_options(state)

    socket
    |> assign(:status, :loading)
    |> start_async(:load, fn -> QueryBuilder.build_and_execute(config.query, opts) end)
  end
end
