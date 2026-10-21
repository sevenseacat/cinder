defmodule CinderDevWeb.NextDaisyLive do
  @moduledoc """
  The shell-rewrite spike, built entirely from daisyUI markup with no Cinder
  default components: every interactive element spreads an attribute map from the
  collection view-model. The filters modal is teleported to `<body>` with a portal,
  so its inputs sit outside the component's DOM and join the form through `form=`.
  """
  use CinderDevWeb, :live_view
  use Cinder.UrlSync

  @impl true
  def mount(_params, _session, socket) do
    artists = Music.Artist |> Ash.read!() |> Enum.map(&{&1.name, &1.name}) |> Enum.sort()
    {:ok, assign(socket, :artists, artists)}
  end

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
        :let={c}
        id="daisy"
        resource={Music.Album}
        layout="custom"
        url_state={@url_state}
        query_opts={[load: [:artist]]}
        page_size={12}
        search={[fields: ["title", "artist.name"]]}
      >
        <:filter field="genre" type="select" prompt="All" />
        <:filter field="title" type="text" help="Matches anywhere in the title" />
        <:filter
          field="tags"
          type="multi_checkboxes"
          options={Enum.map(CinderDev.Seeds.tags(), &{&1, &1})}
        />
        <:filter field="price" type="number_range" label="Price ($)" />
        <:filter
          field="artist.name"
          type="autocomplete"
          label="Artist"
          options={@artists}
          max_results={5}
        />
        <:sort field="title" />
        <:sort field="price" label="Price" />
        <:sort field="release_date" label="Released" />

        <div class="space-y-4">
          <div class="flex flex-wrap items-center gap-3">
            <label class="input">
              <.icon name="hero-magnifying-glass" class="size-4 opacity-50" />
              <input {c.search.input_attrs} class="grow" />
            </label>

            <button type="button" class="btn" onclick="daisy_filters.showModal()">
              Filters
              <span :if={c.active_filter_count > 0} class="badge badge-primary badge-sm">
                {c.active_filter_count}
              </span>
            </button>

            <%!-- A select filter as a button group, from each option's radio attrs --%>
            <div class="join">
              <input
                :for={option <- c.filters_by_field["genre"].options}
                class="join-item btn btn-sm"
                {option.input_attrs}
              />
            </div>

            <span :if={c.status == :loading} class="loading loading-spinner loading-sm"></span>
          </div>

          <div class="flex flex-wrap items-center gap-2">
            <span class="text-sm opacity-70">Sort:</span>
            <%!-- Chips: additive, from each sort's attrs --%>
            <button
              :for={sort <- c.sorts}
              class={["btn btn-xs", sort.direction && "btn-primary"]}
              {sort.attrs}
            >
              {sort.label}
              <span :if={sort.direction}>{if sort.direction == :asc, do: "↑", else: "↓"}</span>
            </button>
            <span class="divider divider-horizontal mx-0"></span>
            <%!-- The same sorts as an exclusive dropdown --%>
            <select class="select select-sm w-auto" {c.sort_select.select_attrs}>
              <option :for={option <- c.sort_select.options} {option.attrs}>{option.label}</option>
            </select>
          </div>

          <.daisy_pagination :if={c.pagination} pagination={c.pagination} />

          <div class="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
            <div :for={row <- c.rows} class="card bg-base-100 card-border" {row.attrs}>
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

          <div :if={c.rows == [] and c.status == :idle} class="alert">No albums match.</div>

          <.daisy_pagination :if={c.pagination} pagination={c.pagination} />
        </div>

        <%!-- Teleported to <body>: these inputs are outside the component's DOM entirely --%>
        <.portal id="daisy-filters-portal" target="body">
          <%!-- showModal() sets `open` in the browser; without this, every re-render
               (like a filter change) would strip it and leave the page inert --%>
          <dialog
            id="daisy_filters"
            class="modal"
            phx-mounted={JS.ignore_attributes(["open"])}
          >
            <div class="modal-box space-y-4">
              <h3 class="text-lg font-bold">Filters</h3>
              <% title = c.filters_by_field["title"] %>
              <fieldset class="fieldset">
                <legend class="fieldset-legend">
                  {title.label}
                  <span class="tooltip" data-tip={title.help}>
                    <.icon name="hero-question-mark-circle" class="size-4 opacity-60" />
                  </span>
                  <.clear filter={title} />
                </legend>
                <input class="input w-full" {title.input_attrs} />
                <p class="label" {title.help_attrs}>{title.help}</p>
              </fieldset>
              <% artist = c.filters_by_field["artist.name"] %>
              <fieldset class="fieldset">
                <legend class="fieldset-legend">{artist.label} <.clear filter={artist} /></legend>
                <input class="input w-full" {artist.input_attrs} />
                <div class="flex flex-wrap gap-1">
                  <input
                    :for={option <- artist.options}
                    class="btn btn-xs"
                    aria-label={option.label}
                    {option.input_attrs}
                  />
                </div>
              </fieldset>

              <% tags = c.filters_by_field["tags"] %>
              <fieldset class="fieldset">
                <legend class="fieldset-legend">{tags.label} <.clear filter={tags} /></legend>
                <div class="flex flex-wrap gap-x-4 gap-y-2">
                  <label :for={option <- tags.options} class="label">
                    <input class="checkbox checkbox-sm" {option.input_attrs} /> {option.label}
                  </label>
                </div>
              </fieldset>

              <% price = c.filters_by_field["price"] %>
              <fieldset class="fieldset">
                <legend class="fieldset-legend">{price.label} <.clear filter={price} /></legend>
                <div class="join">
                  <input class="input join-item" {price.input_attrs.min} />
                  <input class="input join-item" {price.input_attrs.max} />
                </div>
              </fieldset>

              <div class="modal-action">
                <button class="btn btn-ghost" {c.clear_all_attrs}>Clear all</button>
                <form method="dialog"><button class="btn">Done</button></form>
              </div>
            </div>
            <form method="dialog" class="modal-backdrop"><button>close</button></form>
          </dialog>
        </.portal>
      </Cinder.Next.collection>
    </Layouts.app>
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
