defmodule CinderDevWeb.NextLive do
  @moduledoc """
  The shell-rewrite spike (`Cinder.Next.collection`), with the same collection as
  the Table page, for comparing the two side by side.
  """
  use CinderDevWeb, :live_view
  use Cinder.UrlSync

  @impl true
  def handle_params(params, uri, socket) do
    {:noreply, Cinder.UrlSync.handle_params(params, uri, socket)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      theme={@theme}
      current_path={@current_path}
      query_params={@query_params}
    >
      <Cinder.Next.collection
        id="albums-next"
        resource={Music.Album}
        url_state={@url_state}
        query_opts={[load: [:artist]]}
      >
        <:col :let={album} field="title" filter sort>{album.title}</:col>
        <:col :let={album} field="artist.name" label="Artist" filter sort>
          {album.artist.name}
        </:col>
        <:col field="genre" filter sort />
        <:col :let={album} field="price" filter sort>{Decimal.to_string(album.price)}</:col>
        <:col field="release_date" filter sort />
        <:col field="is_remastered" label="Remastered" filter />
      </Cinder.Next.collection>
    </Layouts.app>
    """
  end
end
