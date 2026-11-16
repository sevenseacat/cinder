defmodule CinderDevWeb.Next.PaginationLive do
  @moduledoc """
  The Pagination page in the new shell (`Cinder.Next`). Only the first collection is
  URL-synced, because two URL-synced collections on one page aren't supported yet.
  """
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
      <h2 class="text-lg font-semibold">Offset, with a page-size selector (URL-synced)</h2>
      <Layouts.parity not_yet={["The page size selector (`size_options`)", "Themes"]} />
      <Cinder.Next.collection
        id="albums-offset"
        resource={Music.Album}
        url_state={@url_state}
        pagination={[size: 10]}
      >
        <:field :let={album} name="title" sort>{album.title}</:field>
        <:field :let={album} name="release_date" sort>{album.release_date}</:field>
      </Cinder.Next.collection>

      <h2 class="mt-10 text-lg font-semibold">Keyset (not URL-synced)</h2>
      <Layouts.parity not_yet={["Themes"]} />
      <Cinder.Next.collection
        id="albums-keyset"
        resource={Music.Album}
        action={:paginated}
        pagination={[mode: :keyset, size: 10]}
      >
        <:field :let={album} name="title" sort>{album.title}</:field>
        <:field :let={album} name="release_date" sort>{album.release_date}</:field>
      </Cinder.Next.collection>

      <h2 class="mt-10 text-lg font-semibold">Offset, counted in the background (not URL-synced)</h2>
      <Layouts.parity not_yet={[
        "Counting in the background (`count: :async`): it counts with each read",
        "Themes"
      ]} />
      <Cinder.Next.collection id="albums-async-count" resource={Music.Album} pagination={[size: 10]}>
        <:field :let={album} name="title" sort>{album.title}</:field>
        <:field :let={album} name="release_date" sort>{album.release_date}</:field>
      </Cinder.Next.collection>
    </Layouts.app>
    """
  end
end
