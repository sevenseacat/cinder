defmodule Cinder.Next.Component do
  @moduledoc """
  Spike: `Cinder.Next.Collection` in a LiveComponent. The collection decides
  everything; this only carries out its effects (loading, URL patches) and renders.
  """
  use Phoenix.LiveComponent

  alias Cinder.Next.Collection

  # `url_params` is nil unless the collection is URL-synced. When it is, every
  # state change arrives here as a URL change, from our own events and from
  # browser back/forward alike.
  @impl true
  def update(%{config: config, url_params: url_params} = assigns, socket) do
    {collection, effects} =
      case socket.assigns[:collection] do
        nil -> Collection.new(assigns.id, config, url_params)
        collection -> Collection.apply_url(%{collection | config: config}, url_params)
      end

    {:ok, socket |> assign(:id, assigns.id) |> run(collection, effects)}
  end

  @impl true
  def handle_event(event, params, socket) do
    {collection, effects} = Collection.handle_event(socket.assigns.collection, event, params)
    {:noreply, run(socket, collection, effects)}
  end

  @impl true
  def handle_async(:load, {:ok, result}, socket),
    do:
      {:noreply, assign_collection(socket, Collection.loaded(socket.assigns.collection, result))}

  def handle_async(:load, {:exit, reason}, socket),
    do:
      {:noreply,
       assign_collection(socket, Collection.loaded(socket.assigns.collection, {:exit, reason}))}

  defp run(socket, collection, effects) do
    Enum.reduce(effects, assign_collection(socket, collection), fn
      :load, socket -> load(socket)
      {:url, params}, socket -> notify(socket, params)
    end)
  end

  defp notify(socket, params) do
    send(self(), {:table_state_change, socket.assigns.id, params})
    socket
  end

  defp load(socket) do
    collection = Collection.loading(socket.assigns.collection)
    run = Collection.load_fun(collection)
    socket = assign_collection(socket, collection)

    # Ash's test helpers set this to make reads synchronous, as the current shell honours
    if Application.get_env(:ash, :disable_async?) do
      assign_collection(socket, Collection.loaded(collection, run.()))
    else
      start_async(socket, :load, run)
    end
  end

  # The view-model is a socket assign, rebuilt only when the collection may have
  # changed. `assign/3` only marks it changed when the new one differs, so a
  # re-render that changes nothing (like our own URL patch coming back) sends nothing.
  # Built inside `render/1` instead, it was new every time, and everything was resent.
  defp assign_collection(socket, collection) do
    socket
    |> assign(:collection, collection)
    |> assign(:config, collection.config)
    |> assign(:view, Collection.view(collection, socket.assigns.myself))
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id={@id} {@view.attrs}>
      <%= if @config.page_slot != [] do %>
        <%!-- A `<:page>` places `<form {c.form_attrs}>` itself, so component
             libraries' inputs (which assume they're inside a form) work; inputs
             that can't be nested in it, like a teleported modal's, use `form=` --%>
        {render_slot(@config.page_slot, @view)}
      <% else %>
        <%!-- The default layout keeps the toolbar inside the form, so it works with any test tooling --%>
        <form {@view.form_attrs}>
          <%= if @config.toolbar_slot != [] do %>
            {render_slot(@config.toolbar_slot, @view)}
          <% else %>
            <Cinder.Next.toolbar collection={@view} />
          <% end %>
        </form>
        <Cinder.Next.bulk_bar collection={@view} />
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
end
