defmodule CinderDevWeb.ListLive do
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
      <Cinder.collection
        id="albums-list"
        resource={Music.Album}
        layout={:list}
        theme={@theme}
        url_state={@url_state}
        query_opts={[load: [:artist]]}
      >
        <:col field="title" filter sort />
        <:col field="artist.name" label="Artist" filter sort />
        <:col field="release_date" sort />

        <:item :let={album}>
          <div>
            <p class="font-semibold">{album.title}</p>
            <p class="text-sm opacity-70">{album.artist.name} · {album.release_date}</p>
          </div>
        </:item>
      </Cinder.collection>
    </Layouts.app>
    """
  end
end
