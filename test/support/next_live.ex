defmodule Cinder.TestLive.NextLiveView do
  @moduledoc """
  A LiveView keeping a `Cinder.Next` collection in its own assigns, through
  `use Cinder.Next.LiveView`, with an event of its own alongside the hook's.
  """
  use Phoenix.LiveView, layout: false
  use Cinder.Next.LiveView

  alias Cinder.Next.LiveView, as: Collections

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:pings, 0)
     |> Collections.assign_collection(:albums, Ash.Query.sort(Music.Album, :title),
       url: true,
       page_size: 2,
       layouts: [:grid],
       selectable: true,
       filters: [genre: :select],
       sorts: [:title],
       bulk_actions: [remaster: :remaster]
     )}
  end

  @impl true
  def handle_params(_params, _uri, socket), do: {:noreply, socket}

  # The app's own event: the hook passes it through untouched
  @impl true
  def handle_event("ping", _params, socket), do: {:noreply, update(socket, :pings, &(&1 + 1))}

  @impl true
  def render(assigns) do
    ~H"""
    <button id="ping" phx-click="ping">Ping ({@pings})</button>
    <form {@albums.form_attrs}>
      <Cinder.Next.filter :for={f <- @albums.filters} filter={f} />
    </form>
    <Cinder.Next.pagination collection={@albums} id="top" />
    <Cinder.Next.grid collection={@albums} :let={album}>
      <h3>{album.title}</h3>
    </Cinder.Next.grid>
    <button :for={action <- @albums.bulk_actions} {action.attrs}>{action.label}</button>
    """
  end
end
