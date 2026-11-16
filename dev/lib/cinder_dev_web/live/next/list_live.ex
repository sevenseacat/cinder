defmodule CinderDevWeb.Next.ListLive do
  @moduledoc """
  The List page in the new shell (`Cinder.Next`), as a table until it has layouts.
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
      <Layouts.parity not_yet={["`layout={:list}`", "An `<:item>` slot for each record", "Themes"]} />
      <Cinder.Next.collection id="albums-list" resource={Music.Album} url_state={@url_state}>
        <:field :let={album} name="title" filter sort>{album.title}</:field>
        <:field :let={album} name="artist.name" label="Artist" filter sort>
          {album.artist.name}
        </:field>
        <:field :let={album} name="release_date" sort>{album.release_date}</:field>
      </Cinder.Next.collection>
    </Layouts.app>
    """
  end
end
