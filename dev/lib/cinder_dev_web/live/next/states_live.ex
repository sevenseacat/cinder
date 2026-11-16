defmodule CinderDevWeb.Next.StatesLive do
  @moduledoc """
  The States page in the new shell (`Cinder.Next`). It reads synchronously for now, so
  the slow collection holds up the whole page, and a failing read would crash it.
  """
  use CinderDevWeb, :live_view

  require Ash.Query

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :no_matches, Ash.Query.filter(Music.Album, title == "No such album"))}
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
      <h2 class="text-lg font-semibold">Loading (the read action takes 1.5s)</h2>
      <Layouts.parity not_yet={[
        "Reading in the background: the whole page waits for this read",
        "A `<:loading>` slot",
        "Themes"
      ]} />
      <Cinder.Next.collection id="albums-slow" resource={Music.Album} action={:slow}>
        <:field :let={album} name="title">{album.title}</:field>
      </Cinder.Next.collection>

      <h2 class="mt-10 text-lg font-semibold">Empty</h2>
      <Layouts.parity not_yet={["An `<:empty>` slot, told whether filters are applied", "Themes"]} />
      <Cinder.Next.collection id="albums-empty" query={@no_matches}>
        <:field :let={album} name="title" filter>{album.title}</:field>
      </Cinder.Next.collection>

      <h2 class="mt-10 text-lg font-semibold">Error</h2>
      <Layouts.parity not_yet={[
        "A failed read crashes the collection, so there's none here",
        "An `<:error>` slot"
      ]} />
    </Layouts.app>
    """
  end
end
