defmodule CinderDevWeb.NextLayoutsLive do
  @moduledoc """
  The shell-rewrite spike's layout customisation: a `:toolbar` region slot, a page
  arranged freely (a collection kept in this LiveView, with filters in a sidebar and
  pagination twice), grouping, a list, and a grid with breakpoint columns. The rest
  are collection components, side by side with the LiveView-kept one. Only the
  sidebar one is URL-synced, because two URL-synced collections on one page aren't
  supported yet.
  """
  use CinderDevWeb, :live_view
  use Cinder.Next.LiveView

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     Cinder.Next.LiveView.assign_collection(socket, :sidebar, Music.Album,
       url: true,
       page_size: 8,
       filters: [genre: [type: :select, prompt: "Any genre"], title: :text],
       sorts: [:title],
       search: ["title"]
     )}
  end

  @impl true
  def handle_params(_params, _uri, socket), do: {:noreply, socket}

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

      <h2 class="mt-12 text-lg font-semibold">
        Arranged freely: a sidebar, pagination top and bottom (kept in this LiveView)
      </h2>
      <div {@sidebar.attrs} class="grid gap-6 md:grid-cols-[16rem_1fr]">
        <form {@sidebar.form_attrs} class="space-y-4">
          <Cinder.Next.search search={@sidebar.search} />
          <Cinder.Next.filter :for={f <- @sidebar.filters} filter={f} />
        </form>
        <main class="space-y-4">
          <Cinder.Next.pagination collection={@sidebar} />
          <Cinder.Next.table collection={@sidebar}>
            <:col :let={album} field="title">{album.title}</:col>
            <:col :let={album} field="genre">{album.genre}</:col>
          </Cinder.Next.table>
          <Cinder.Next.pagination collection={@sidebar} />
        </main>
      </div>

      <h2 class="mt-12 text-lg font-semibold">Grouped by genre (the default table)</h2>
      <Cinder.Next.collection id="grouped" resource={Music.Album} page_size={12}>
        <:col :let={album} field="title" sort>{album.title}</:col>
        <:col field="release_date" label="Released" sort />
        <:group :let={group} field="genre">
          {group.value} <small>({length(group.items)} on this page)</small>
        </:group>
      </Cinder.Next.collection>

      <h2 class="mt-12 text-lg font-semibold">
        A multi-select inside a short <code>overflow: hidden</code> box
      </h2>
      <%!-- An absolutely positioned dropdown would be clipped here; a popover isn't --%>
      <div class="h-40 overflow-hidden rounded-box border border-base-300 p-4">
        <Cinder.Next.collection id="clipped" resource={Music.Album} page_size={3}>
          <:col :let={album} field="title">{album.title}</:col>
          <:filter
            field="tags"
            type="multi_select"
            options={Enum.map(CinderDev.Seeds.tags(), &{&1, &1})}
          />
        </Cinder.Next.collection>
      </div>

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
