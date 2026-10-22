defmodule CinderDevWeb.NextDaisyLive do
  @moduledoc """
  The shell-rewrite spike, built from daisyUI markup, with collections kept in this
  LiveView: every interactive element spreads an attribute map from the collection
  view-model. The filters modal is teleported to `<body>` with a portal, so its
  inputs sit outside the collection's form and join it through `form=`.
  """
  use CinderDevWeb, :live_view
  use Cinder.Next.LiveView

  alias Cinder.Next.LiveView

  @impl true
  def mount(_params, _session, socket) do
    artists = Music.Artist |> Ash.read!() |> Enum.map(&{&1.name, &1.name}) |> Enum.sort()

    {:ok,
     socket
     |> LiveView.assign_collection(:daisy, Music.Album,
       url: true,
       layout: :grid,
       layouts: [:grid, :table],
       grid_columns: [xs: 1, sm: 2, lg: 3],
       selectable: true,
       load: [:artist],
       page_size: 12,
       search: [fields: ["title", "artist.name"]],
       filters: [
         genre: [type: :select, prompt: "All"],
         title: [type: :text, help: "Matches anywhere in the title"],
         tags: [type: :multi_checkboxes, options: Enum.map(CinderDev.Seeds.tags(), &{&1, &1})],
         price: [type: :number_range, label: "Price ($)"],
         "artist.name": [type: :autocomplete, label: "Artist", options: artists, max_results: 5]
       ],
       sorts: [:title, price: [label: "Price"], release_date: [label: "Released"]],
       bulk_actions: [
         remaster: :remaster,
         delete: [action: :destroy, confirm: "Delete {count} albums? This can't be undone."]
       ]
     )
     |> LiveView.assign_collection(:tracks, Music.Album,
       action: :with_min_tracks,
       page_size: 6,
       arguments: [min_tracks: [label: "At least this many tracks"]],
       filters: [genre: [type: :select, prompt: "All"]]
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
      <div {@daisy.attrs} class="space-y-4">
        <%!-- The search, genre and sort controls sit in the collection's form; the
             teleported modal can't, so its inputs join it through `form=` --%>
        <form {@daisy.form_attrs} class="space-y-4">
          <div class="flex flex-wrap items-center gap-3">
            <label class="input">
              <.icon name="hero-magnifying-glass" class="size-4 opacity-50" />
              <input {@daisy.search.input_attrs} class="grow" />
            </label>

            <button type="button" class="btn" onclick="daisy_filters.showModal()">
              Filters
              <span :if={@daisy.active_filter_count > 0} class="badge badge-primary badge-sm">
                {@daisy.active_filter_count}
              </span>
            </button>

            <%!-- A select filter as a button group, from each option's radio attrs --%>
            <div class="join">
              <input
                :for={option <- @daisy.filters["genre"].options}
                class="join-item btn btn-sm"
                {option.input_attrs}
              />
            </div>

            <div class="join">
              <button
                :for={layout <- @daisy.layouts}
                class={["join-item btn btn-sm", layout.active? && "btn-active"]}
                {layout.attrs}
              >
                {layout.label}
              </button>
            </div>

            <span :if={@daisy.status == :loading} class="loading loading-spinner loading-sm"></span>
          </div>

          <div class="flex flex-wrap items-center gap-2">
            <span class="text-sm opacity-70">Sort:</span>
            <%!-- Chips: additive, from each sort's attrs --%>
            <button
              :for={sort <- @daisy.sorts}
              class={["btn btn-xs", sort.direction && "btn-primary"]}
              {sort.attrs}
            >
              {sort.label}
              <span :if={sort.direction}>{if sort.direction == :asc, do: "↑", else: "↓"}</span>
            </button>
            <span class="divider divider-horizontal mx-0"></span>
            <%!-- The same sorts as an exclusive dropdown --%>
            <select class="select select-sm w-auto" {@daisy.sort_select.select_attrs}>
              <option :for={option <- @daisy.sort_select.options} {option.attrs}>
                {option.label}
              </option>
            </select>
          </div>
        </form>

        <%!-- The selection and its actions, from `selection` and `bulk_actions` --%>
        <div
          :if={@daisy.selection.count > 0}
          class="flex items-center gap-3 rounded-box bg-base-200 px-4 py-2"
        >
          <input {@daisy.selection.page_attrs} class="checkbox checkbox-sm" />
          <span class="text-sm font-medium">{@daisy.selection.summary}</span>
          <button :for={action <- @daisy.bulk_actions} class="btn btn-sm" {action.attrs}>
            {action.label}
          </button>
          <button class="btn btn-sm btn-ghost" {@daisy.selection.clear_attrs}>Clear</button>
        </div>

        <div
          :if={@daisy.bulk_result}
          role="status"
          class={[
            "alert",
            @daisy.bulk_result.status == :ok && "alert-success",
            @daisy.bulk_result.status != :ok && "alert-error"
          ]}
        >
          {@daisy.bulk_result.action}: {if @daisy.bulk_result.status == :ok,
            do: "done",
            else: "failed"}
        </div>

        <%!-- The server holds the pending action; this only shows its question.
             Rendered while pending, so no JS: confirming runs what the server has
             pending, not anything this markup names. --%>
        <div :if={@daisy.confirmation} class="modal modal-open" {@daisy.confirmation.attrs}>
          <div class="modal-box">
            <h3 class="text-lg font-bold">{@daisy.confirmation.action}</h3>
            <p class="py-4">{@daisy.confirmation.message}</p>
            <div class="modal-action">
              <button class="btn btn-ghost" {@daisy.confirmation.cancel_attrs}>Cancel</button>
              <button class="btn btn-error" {@daisy.confirmation.confirm_attrs}>
                {@daisy.confirmation.action}
              </button>
            </div>
          </div>
        </div>

        <.daisy_pagination :if={@daisy.pagination} pagination={@daisy.pagination} />

        <Cinder.Next.table :if={@daisy.layout == :table} collection={@daisy} class="table">
          <:col :let={album} field="title">{album.title}</:col>
          <:col :let={album} field="artist.name">{album.artist.name}</:col>
          <:col :let={album} field="genre">{album.genre}</:col>
          <:col :let={album} field="price">${Decimal.to_string(album.price)}</:col>
        </Cinder.Next.table>
        <%!-- Its own grid, spreading each row's attrs (data-row-id, data-selected) onto
             its own wrapper: Cinder's CSS only styles the `cinder-*` classes its own
             components render, so the daisyUI card isn't wrapped in a second card --%>
        <div :if={@daisy.layout == :grid} class="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
          <div
            :for={row <- @daisy.rows}
            class={["relative rounded-box", row.selected? && "ring-2 ring-primary"]}
            {row.attrs}
          >
            <input class="checkbox checkbox-sm absolute top-4 right-4" {row.select_attrs} />
            <div class="card bg-base-100 card-border h-full">
              <div class="card-body">
                <h3 class="card-title">{row.record.title}</h3>
                <p class="opacity-70">{row.record.artist.name}</p>
                <div class="card-actions justify-end">
                  <span class="badge badge-outline">{row.record.genre}</span>
                  <span class="badge">${Decimal.to_string(row.record.price)}</span>
                </div>
              </div>
            </div>
          </div>
        </div>

        <div :if={@daisy.rows == [] and @daisy.status == :idle} class="alert">No albums match.</div>

        <.daisy_pagination :if={@daisy.pagination} pagination={@daisy.pagination} />
      </div>

      <%!-- Teleported to <body>: these inputs are outside the collection's markup entirely --%>
      <.portal id="daisy-filters-portal" target="body">
        <%!-- showModal() sets `open` in the browser; without this, every re-render
             (like a filter change) would strip it and leave the page inert --%>
        <dialog id="daisy_filters" class="modal" phx-mounted={JS.ignore_attributes(["open"])}>
          <div class="modal-box space-y-4">
            <h3 class="text-lg font-bold">Filters</h3>
            <.text_filter filter={@daisy.filters["title"]} />
            <.autocomplete_filter filter={@daisy.filters["artist.name"]} />
            <.checkboxes_filter filter={@daisy.filters["tags"]} />
            <.range_filter filter={@daisy.filters["price"]} />

            <div class="modal-action">
              <button class="btn btn-ghost" {@daisy.clear_all_attrs}>Clear all</button>
              <form method="dialog"><button class="btn">Done</button></form>
            </div>
          </div>
          <form method="dialog" class="modal-backdrop"><button>close</button></form>
        </dialog>
      </.portal>

      <h2 class="mt-12 text-lg font-semibold">A read action argument (not URL-synced)</h2>
      <div {@tracks.attrs}>
        <form {@tracks.form_attrs}>
          <fieldset :for={min <- @tracks.filters} class="fieldset max-w-xs">
            <legend class="fieldset-legend">{min.label}</legend>
            <input class={["input", min.errors != [] && "input-error"]} {min.input_attrs} />
            <p :if={min.errors != []} class="label text-error" {min.error_attrs}>
              {Enum.join(min.errors, ", ")}
            </p>
          </fieldset>
        </form>
        <table :if={@tracks.status == :idle} class="table">
          <tr :for={row <- @tracks.rows} {row.attrs}>
            <td>{row.record.title}</td>
            <td>{row.record.track_count}</td>
          </tr>
        </table>
      </div>
    </Layouts.app>
    """
  end

  attr :filter, :map, required: true

  defp text_filter(assigns) do
    ~H"""
    <fieldset class="fieldset">
      <legend class="fieldset-legend">
        {@filter.label}
        <span class="tooltip" data-tip={@filter.help}>
          <.icon name="hero-question-mark-circle" class="size-4 opacity-60" />
        </span>
        <.clear filter={@filter} />
      </legend>
      <input class="input w-full" {@filter.input_attrs} />
      <p class="label" {@filter.help_attrs}>{@filter.help}</p>
    </fieldset>
    """
  end

  attr :filter, :map, required: true

  defp checkboxes_filter(assigns) do
    ~H"""
    <fieldset class="fieldset">
      <legend class="fieldset-legend">{@filter.label} <.clear filter={@filter} /></legend>
      <div class="flex flex-wrap gap-x-4 gap-y-2">
        <label :for={option <- @filter.options} class="label">
          <input class="checkbox checkbox-sm" {option.input_attrs} /> {option.label}
        </label>
      </div>
    </fieldset>
    """
  end

  attr :filter, :map, required: true

  defp range_filter(assigns) do
    ~H"""
    <fieldset class="fieldset">
      <legend class="fieldset-legend">{@filter.label} <.clear filter={@filter} /></legend>
      <div class="join">
        <input class="input join-item" {@filter.input_attrs.min} />
        <input class="input join-item" {@filter.input_attrs.max} />
      </div>
    </fieldset>
    """
  end

  attr :filter, :map, required: true

  defp autocomplete_filter(assigns) do
    ~H"""
    <fieldset class="fieldset">
      <legend class="fieldset-legend">{@filter.label} <.clear filter={@filter} /></legend>
      <input class="input w-full" {@filter.input_attrs} />
      <div class="flex flex-wrap gap-1">
        <input
          :for={option <- @filter.options}
          class="btn btn-xs"
          aria-label={option.label}
          {option.input_attrs}
        />
      </div>
    </fieldset>
    """
  end

  attr :filter, :map, required: true

  # Every filter's view-model has `clear_attrs`, hidden while the filter isn't active
  defp clear(assigns) do
    ~H"""
    <button class="btn btn-ghost btn-xs" {@filter.clear_attrs}>Clear</button>
    """
  end

  attr :pagination, :map, required: true

  defp daisy_pagination(assigns) do
    ~H"""
    <div class="flex items-center justify-between">
      <span class="text-sm opacity-70">{@pagination.summary}</span>
      <div class="join">
        <button class="join-item btn btn-sm" {@pagination.prev.attrs}>«</button>
        <%= for page <- @pagination.pages do %>
          <button :if={page.kind == :gap} class="join-item btn btn-sm btn-disabled">…</button>
          <button
            :if={page.kind == :page}
            class={["join-item btn btn-sm", page.current? && "btn-active"]}
            {page.attrs}
          >
            {page.label}
          </button>
        <% end %>
        <button class="join-item btn btn-sm" {@pagination.next.attrs}>»</button>
      </div>
    </div>
    """
  end
end
