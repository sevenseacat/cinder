defmodule CinderDevWeb.Next.ControlsLive do
  @moduledoc """
  The Controls page in the new shell (`Cinder.Next`), with the default controls until
  they can be laid out by hand.
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
      <Layouts.parity not_yet={[
        "A `<:controls>` slot laying out the search and filters by hand (`Cinder.Controls`)",
        "Themes"
      ]} />
      <Cinder.Next.collection id="albums-controls" resource={Music.Album} url_state={@url_state}>
        <:field :let={album} name="title" search sort>{album.title}</:field>
        <:field :let={album} name="genre" filter>{album.genre}</:field>
        <:field :let={album} name="is_remastered" label="Remastered" filter>
          {album.is_remastered}
        </:field>
      </Cinder.Next.collection>
    </Layouts.app>
    """
  end
end
