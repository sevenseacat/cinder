defmodule Cinder.Next.Component do
  @moduledoc """
  Spike: the stateful part of the new shell. Holds the config from
  `Cinder.Next.collection/1` and a `Cinder.Next.State`, and loads data through
  the existing `Cinder.QueryBuilder`.
  """
  use Phoenix.LiveComponent

  alias Cinder.Next.{State, View}
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
            sort: QueryBuilder.extract_query_sorts(config.query, config.engine_columns)
          )

        {:ok, socket |> assign(state: from_url(state, socket), page: nil) |> load()}

      state ->
        {:ok, apply_state(socket, from_url(state, socket))}
    end
  end

  @impl true
  def handle_event("sort", %{"field" => field}, socket) do
    case socket.assigns.config.fields[field] do
      %{sort: %{cycle: cycle}} -> {:noreply, commit(socket, &State.toggle_sort(&1, field, cycle))}
      _not_sortable -> {:noreply, socket}
    end
  end

  def handle_event("filter", params, socket) do
    columns = socket.assigns.config.engine_columns
    filters = FilterManager.params_to_filters(Map.get(params, "filters", %{}), columns)
    search = Map.get(params, "search", socket.assigns.state.search)
    sort = parse_sort(params["sort_by"], socket.assigns.config)

    {:noreply,
     commit(socket, fn state ->
       state = State.set_filters(state, filters, search)
       if sort, do: State.set_sort(state, sort), else: state
     end)}
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
  def handle_async(:load, {:ok, result}, socket), do: {:noreply, loaded(socket, result)}
  def handle_async(:load, {:exit, _reason}, socket), do: {:noreply, loaded(socket, :error)}

  defp loaded(socket, {:ok, page}), do: assign(socket, page: page, status: :idle)
  defp loaded(socket, _error), do: assign(socket, status: :error)

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :view, View.build(assigns))

    ~H"""
    <div id={@id} {@view.attrs}>
      <%= if @config.layout == :custom do %>
        <%!-- A custom layout: inputs anywhere in it join this form through `form=` --%>
        <form {@view.form_attrs}></form>
        {render_slot(@config.layout_slot, @view)}
      <% else %>
        <%!-- The default layout keeps the toolbar inside the form, so it works with any test tooling --%>
        <form {@view.form_attrs}>
          <%= if @config.toolbar_slot != [] do %>
            {render_slot(@config.toolbar_slot, @view)}
          <% else %>
            <Cinder.Next.toolbar collection={@view} />
          <% end %>
        </form>
        <Cinder.Next.results collection={@view} />
        <%!-- A region slot only renders when its region exists, so it never sees a nil pagination --%>
        <%= if @config.pagination_slot != [] do %>
          {@view.pagination && render_slot(@config.pagination_slot, @view)}
        <% else %>
          <Cinder.Next.pagination collection={@view} />
        <% end %>
      <% end %>
    </div>
    """
  end

  # The dropdown's value, in the URL's encoding: "" for none, "-field" for descending.
  # Only declared sorts are accepted; anything else leaves the sort alone.
  defp parse_sort(nil, _config), do: nil
  defp parse_sort("", _config), do: []

  defp parse_sort(value, config) do
    {field, direction} =
      case value do
        "-" <> field -> {field, :desc}
        field -> {field, :asc}
      end

    if field in config.sort_order, do: [{field, direction}]
  end

  # The one path for every user-driven state change. It loads straight away rather
  # than waiting for the URL to come back, so it works the same without URL sync.
  defp commit(socket, transition) do
    new = transition.(socket.assigns.state)
    changed? = State.query_changed?(socket.assigns.state, new)
    socket = apply_state(socket, new)

    if changed? and socket.assigns.url_params do
      params = State.to_url_params(new, socket.assigns.config.filter_order)
      send(self(), {:table_state_change, socket.assigns.id, params})
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
    State.from_url_params(state, params, config.engine_columns)
  end

  defp load(socket) do
    %{config: config, state: state} = socket.assigns

    opts =
      [
        scope: config.scope,
        action: config.action,
        query_opts: config.query_opts,
        columns: config.engine_columns,
        search_fn: config.search[:fn]
      ] ++ State.query_options(state)

    run = fn -> QueryBuilder.build_and_execute(config.query, opts) end
    socket = assign(socket, :status, :loading)

    # Ash's test helpers set this to make reads synchronous, as the current shell honours
    if Application.get_env(:ash, :disable_async?) do
      loaded(socket, run.())
    else
      start_async(socket, :load, run)
    end
  end
end
