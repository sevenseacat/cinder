defmodule CinderDevWeb.NextPowerLive do
  @moduledoc """
  The shell-rewrite spike's "crazy custom case", on sketch 8b: the collection lives
  in this LiveView, and everything else is the app's own. Users choose which
  columns show and in what order, and the table is this page's own HTML. Cinder
  knows nothing about the columns: they're this LiveView's state and events, next
  to the collection's. Rows are grouped by genre (7CC-129): the collection keeps
  each group together and gives `@albums.groups`, and groups collapse in the
  browser.
  """
  use CinderDevWeb, :live_view
  use Cinder.Next.LiveView

  alias Cinder.Next.LiveView, as: Collections

  @columns [
    {"title", "Title"},
    {"artist.name", "Artist"},
    {"genre", "Genre"},
    {"price", "Price"},
    {"release_date", "Released"},
    {"track_count", "Tracks"},
    {"is_remastered", "Remastered"}
  ]

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign_columns(
       Enum.map(@columns, fn {key, label} ->
         %{key: key, label: label, visible?: key != "track_count"}
       end)
     )
     |> Collections.assign_collection(:albums, Ash.Query.sort(Music.Album, :title),
       url: true,
       load: [:artist],
       page_size: 15,
       layouts: [:table],
       group: :genre,
       selectable: true,
       search: ["title", "artist.name"],
       filters: [genre: [type: :select, prompt: "Any genre"]],
       sorts: [:genre, :title, :"artist.name", :price, :release_date, :track_count],
       bulk_actions: [remaster: :remaster]
     )}
  end

  @impl true
  def handle_params(_params, _uri, socket), do: {:noreply, socket}

  # The page's own events, alongside the collection's
  @impl true
  def handle_event("toggle_column", %{"key" => key}, socket) do
    columns =
      Enum.map(
        socket.assigns.columns,
        &if(&1.key == key, do: %{&1 | visible?: not &1.visible?}, else: &1)
      )

    {:noreply, assign_columns(socket, columns)}
  end

  def handle_event("move_column", %{"key" => key, "by" => by}, socket) do
    columns = socket.assigns.columns
    from = Enum.find_index(columns, &(&1.key == key))
    to = max(from + String.to_integer(by), 0)
    {column, rest} = List.pop_at(columns, from)
    {:noreply, assign_columns(socket, List.insert_at(rest, to, column))}
  end

  # The visible columns are kept beside the choice, not worked out in `render/1`,
  # where they'd be new every render and resent
  defp assign_columns(socket, columns),
    do: assign(socket, columns: columns, visible: Enum.filter(columns, & &1.visible?))

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      theme={@theme}
      current_path={@current_path}
      query_params={@query_params}
    >
      <div {@albums.attrs} class="space-y-4">
        <div class="flex flex-wrap items-end gap-3">
          <form {@albums.form_attrs} class="contents">
            <Cinder.Next.toolbar collection={@albums} />
          </form>

          <details class="dropdown">
            <summary class="btn btn-sm">Columns</summary>
            <ul class="dropdown-content z-10 mt-1 w-64 space-y-1 rounded-box bg-base-100 p-2 shadow">
              <li :for={{column, index} <- Enum.with_index(@columns)} class="flex items-center gap-2">
                <label class="flex grow items-center gap-2">
                  <input
                    type="checkbox"
                    class="checkbox checkbox-xs"
                    checked={column.visible?}
                    phx-click="toggle_column"
                    phx-value-key={column.key}
                  />
                  {column.label}
                </label>
                <button
                  class="btn btn-ghost btn-xs"
                  disabled={index == 0}
                  phx-click="move_column"
                  phx-value-key={column.key}
                  phx-value-by="-1"
                >
                  ↑
                </button>
                <button
                  class="btn btn-ghost btn-xs"
                  disabled={index == length(@columns) - 1}
                  phx-click="move_column"
                  phx-value-key={column.key}
                  phx-value-by="1"
                >
                  ↓
                </button>
              </li>
            </ul>
          </details>
        </div>

        <Cinder.Next.pagination collection={@albums} />

        <table class="table table-sm">
          <thead>
            <tr>
              <th class="w-0">
                <input class="checkbox checkbox-sm" {@albums.selection.page_attrs} />
              </th>
              <th :for={column <- @visible}>
                <.sort_header
                  sort={Enum.find(@albums.sorts, &(&1.field == column.key))}
                  label={column.label}
                />
              </th>
            </tr>
          </thead>
          <%= for group <- @albums.groups do %>
            <tbody {group.attrs}>
              <tr class="bg-base-200">
                <th class="w-0">
                  <button class="btn btn-ghost btn-xs group" {group.toggle_attrs}>
                    <.icon
                      name="hero-chevron-down"
                      class="size-4 group-aria-[expanded=false]:-rotate-90"
                    />
                  </button>
                </th>
                <th colspan={length(@visible)}>
                  <span id={group.label_id}>{group.value}</span>
                  <span class="ml-2 font-normal opacity-60">{length(group.items)} on this page</span>
                </th>
              </tr>
            </tbody>
            <tbody {group.items_attrs}>
              <tr :for={row <- group.items} class={row.selected? && "bg-primary/10"}>
                <td><input class="checkbox checkbox-sm" {row.select_attrs} /></td>
                <td :for={column <- @visible}>{cell(row.record, column.key)}</td>
              </tr>
            </tbody>
          <% end %>
        </table>

        <Cinder.Next.bulk_bar collection={@albums} />
        <Cinder.Next.pagination collection={@albums} />
      </div>
    </Layouts.app>
    """
  end

  attr :sort, :map, default: nil
  attr :label, :string, required: true

  defp sort_header(%{sort: nil} = assigns), do: ~H"{@label}"

  defp sort_header(assigns) do
    ~H"""
    <button class="flex items-center gap-1" {@sort.attrs}>
      {@label}
      <span :if={@sort.direction}>{if @sort.direction == :asc, do: "↑", else: "↓"}</span>
    </button>
    """
  end

  defp cell(album, "artist.name"), do: album.artist.name
  defp cell(album, "price"), do: "$" <> Decimal.to_string(album.price)
  defp cell(album, "is_remastered"), do: if(album.is_remastered, do: "Yes", else: "")
  defp cell(album, key), do: Map.get(album, String.to_existing_atom(key))
end
