defmodule CinderDevWeb.AlbumsLive do
  use CinderDevWeb, :live_view
  use Cinder.UrlSync

  @impl true
  def handle_params(params, uri, socket) do
    {:noreply, Cinder.UrlSync.handle_params(params, uri, socket)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <Cinder.collection
        id="albums"
        resource={Music.Album}
        url_state={@url_state}
        query_opts={[load: [:artist]]}
      >
        <:col :let={album} field="title" filter sort>{album.title}</:col>
        <:col :let={album} field="artist.name" label="Artist" filter sort>
          {album.artist.name}
        </:col>
        <:col :let={album} field="genre" filter sort>{album.genre}</:col>
        <:col :let={album} field="price" filter sort>{Decimal.to_string(album.price)}</:col>
        <:col :let={album} field="release_date" filter sort>{album.release_date}</:col>
        <:col :let={album} field="is_remastered" label="Remastered" filter>
          {album.is_remastered}
        </:col>
      </Cinder.collection>
    </Layouts.app>
    """
  end
end
