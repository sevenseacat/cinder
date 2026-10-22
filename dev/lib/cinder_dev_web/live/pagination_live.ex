defmodule CinderDevWeb.PaginationLive do
  @moduledoc """
  Offset pagination with a page-size selector, and keyset pagination. Only the
  first is URL-synced, because two URL-synced collections on one page aren't
  supported yet.
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
      <h2 class="text-lg font-semibold">Offset, with a page-size selector (URL-synced)</h2>
      <Cinder.collection
        id="albums-offset"
        resource={Music.Album}
        theme={@theme}
        url_state={@url_state}
        page_size={[default: 10, options: [10, 25, 50]]}
      >
        <:col :let={album} field="title" sort>{album.title}</:col>
        <:col :let={album} field="release_date" sort>{album.release_date}</:col>
      </Cinder.collection>

      <h2 class="mt-10 text-lg font-semibold">Keyset (not URL-synced)</h2>
      <Cinder.collection
        id="albums-keyset"
        resource={Music.Album}
        action={:paginated}
        theme={@theme}
        pagination={[mode: :keyset]}
        page_size={10}
      >
        <:col :let={album} field="title" sort>{album.title}</:col>
        <:col :let={album} field="release_date" sort>{album.release_date}</:col>
      </Cinder.collection>
    </Layouts.app>
    """
  end
end
