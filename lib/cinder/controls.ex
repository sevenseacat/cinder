defmodule Cinder.Controls do
  @moduledoc """
  Data preparation and render helpers for custom filter/search control layouts.

  When using the `:controls` slot on `Cinder.collection`, this module provides
  helpers to render individual filters, search inputs, and headers while keeping
  Cinder's state management, URL sync, and query building intact.

  ## Usage

  The `:controls` slot receives a controls data map via `:let`. Shared context
  (theme, target, filter values) is stored once at the top level — pass it
  explicitly to render helpers:

      <Cinder.collection resource={MyApp.User}>
        <:col field="name" filter sort search />
        <:col field="status" filter={:select} />

        <:controls :let={controls}>
          <div class="flex items-center gap-4 mb-4">
            <Cinder.Controls.render_search
              search={controls.search}
              theme={controls.theme}
              target={controls.target}
            />
          </div>
          <div class="grid grid-cols-2 gap-4">
            <Cinder.Controls.render_filter
              :for={{_name, filter} <- controls.filters}
              filter={filter}
              theme={controls.theme}
              target={controls.target}
            />
          </div>
        </:controls>
      </Cinder.collection>

  ## Selective rendering

  Filters is a keyword list keyed by field name, so you can access individual
  filters directly:

      <:controls :let={controls}>
        <Cinder.Controls.render_header {controls} />
        <div class="flex gap-2">
          <Cinder.Controls.render_filter
            filter={controls.filters[:status]}
            theme={controls.theme}
            target={controls.target}
          />
          <Cinder.Controls.render_filter
            filter={controls.filters[:name]}
            theme={controls.theme}
            target={controls.target}
          />
        </div>
      </:controls>
  """

  use Phoenix.Component
  use Cinder.Messages

  alias Cinder.FilterManager
  alias Phoenix.LiveView.JS

  import Cinder.Filter, only: [filter_id: 2]

  @doc """
  Builds the controls data map from FilterManager assigns.

  Returns a map with all the data needed to render custom filter controls:

  - `:filters` — keyword list of filter data maps keyed by field atom, preserving column order.
      Access by name: `controls.filters[:status]`. Iterate: `for {_name, filter} <- controls.filters`.
  - `:search` — search input data map (value, name, label, placeholder, id), or `nil` when disabled
  - `:active_filter_count` — number of currently active filters
  - `:target` — LiveComponent target for `phx-target`
  - `:theme` — resolved theme map
  - `:table_id` — table DOM ID prefix
  - `:filters_label` — translated label for the filters section
  - `:filter_mode` — current filter display mode
  - `:filter_values` — shared filter values map (for render helpers)
  - `:raw_filter_params` — raw form params (for autocomplete filters)
  """
  def build_controls_data(assigns) do
    filterable_columns = Enum.filter(assigns.columns, & &1.filterable)
    filter_values = FilterManager.build_filter_values(filterable_columns, assigns.filters)
    active_filter_count = FilterManager.count_active_filters(assigns.filters)
    raw_filter_params = Map.get(assigns, :raw_filter_params, %{})
    filter_mode = Map.get(assigns, :filter_mode, true)

    filters =
      Enum.map(filterable_columns, fn column ->
        current_value = Map.get(filter_values, column.field, "")
        key = String.to_atom(column.field)

        {key,
         %{
           field: column.field,
           label: column.label,
           type: column.filter_type,
           value: current_value,
           options: column.filter_options,
           name: "filters[#{column.field}]",
           id: filter_id(assigns.table_id, column.field)
         }}
      end)

    search =
      if Map.get(assigns, :show_search, false) do
        %{
          value: Map.get(assigns, :search_term, ""),
          name: "search",
          label: Map.get(assigns, :search_label, dgettext("cinder", "Search")),
          placeholder: Map.get(assigns, :search_placeholder, dgettext("cinder", "Search...")),
          id: filter_id(assigns.table_id, "search")
        }
      else
        nil
      end

    %{
      filters: filters,
      search: search,
      active_filter_count: active_filter_count,
      target: assigns.target,
      theme: assigns.theme,
      table_id: assigns.table_id,
      filters_label: assigns.filters_label,
      filter_mode: filter_mode,
      filter_values: filter_values,
      raw_filter_params: raw_filter_params
    }
  end

  # ============================================================================
  # RENDER HELPERS
  # ============================================================================

  @doc """
  Renders a single filter (label + input + clear button).

  Delegates to the existing `FilterManager.filter_label/1` and
  `FilterManager.filter_input/1` components.

  ## Attributes

  - `filter` — a filter data map from `build_controls_data/1`
  - `theme` — theme map (required)
  - `target` — LiveComponent target for `phx-target`
  - `filter_values` — shared filter values map (for filters referencing other values)
  - `raw_filter_params` — raw form params (for autocomplete filters)
  """
  attr :filter, :map, required: true
  attr :theme, :map, required: true
  attr :target, :any, default: nil
  attr :filter_values, :map, default: %{}
  attr :raw_filter_params, :map, default: %{}

  def render_filter(%{filter: nil} = assigns) do
    ~H""
  end

  def render_filter(assigns) do
    # Construct column-compatible map from lean filter data
    column = %{
      field: assigns.filter.field,
      label: assigns.filter.label,
      filter_type: assigns.filter.type,
      filter_options: assigns.filter.options
    }

    # Derive table_id from the filter id (strip "-filter-{field}" suffix)
    table_id = String.replace(assigns.filter.id, ~r/-filter-.*$/, "")

    assigns =
      assigns
      |> assign(:column, column)
      |> assign(:table_id, table_id)

    ~H"""
    <div class={@theme.filter_input_wrapper_class} data-key="filter_input_wrapper_class">
      <FilterManager.filter_label
        column={@column}
        table_id={@table_id}
        theme={@theme}
      />
      <FilterManager.filter_input
        column={@column}
        table_id={@table_id}
        current_value={@filter.value}
        filter_values={@filter_values}
        raw_filter_params={@raw_filter_params}
        theme={@theme}
        target={@target}
      />
    </div>
    """
  end

  @doc """
  Renders the default search input.

  ## Attributes

  - `search` — the search data map from `build_controls_data/1`
  - `theme` — theme map (required)
  - `target` — LiveComponent target for `phx-target`
  """
  attr :search, :map, default: nil
  attr :theme, :map, required: true
  attr :target, :any, default: nil

  def render_search(%{search: nil} = assigns) do
    ~H""
  end

  def render_search(assigns) do
    ~H"""
    <div class={@theme.filter_input_wrapper_class} data-key="filter_input_wrapper_class">
      <label for={@search.id} class={@theme.filter_label_class} data-key="filter_label_class">{@search.label}:</label>
      <div class="flex items-center">
        <div class="flex-1 relative">
          <input
            type="text"
            id={@search.id}
            name={@search.name}
            value={@search.value}
            placeholder={@search.placeholder}
            phx-debounce="300"
            class={@theme.search_input_class}
            data-key="search_input_class"
          />
          <div class="absolute inset-y-0 left-0 z-10 flex items-center pl-3 pointer-events-none">
            <svg class={@theme.search_icon_class} data-key="search_icon_class" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
            </svg>
          </div>
        </div>
        <button
          type="button"
          phx-click="clear_filter"
          phx-value-key="search"
          phx-target={@target}
          class={[
            @theme.filter_clear_button_class,
            unless(@search.value != "", do: "invisible", else: "")
          ]}
          data-key="filter_clear_button_class"
          title={dgettext("cinder", "Clear search")}
        >
          ×
        </button>
      </div>
    </div>
    """
  end

  @doc """
  Renders the default filter header (title, active count badge, clear all button, toggle).

  Accepts either the full controls data map or individual attributes.

  ## Attributes

  - `table_id` — DOM ID prefix
  - `filters_label` — label text for the header
  - `active_filter_count` — number of active filters
  - `filter_mode` — display mode (true, :toggle, :toggle_open)
  - `target` — LiveComponent target
  - `theme` — theme map
  """
  attr :table_id, :string, required: true
  attr :filters_label, :string, required: true
  attr :active_filter_count, :integer, required: true
  attr :filter_mode, :any, default: true
  attr :target, :any, default: nil
  attr :theme, :map, required: true
  attr :has_filters, :boolean, default: true

  def render_header(assigns) do
    collapsible = assigns.filter_mode in [:toggle, :toggle_open]
    initially_collapsed = assigns.filter_mode == :toggle

    assigns =
      assigns
      |> assign(:collapsible, collapsible)
      |> assign(:initially_collapsed, initially_collapsed)

    ~H"""
    <div class={@theme.filter_header_class} data-key="filter_header_class">
      <%= if @collapsible do %>
        <span
          class={[@theme.filter_title_class, @theme.filter_toggle_class]}
          data-key="filter_title_class"
          phx-click={toggle_filters_js(@table_id)}
        >
          <span id={"#{@table_id}-filter-toggle-expanded"} class={if(@initially_collapsed, do: "hidden")}>
            <span class={[@theme.filter_toggle_icon_class, "hero-chevron-down"]} />
          </span>
          <span id={"#{@table_id}-filter-toggle-collapsed"} class={unless(@initially_collapsed, do: "hidden")}>
            <span class={[@theme.filter_toggle_icon_class, "hero-chevron-right"]} />
          </span>
          {@filters_label}
          <span class={[@theme.filter_count_class, if(@active_filter_count == 0, do: "invisible", else: "")]} data-key="filter_count_class">
            ({@active_filter_count} {dngettext("cinder", "active", "active", @active_filter_count)})
          </span>
        </span>
      <% else %>
        <span class={@theme.filter_title_class} data-key="filter_title_class">
          {@filters_label}
          <span class={[@theme.filter_count_class, if(@active_filter_count == 0, do: "invisible", else: "")]} data-key="filter_count_class">
            ({@active_filter_count} {dngettext("cinder", "active", "active", @active_filter_count)})
          </span>
        </span>
      <% end %>
      <button
        :if={@has_filters}
        type="button"
        phx-click="clear_all_filters"
        phx-target={@target}
        class={[@theme.filter_clear_all_class, if(@active_filter_count == 0, do: "invisible", else: "")]}
        data-key="filter_clear_all_class"
      >
        {dgettext("cinder", "Clear all")}
      </button>
    </div>
    """
  end

  defp toggle_filters_js(table_id) do
    JS.toggle(to: "##{table_id}-filter-body")
    |> JS.toggle(to: "##{table_id}-filter-toggle-expanded")
    |> JS.toggle(to: "##{table_id}-filter-toggle-collapsed")
  end
end
