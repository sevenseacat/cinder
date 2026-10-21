defmodule CinderDevWeb.NextLiveViewLive do
  @moduledoc """
  The shell-rewrite spike's sketch 8b: the collection lives in this LiveView's
  assigns (`use Cinder.Next.LiveView`), declared in `mount`, and the template is
  only function components, arranged freely: pagination twice, the bulk bar under
  the results, and the card written where the grid is.
  """
  use CinderDevWeb, :live_view
  use Cinder.Next.LiveView

  alias Cinder.Next.LiveView, as: Collections

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     Collections.assign_collection(socket, :albums, Music.Album,
       url: true,
       load: [:artist],
       page_size: 12,
       layouts: [:grid],
       grid_columns: [xs: 1, sm: 2, lg: 3],
       selectable: true,
       search: ["title", "artist.name"],
       filters: [genre: [type: :select, prompt: "Any genre"], price: :number_range],
       sorts: [:title, :price, release_date: [label: "Released"]],
       bulk_actions: [
         remaster: :remaster,
         delete: [action: :destroy, confirm: "Delete {count} albums?"]
       ]
     )}
  end

  @impl true
  def handle_params(_params, _uri, socket), do: {:noreply, socket}

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      theme={@theme}
      current_path={@current_path}
      query_params={@query_params}
    >
      <div {@albums.attrs} class="space-y-4">
        <form {@albums.form_attrs}>
          <Cinder.Next.toolbar collection={@albums} />
        </form>
        <Cinder.Next.pagination collection={@albums} />
        <Cinder.Next.grid :let={album} collection={@albums}>
          <strong>{album.title}</strong>
          <p>{album.artist.name} · {album.genre} · ${Decimal.to_string(album.price)}</p>
        </Cinder.Next.grid>
        <Cinder.Next.bulk_bar collection={@albums} />
        <Cinder.Next.pagination collection={@albums} />
      </div>
    </Layouts.app>
    """
  end
end
