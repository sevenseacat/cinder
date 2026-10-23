defmodule CinderDevWeb.NextLive do
  @moduledoc """
  The shell-rewrite spike (`Cinder.Next.collection`), with the same collection as
  the Table page, for comparing the two side by side. It pages by keyset, through
  the `:paginated` action, where the Table page uses offset pages, and switches
  between the table and a grid of cards. Its columns can be chosen and reordered
  (`reorderable`), with release date and remastered hidden at first.
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
      <Cinder.Next.collection
        id="albums-next"
        resource={Music.Album}
        action={:paginated}
        pagination_mode="keyset"
        reorderable
        url_state={@url_state}
        query_opts={[load: [:artist]]}
        grid_columns={[xs: 1, sm: 2, lg: 3]}
        selectable={&(not &1.is_remastered)}
      >
        <:col :let={album} field="title" filter search sort>{album.title}</:col>
        <:col :let={album} field="artist.name" label="Artist" filter sort>
          {album.artist.name}
        </:col>
        <:col field="genre" sort />
        <:filter field="genre" type="select" prompt="Any genre" help="Only one genre at a time" />
        <:filter
          field="tags"
          type="multi_select"
          options={Enum.map(CinderDev.Seeds.tags(), &{&1, &1})}
        />
        <:col :let={album} field="price" sort>{Decimal.to_string(album.price)}</:col>
        <%!-- Rich header content: an icon and a tooltip, inside the sort button --%>
        <:header :let={column} field="price">
          <.icon name="hero-currency-dollar" class="size-4 align-text-bottom" />
          {column.label}
          <span class="tooltip tooltip-bottom font-normal" data-tip="Excluding tax">(?)</span>
        </:header>
        <:col field="release_date" sort hidden />
        <:col field="is_remastered" label="Remastered" hidden />
        <%!-- Remastered albums can't be selected, so they can't be remastered again --%>
        <:bulk_action name="remaster" action={:remaster} />
        <:bulk_action name="delete" action={:destroy} confirm="Delete {count} albums?" />
        <%!-- Columns and an item: the toolbar offers a table/grid switch --%>
        <:item :let={album}>
          <strong>{album.title}</strong>
          <p>{album.artist.name} · {album.genre} · ${Decimal.to_string(album.price)}</p>
        </:item>
      </Cinder.Next.collection>

      <h2 class="mt-10 text-lg font-semibold">Custom pagination slot (not URL-synced)</h2>
      <Cinder.Next.collection id="albums-next-custom" resource={Music.Album} page_size={5}>
        <:col :let={album} field="title" sort>{album.title}</:col>
        <:col field="genre" />
        <:pagination :let={c}>
          <div class="join self-center">
            <button class="join-item btn btn-sm" {c.pagination.prev.attrs}>«</button>
            <button class="join-item btn btn-sm pointer-events-none">
              Page {c.pagination.page} of {c.pagination.page_count}
            </button>
            <button class="join-item btn btn-sm" {c.pagination.next.attrs}>»</button>
          </div>
        </:pagination>
      </Cinder.Next.collection>
    </Layouts.app>
    """
  end
end
