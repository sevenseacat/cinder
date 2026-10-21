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
  # state change arrives here as a URL change, from our own events (see `commit/2`)
  # and from browser back/forward alike, and loads only if the query changed.
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

        {:ok,
         socket |> assign(state: from_url(state, socket), page: nil) |> load() |> assign_view()}

      state ->
        {:ok, socket |> apply_state(from_url(state, socket)) |> assign_view()}
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
    raw = Map.get(params, "filters", %{})
    filters = FilterManager.params_to_filters(raw, columns)
    search = Map.get(params, "search", socket.assigns.state.search)
    sort = parse_sort(params["sort_by"], socket.assigns.config)

    {:noreply,
     commit(socket, fn state ->
       state =
         state
         |> State.set_filters(filters, search, raw)
         |> State.set_arguments(Map.new(socket.assigns.config.argument_fields, &{&1, raw[&1]}))

       if sort, do: State.set_sort(state, sort), else: state
     end)}
  end

  def handle_event("clear_all", _params, socket) do
    {:noreply, commit(socket, &State.clear_all/1)}
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
  def handle_async(:load, {:ok, result}, socket),
    do: {:noreply, socket |> loaded(result) |> assign_view()}

  def handle_async(:load, {:exit, _reason}, socket),
    do: {:noreply, socket |> loaded(:error) |> assign_view()}

  defp loaded(socket, {:ok, page}) do
    assign(socket, page: page, status: :idle, state: %{socket.assigns.state | errors: %{}})
  end

  # Errors about an argument filter belong on that filter, not the whole collection.
  # When every error does, the collection is `:invalid` (waiting on better input)
  # rather than `:error`.
  defp loaded(socket, {:error, error}) do
    arguments = socket.assigns.config.argument_fields

    {field_errors, other} =
      error
      |> List.wrap()
      |> Enum.flat_map(&Map.get(&1, :errors, [&1]))
      |> Enum.split_with(&(to_string(Map.get(&1, :field)) in arguments))

    errors =
      field_errors
      |> Enum.map(&AshPhoenix.FormData.Error.to_form_error/1)
      |> Enum.group_by(&to_string(elem(&1, 0)), &interpolate/1)

    status = if field_errors != [] and other == [], do: :invalid, else: :error

    assign(socket, page: nil, status: status, state: %{socket.assigns.state | errors: errors})
  end

  defp loaded(socket, _exit), do: assign(socket, status: :error)

  # A real version would hand these to the app's error translation, as forms do
  defp interpolate({_field, message, vars}) do
    Enum.reduce(vars, message, fn {key, value}, message ->
      String.replace(message, "%{#{key}}", to_string(value))
    end)
  end

  # The view-model is a socket assign, rebuilt only when something it depends on
  # may have changed. `assign/3` only marks it changed when the new one differs, so a
  # re-render that changes nothing (like our own URL patch coming back) sends nothing.
  # Built inside `render/1` instead, it was new every time, and everything was resent.
  defp assign_view(socket), do: assign(socket, :view, View.build(socket.assigns))

  @impl true
  def render(assigns) do
    ~H"""
    <div id={@id} {@view.attrs}>
      <%= if @config.layout == :custom do %>
        <%!-- A custom layout places `<form {c.form_attrs}>` itself, so component
             libraries' inputs (which assume they're inside a form) work; inputs
             that can't be nested in it, like a teleported modal's, use `form=` --%>
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

  # The one path for every user-driven state change. When URL-synced, the URL is
  # the source of truth: only the new params go out, and the state is applied (and
  # loaded) in `update/2` when they come back. Applying it here too would render
  # twice, because the patch re-renders the parent, and slot closures capture the
  # parent's assigns, so every cell would be sent again with the same rows.
  #
  # Raw form input isn't part of the query, so it's kept straight away either way.
  defp commit(socket, transition) do
    old = socket.assigns.state
    new = transition.(old)

    cond do
      not State.query_changed?(old, new) ->
        socket |> assign(:state, new) |> assign_view()

      socket.assigns.url_params ->
        params = State.to_url_params(new, socket.assigns.config.filter_order)
        send(self(), {:table_state_change, socket.assigns.id, params})
        socket |> assign(:state, %{old | raw: new.raw}) |> assign_view()

      true ->
        socket |> apply_state(new) |> assign_view()
    end
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
    State.from_url_params(state, params, config.engine_columns, config.argument_fields)
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
