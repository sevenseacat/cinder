defmodule CinderDevWeb.Next.StatesLive do
  @moduledoc """
  The States page in the new shell (`Cinder.Next`).
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
      <Layouts.parity not_yet={["Themes"]} />
      <Cinder.Next.collection id="albums-slow" resource={Music.Album} action={:slow}>
        <:field :let={album} name="title">{album.title}</:field>
        <:loading>
          <p class="p-8 text-center">Fetching albums...</p>
        </:loading>
      </Cinder.Next.collection>

      <h2 class="mt-10 text-lg font-semibold">Empty</h2>
      <Layouts.parity
        not_yet={["Themes"]}
        changed={[
          "The slot's `filters` are each filter's value, by field, and it gets `arguments` too"
        ]}
      />
      <Cinder.Next.collection id="albums-empty" query={@no_matches}>
        <:field :let={album} name="title" filter>{album.title}</:field>
        <:empty :let={context}>
          <p class="p-8 text-center">
            {if context.filtered?, do: "No albums match your filters.", else: "No albums yet."}
          </p>
        </:empty>
      </Cinder.Next.collection>

      <h2 class="mt-10 text-lg font-semibold">Error</h2>
      <Layouts.parity
        not_yet={["Themes"]}
        changed={["The error offers to try again, and the slot is given `retry` to do it"]}
      />
      <Cinder.Next.collection id="albums-failing" resource={Music.Album} action={:failing}>
        <:field :let={album} name="title">{album.title}</:field>
        <:error :let={error}>
          <p class="p-8 text-center text-error">
            Something went wrong loading albums.
            <button type="button" class="link" phx-click={error.retry}>Try again</button>
          </p>
        </:error>
      </Cinder.Next.collection>
    </Layouts.app>
    """
  end
end
