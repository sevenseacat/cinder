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
        :let={c}
        id="petal"
        resource={Music.Album}
        layout="custom"
        url_state={@url_state}
        query_opts={[load: [:artist]]}
        page_size={10}
        search={[fields: ["title", "artist.name"]]}
      >
        <:filter field="genre" type="select" prompt="All genres" />
        <:filter
          field="tags"
          type="multi_checkboxes"
          options={Enum.map(CinderDev.Seeds.tags(), &{&1, &1})}
        />
        <:filter field="price" type="number_range" label="Price ($)" />
        <%!-- Petal's table builds its own sortable headers, from its own columns --%>
        <:sort field="title" />
        <:sort field="price" />
        <:sort field="release_date" />

        <div class="space-y-4">
          <div class="grid gap-x-4 sm:grid-cols-2 lg:grid-cols-4">
            <Field.field {attrs(c.search.input_attrs)} label={c.search.label} />

            <% genre = c.filters_by_field["genre"] %>
            <%!-- The prompt is the first of the view-model's options --%>
            <Field.field
              {attrs(genre.input_attrs)}
              type="select"
              label={genre.label}
              options={Enum.map(genre.options, &{&1.label, &1.value})}
            />

            <% price = c.filters_by_field["price"] %>
            <Field.field {attrs(price.input_attrs.min)} label={"Min #{price.label}"} />
            <Field.field {attrs(price.input_attrs.max)} label={"Max #{price.label}"} />
          </div>

          <% tags = c.filters_by_field["tags"] %>
          <Field.field
            type="checkbox-group"
            group_layout="row"
            name={tags.name}
            value={tags.value}
            label={tags.label}
            options={Enum.map(tags.options, &{&1.label, &1.value})}
            form={c.form_attrs["id"]}
          />

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

  # Petal's components fill their declared attrs (`name`, `value`, `type`...) only
  # from atom keys; string keys all land in `rest`, so the input renders but the
  # component never sees its own name or value
  defp attrs(map), do: Map.new(map, fn {key, value} -> {String.to_atom(key), value} end)
end
