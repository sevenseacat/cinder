defmodule CinderDevWeb.StatesLive do
  @moduledoc """
  The `:loading`, `:empty` and `:error` slots, each forced by the collection's
  query: a slow read action, a filter nothing matches, and a failing read action.
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
      <Cinder.collection id="albums-slow" resource={Music.Album} action={:slow} theme={@theme}>
        <:col :let={album} field="title">{album.title}</:col>
        <:loading>
          <p class="p-8 text-center">Fetching albums...</p>
        </:loading>
      </Cinder.collection>

      <h2 class="mt-10 text-lg font-semibold">Empty</h2>
      <Cinder.collection id="albums-empty" query={@no_matches} theme={@theme}>
        <:col :let={album} field="title" filter>{album.title}</:col>
        <:empty :let={context}>
          <p class="p-8 text-center">
            {if context.filtered?, do: "No albums match your filters.", else: "No albums yet."}
          </p>
        </:empty>
      </Cinder.collection>

      <h2 class="mt-10 text-lg font-semibold">Error</h2>
      <Cinder.collection id="albums-failing" resource={Music.Album} action={:failing} theme={@theme}>
        <:col :let={album} field="title">{album.title}</:col>
        <:error>
          <p class="p-8 text-center text-error">Something went wrong loading albums.</p>
        </:error>
      </Cinder.collection>
    </Layouts.app>
    """
  end
end
