defmodule CinderDevWeb.NextLive do
  @moduledoc """
  The new shell (`Cinder.Next`), as it's rebuilt slice by slice.
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
      <Cinder.Next.collection
        id="albums"
        resource={Music.Album}
        pagination={[mode: :keyset, size: 10]}
        url_state={@url_state}
        selectable={&(&1.genre != :classical)}
      >
        <:field :let={album} name="title" sort filter search>{album.title}</:field>
        <:field :let={album} name="artist.name" sort search>{album.artist.name}</:field>
        <:field
          :let={album}
          name="release_date"
          label="Released"
          sort={[cycle: [:desc, :asc, nil]]}
          filter
        >
          {Calendar.strftime(album.release_date, "%d/%m/%Y")}
        </:field>
        <:field name="genre" filter={[type: :radio_group, prompt: "Any"]} column={false} />
      </Cinder.Next.collection>

      <%!-- Not synced to the URL: only one collection on a page can be, for now --%>
      <h2 class="mt-8 text-lg font-semibold">By genre</h2>
      <Cinder.Next.collection id="albums-by-genre" resource={Music.Album} action={:by_genre}>
        <:field :let={album} name="title" sort>{album.title}</:field>
        <:field :let={album} name="artist.name">{album.artist.name}</:field>
        <:argument name="genre" input={[prompt: "Choose a genre"]} />
      </Cinder.Next.collection>
    </Layouts.app>
    """
  end
end
