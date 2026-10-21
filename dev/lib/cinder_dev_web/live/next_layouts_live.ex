defmodule CinderDevWeb.NextLayoutsLive do
  @moduledoc """
  The shell-rewrite spike's layout customisation: a `:toolbar` region slot, a
  custom layout, a list, and a grid with breakpoint columns. Only the custom
  layout is URL-synced, because two URL-synced collections on one page aren't
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
      <%!-- A Discord user's case: a section heading with search beside it, which today
           needs the :controls slot plus hand-passed theme and target --%>
      <Cinder.Next.collection id="buildings" resource={Music.Album} page_size={5}>
        <:col :let={album} field="title" search sort>{album.title}</:col>
        <:col field="genre" />
        <:toolbar :let={c}>
          <div class="flex items-center justify-between">
            <h2 class="text-lg font-semibold">Albums</h2>
            <Cinder.Next.search search={c.search} />
          </div>
        </:toolbar>
      </Cinder.Next.collection>

      <h2 class="mt-12 text-lg font-semibold">Custom layout: sidebar, pagination top and bottom</h2>
      <Cinder.Next.collection
        :let={c}
        id="sidebar"
        resource={Music.Album}
        layout="custom"
        url_state={@url_state}
        page_size={8}
      >
        <:col :let={album} field="title" sort search>{album.title}</:col>
        <:col field="genre" />
        <:filter field="genre" type="select" prompt="Any genre" />
        <:filter field="title" type="text" />

        <div class="grid gap-6 md:grid-cols-[16rem_1fr]">
          <form {c.form_attrs} class="space-y-4">
            <Cinder.Next.search search={c.search} />
            <Cinder.Next.filter :for={f <- c.filters} filter={f} />
          </form>
          <main class="space-y-4">
            <Cinder.Next.pagination collection={c} />
            <Cinder.Next.table collection={c} />
            <Cinder.Next.pagination collection={c} />
          </main>
        </div>
      </Cinder.Next.collection>

      <h2 class="mt-12 text-lg font-semibold">List (a one-column grid)</h2>
      <Cinder.Next.collection id="list" resource={Music.Album} layout="list" page_size={4}>
        <:sort field="title" />
        <:item :let={album}>{album.title} · {album.genre}</:item>
      </Cinder.Next.collection>

      <h2 class="mt-12 text-lg font-semibold">Grid with breakpoint columns (1, 2, then 4)</h2>
      <Cinder.Next.collection
        id="breakpoints"
        resource={Music.Album}
        layout="grid"
        grid_columns={[xs: 1, sm: 2, lg: 4]}
        page_size={8}
      >
        <:item :let={album}>
          <p class="font-semibold">{album.title}</p>
          <p class="text-sm opacity-70">{album.genre}</p>
        </:item>
      </Cinder.Next.collection>
    </Layouts.app>
    """
  end
end
