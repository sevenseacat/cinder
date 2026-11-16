defmodule CinderDevWeb.Next.TableLive do
  @moduledoc """
  The Table page in the new shell (`Cinder.Next`).
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
      <Layouts.parity not_yet={["Themes"]} />
      <Cinder.Next.collection id="albums" resource={Music.Album} url_state={@url_state}>
        <:field :let={album} name="title" filter sort>{album.title}</:field>
        <:field :let={album} name="artist.name" label="Artist" filter sort>
          {album.artist.name}
        </:field>
        <:field :let={album} name="genre" filter sort>{album.genre}</:field>
        <:field :let={album} name="price" filter sort>{Decimal.to_string(album.price)}</:field>
        <:field :let={album} name="release_date" filter sort>{album.release_date}</:field>
        <:field :let={album} name="is_remastered" label="Remastered" filter>
          {album.is_remastered}
        </:field>
      </Cinder.Next.collection>
    </Layouts.app>
    """
  end
end
