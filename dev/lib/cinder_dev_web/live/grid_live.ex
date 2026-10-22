defmodule CinderDevWeb.GridLive do
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
        id="albums-grid"
        resource={Music.Album}
        layout={:grid}
        grid_columns={[xs: 1, sm: 2, md: 3, lg: 4]}
        theme={@theme}
        url_state={@url_state}
        query_opts={[load: [:artist]]}
      >
        <:col field="title" filter sort />
        <:col field="genre" filter />
        <:col field="price" sort />

        <:item :let={album}>
          <p class="font-semibold">{album.title}</p>
          <p class="text-sm opacity-70">{album.artist.name}</p>
          <p class="mt-2 text-sm">{album.genre} · ${Decimal.to_string(album.price)}</p>
        </:item>
      </Cinder.collection>
    </Layouts.app>
    """
  end
end
