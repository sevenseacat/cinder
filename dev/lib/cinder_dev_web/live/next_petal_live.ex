defmodule CinderDevWeb.NextPetalLive do
  @moduledoc """
  The shell-rewrite spike, built from Petal Components: Petal's own table, fields
  and pagination, fed from the collection view-model. Unlike daisyUI, these are
  function components with their own attrs, so the attribute maps go in as
  component attrs, and the table and pagination take an event and target rather
  than attribute maps.
  """
  use CinderDevWeb, :live_view
  use Cinder.UrlSync

  alias PetalComponents.{Badge, Button, Field, Loading, Pagination, Table}

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
        id="petal"
        resource={Music.Album}
        url_state={@url_state}
        query_opts={[load: [:artist]]}
        page_size={10}
        search={[fields: ["title", "artist.name"]]}
      >
        <%!-- Each filter's Petal markup sits with its declaration; the layout places it --%>
        <:filter :let={f} field="genre" type="select" prompt="All genres">
          <Field.field field={f.form_field} type="select" label={f.label} options={options(f)} />
        </:filter>
        <:filter
          :let={f}
          field="tags"
          type="multi_checkboxes"
          options={Enum.map(CinderDev.Seeds.tags(), &{&1, &1})}
        >
          <Field.field
            field={f.form_field}
            type="checkbox-group"
            group_layout="row"
            label={f.label}
            options={options(f)}
          />
        </:filter>
        <:filter :let={f} field="price" type="number_range" label="Price ($)">
          <%!-- Petal's slider only takes FormFields. Its hook posts both bounds. --%>
          <Field.field
            type="range-dual"
            min_field={f.form_field.min}
            max_field={f.form_field.max}
            range_min={0}
            range_max={30}
            value_prefix="$"
            label={f.label}
          />
        </:filter>
        <%!-- Petal's table builds its own sortable headers, from its own columns --%>
        <:sort field="title" />
        <:sort field="price" />
        <:sort field="release_date" />
        <:page :let={c}>
          <div class="space-y-4">
            <%!-- Petal's inputs assume they're inside a form, so they are --%>
            <form {c.form_attrs} class="space-y-4">
              <div class="grid gap-x-4 sm:grid-cols-2 lg:grid-cols-4">
                <Field.field {attrs(c.search.input_attrs)} label={c.search.label} />
                <Cinder.Next.filter collection={c} field="genre" />
                <div class="lg:col-span-2"><Cinder.Next.filter collection={c} field="price" /></div>
              </div>
              <Cinder.Next.filter collection={c} field="tags" />
            </form>

            <div class="flex items-center gap-3">
              <Button.button
                {attrs(c.clear_all_attrs)}
                link_type="button"
                variant="outline"
                size="sm"
                disabled={c.active_filter_count == 0}
              >
                Clear filters
                <Badge.badge
                  :if={c.active_filter_count > 0}
                  size="xs"
                  label={to_string(c.active_filter_count)}
                />
              </Button.button>
              <Loading.spinner show={c.status == :loading} />
            </div>

            <.petal_pagination pagination={c.pagination} target={c.target} />

            <Table.table
              rows={c.rows}
              row_item={& &1.record}
              sort_by={c.primary_sort && c.primary_sort.field}
              sort_dir={if c.primary_sort, do: to_string(c.primary_sort.direction), else: "asc"}
              on_sort={&Cinder.Next.sort_command(c, &1)}
            >
              <:col :let={album} label="Title" sortable sort_key="title">{album.title}</:col>
              <:col :let={album} label="Artist">{album.artist.name}</:col>
              <:col :let={album} label="Genre">{album.genre}</:col>
              <:col :let={album} label="Price" sortable sort_key="price">
                ${Decimal.to_string(album.price)}
              </:col>
              <:col :let={album} label="Released" sortable sort_key="release_date">
                {album.release_date}
              </:col>
              <:empty_state>No albums match.</:empty_state>
            </Table.table>

            <.petal_pagination pagination={c.pagination} target={c.target} />
          </div>
        </:page>
      </Cinder.Next.collection>

      <h2 class="mt-12 text-lg font-semibold">
        Phoenix's generated core_components (not URL-synced)
      </h2>
      <Cinder.Next.collection
        id="core"
        resource={Music.Album}
        action={:with_min_tracks}
        page_size={5}
      >
        <:col :let={album} field="title">{album.title}</:col>
        <:argument name="min_tracks" label="At least this many tracks" />
        <:filter field="genre" type="select" />
        <:filter field="price" type="number_range" />
        <:page :let={c}>
          <%!-- Looked up inline instead, with the markup in the layout --%>
          <form {c.form_attrs} class="grid gap-x-4 sm:grid-cols-4">
            <.input
              field={c.filters["min_tracks"].form_field}
              type="number"
              label={c.filters["min_tracks"].label}
            />
            <.input
              field={c.filters["genre"].form_field}
              type="select"
              label={c.filters["genre"].label}
              options={options(c.filters["genre"])}
            />
            <.input field={c.filters["price"].form_field.min} type="number" label="Min price" />
            <.input field={c.filters["price"].form_field.max} type="number" label="Max price" />
          </form>
          <ul :if={c.status == :idle}>
            <li :for={row <- c.rows}>{row.record.title} ({row.record.track_count} tracks)</li>
          </ul>
        </:page>
      </Cinder.Next.collection>
    </Layouts.app>
    """
  end

  attr :pagination, :map, required: true
  attr :target, :any, required: true

  defp petal_pagination(assigns) do
    ~H"""
    <div :if={@pagination} class="flex items-center justify-between">
      <span class="text-sm opacity-70">{@pagination.summary}</span>
      <Pagination.pagination
        event="go_to_page"
        target={@target}
        current_page={@pagination.page}
        total_pages={@pagination.page_count}
      />
    </div>
    """
  end

  # Petal and core_components take options as `{label, value}` pairs. A select's
  # view-model options start with its prompt, so neither needs its own.
  defp options(filter), do: Enum.map(filter.options, &{&1.label, &1.value})

  # Petal's components fill their declared attrs (`name`, `value`, `type`...) only
  # from atom keys; string keys all land in `rest`, so the input renders but the
  # component never sees its own name or value
  defp attrs(map), do: Map.new(map, fn {key, value} -> {String.to_atom(key), value} end)
end
