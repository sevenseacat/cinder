defmodule CinderDevWeb.NextPetalLive do
  @moduledoc """
  The shell-rewrite spike, built from Petal Components: Petal's own table, fields
  and pagination, fed from collections kept in this LiveView. Unlike daisyUI, these
  are function components with their own attrs, so the attribute maps go in as
  component attrs, and the table and pagination take an event rather than
  attribute maps.
  """
  use CinderDevWeb, :live_view
  use Cinder.Next.LiveView

  alias Cinder.Next.LiveView
  alias PetalComponents.{Badge, Button, Field, Loading, Pagination, Table}

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> LiveView.assign_collection(:petal, Music.Album,
       url: true,
       load: [:artist],
       page_size: 10,
       search: [fields: ["title", "artist.name"]],
       filters: [
         genre: [type: :select, prompt: "All genres"],
         tags: [type: :multi_checkboxes, options: Enum.map(CinderDev.Seeds.tags(), &{&1, &1})],
         price: [type: :number_range, label: "Price ($)"]
       ],
       # Petal's table builds its own sortable headers, from its own columns
       sorts: [:title, :price, :release_date]
     )
     |> LiveView.assign_collection(:core, Music.Album,
       action: :with_min_tracks,
       page_size: 5,
       arguments: [min_tracks: [label: "At least this many tracks"]],
       filters: [genre: :select, price: :number_range]
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
      <div {@petal.attrs} class="space-y-4">
        <%!-- Petal's inputs assume they're inside a form, so they are --%>
        <form {@petal.form_attrs} class="space-y-4">
          <div class="grid gap-x-4 sm:grid-cols-2 lg:grid-cols-4">
            <Field.field {attrs(@petal.search.input_attrs)} label={@petal.search.label} />
            <Field.field
              field={@petal.filters["genre"].form_field}
              type="select"
              label={@petal.filters["genre"].label}
              options={options(@petal.filters["genre"])}
            />
            <div class="lg:col-span-2">
              <%!-- Petal's slider only takes FormFields. Its hook posts both bounds. --%>
              <Field.field
                type="range-dual"
                min_field={@petal.filters["price"].form_field.min}
                max_field={@petal.filters["price"].form_field.max}
                range_min={0}
                range_max={30}
                value_prefix="$"
                label={@petal.filters["price"].label}
              />
            </div>
          </div>
          <Field.field
            field={@petal.filters["tags"].form_field}
            type="checkbox-group"
            group_layout="row"
            label={@petal.filters["tags"].label}
            options={options(@petal.filters["tags"])}
          />
        </form>

        <div class="flex items-center gap-3">
          <Button.button
            {attrs(@petal.clear_all_attrs)}
            link_type="button"
            variant="outline"
            size="sm"
            disabled={@petal.active_filter_count == 0}
          >
            Clear filters
            <Badge.badge
              :if={@petal.active_filter_count > 0}
              size="xs"
              label={to_string(@petal.active_filter_count)}
            />
          </Button.button>
          <Loading.spinner show={@petal.status == :loading} />
        </div>

        <.petal_pagination collection={@petal} />

        <Table.table
          rows={@petal.rows}
          row_item={& &1.record}
          sort_by={@petal.primary_sort && @petal.primary_sort.field}
          sort_dir={if @petal.primary_sort, do: to_string(@petal.primary_sort.direction), else: "asc"}
          on_sort={&Cinder.Next.sort_command(@petal, &1)}
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

        <.petal_pagination collection={@petal} />
      </div>

      <h2 class="mt-12 text-lg font-semibold">
        Phoenix's generated core_components (not URL-synced)
      </h2>
      <div {@core.attrs}>
        <form {@core.form_attrs} class="grid gap-x-4 sm:grid-cols-4">
          <.input
            field={@core.filters["min_tracks"].form_field}
            type="number"
            label={@core.filters["min_tracks"].label}
          />
          <.input
            field={@core.filters["genre"].form_field}
            type="select"
            label={@core.filters["genre"].label}
            options={options(@core.filters["genre"])}
          />
          <.input field={@core.filters["price"].form_field.min} type="number" label="Min price" />
          <.input field={@core.filters["price"].form_field.max} type="number" label="Max price" />
        </form>
        <ul :if={@core.status == :idle}>
          <li :for={row <- @core.rows}>{row.record.title} ({row.record.track_count} tracks)</li>
        </ul>
      </div>
    </Layouts.app>
    """
  end

  attr :collection, :map, required: true

  defp petal_pagination(assigns) do
    ~H"""
    <div :if={@collection.pagination} class="flex items-center justify-between">
      <span class="text-sm opacity-70">{@collection.pagination.summary}</span>
      <Pagination.pagination
        event={@collection.event_prefix <> "go_to_page"}
        target={@collection.target}
        current_page={@collection.pagination.page}
        total_pages={@collection.pagination.page_count}
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
