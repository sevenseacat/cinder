defmodule CinderDevWeb.TableLive do
  use CinderDevWeb, :live_view
  use Cinder.UrlSync

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      theme={@theme}
      current_path={@current_path}
      query_params={@query_params}
    >
      <Cinder.collection
        id="albums"
        resource={Music.Album}
        theme={@theme}
        url_state={@url_state}
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
