defmodule Cinder.Next.Component do
  @moduledoc """
  Spike: the stateful part of the new shell. Holds the config from
  `Cinder.Next.collection/1` and a `Cinder.Next.State`, and loads data through
  the existing `Cinder.QueryBuilder`.
  """
  use Phoenix.LiveComponent

  alias Cinder.Next.{Parts, State, View}
  alias Cinder.{FilterManager, QueryBuilder}

  # `url_params` is nil unless the collection is URL-synced. When it is, every
  # URL change arrives here: our own patches (which match the state already, so
  # nothing reloads) and browser back/forward (which don't).
  @impl true
  def update(%{config: config, url_params: url_params} = assigns, socket) do
    socket = assign(socket, id: assigns.id, config: config, url_params: url_params)

    case socket.assigns[:state] do
      nil ->
        state =
          State.new(
            page_size: config.page_size,
            sort: QueryBuilder.extract_query_sorts(config.query, config.columns)
          )

        {:ok, socket |> assign(state: from_url(state, socket), page: nil) |> load()}

      state ->
        {:ok, apply_state(socket, from_url(state, socket))}
    end
  end

  @impl true
  def handle_event("sort", %{"field" => field}, socket) do
    case Enum.find(socket.assigns.config.columns, &(&1.field == field and &1.sortable)) do
      nil -> {:noreply, socket}
      column -> {:noreply, commit(socket, &State.toggle_sort(&1, field, column.sort_cycle))}
    end
  end

  def handle_event("filter", params, socket) do
    %{columns: columns} = socket.assigns.config
    filters = FilterManager.params_to_filters(Map.get(params, "filters", %{}), columns)
    search = Map.get(params, "search", socket.assigns.state.search)

    {:noreply, commit(socket, &State.set_filters(&1, filters, search))}
  end

  def handle_event("clear_filter", %{"field" => field}, socket) do
    {:noreply, commit(socket, &State.clear_filter(&1, field))}
  end

  def handle_event("go_to_page", %{"page" => page}, socket) do
    case Integer.parse(page) do
      {number, ""} -> {:noreply, commit(socket, &State.go_to_page(&1, number))}
      _ -> {:noreply, socket}
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
      <form {@view.form_attrs}></form>
      <Parts.toolbar view={@view} />
      <Parts.table view={@view} />
      <Parts.pagination :if={@view.pagination} pagination={@view.pagination} />
    </div>
    """
  end

  # The one path for every user-driven state change. It loads straight away rather
  # than waiting for the URL to come back, so it works the same without URL sync.
  defp commit(socket, transition) do
    new = transition.(socket.assigns.state)
    changed? = State.query_changed?(socket.assigns.state, new)
    socket = apply_state(socket, new)

    if changed? and socket.assigns.url_params do
      filter_fields =
        for column <- socket.assigns.config.columns, column.filterable, do: column.field

      send(
        self(),
        {:table_state_change, socket.assigns.id, State.to_url_params(new, filter_fields)}
      )
    end

    socket
  end

  defp apply_state(socket, new) do
    if State.query_changed?(socket.assigns.state, new) do
      socket |> assign(:state, new) |> load()
    else
      socket
    end
  end

  defp from_url(state, %{assigns: %{url_params: nil}}), do: state

  defp from_url(state, %{assigns: %{url_params: params, config: config}}) do
    State.from_url_params(state, params, config.columns)
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
        columns: config.columns,
        search_fn: config.search.fn
      ] ++ State.query_options(state)

    socket
    |> assign(:status, :loading)
    |> start_async(:load, fn -> QueryBuilder.build_and_execute(config.query, opts) end)
  end
end
