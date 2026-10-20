defmodule CinderDevWeb.NextGridLive do
  @moduledoc """
  The shell-rewrite spike's grid layout: cards from `<:item>`, with no `<:col>`
  slots at all. Filters, sorts and search are declared on their own.
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
        id="albums-next-grid"
        resource={Music.Album}
        layout="grid"
        url_state={@url_state}
        query_opts={[load: [:artist]]}
        page_size={12}
        search={[fields: ["title", "artist.name"]]}
      >
        <:filter field="genre" type="select" prompt="Any genre" />
        <:filter field="title" type="text" />
        <:sort field="title" />
        <:sort field="price" label="Price" />
        <:sort field="release_date" label="Released" />

        <:item :let={album}>
          <p class="font-semibold">{album.title}</p>
          <p class="text-sm opacity-70">{album.artist.name}</p>
          <p class="mt-2 text-sm">
            {album.genre} · ${Decimal.to_string(album.price)} · {album.release_date}
          </p>
        </:item>
      </Cinder.Next.collection>
    </Layouts.app>
    """
  end
end
