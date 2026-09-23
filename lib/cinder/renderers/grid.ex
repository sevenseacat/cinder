defmodule Cinder.Renderers.Grid do
  @moduledoc """
  Renderer for grid/card layout.

  This module contains the render function for displaying data in a
  responsive grid format with sort controls rendered as a button group.
  """

  use Phoenix.Component
  use Cinder.Messages
  require Logger

  import Cinder.Renderers.Helpers

  alias Cinder.Renderers.BulkActions
  alias Cinder.Renderers.InfiniteStream
  alias Cinder.Renderers.Pagination
  alias Cinder.Renderers.SortControls
  alias Cinder.Selection

  @doc """
  Renders the grid layout.
  """
  def render(assigns) do
    has_item_slot = Map.get(assigns, :item_slot, []) != []

    unless has_item_slot do
      Logger.warning("Cinder.Grid: No <:item> slot provided. Items will not be rendered.")
    end

    container_class =
      get_container_class(assigns.container_class, assigns.grid_columns, assigns.theme)

    {item_class, item_data_key} = get_item_classes(assigns.theme, assigns.item_click)

    assigns =
      assigns
      |> assign_infinite_defaults()
      |> assign_new(:show_item_numbers, fn -> false end)
      |> assign_new(:current_page, fn -> 1 end)
      |> assign(:has_item_slot, has_item_slot)
      |> assign(:grid_container_class, container_class)
      |> assign(:grid_item_class, item_class)
      |> assign(:grid_item_data_key, item_data_key)

    ~H"""
    <div
      class={[@theme.container_class, "relative"]}
      data-key="container_class"
      data-cinder-infinite-root={@pagination_mode == :infinite}
      data-selected-ids={if @pagination_mode == :infinite, do: InfiniteStream.encode_selected_ids(@selected_ids, Map.get(assigns, :infinite_item_ids))}
      data-selected-classes={if @pagination_mode == :infinite, do: InfiniteStream.encode_selected_classes(InfiniteStream.selected_classes(Map.get(@theme, :selected_item_class)))}
      id={if @pagination_mode == :infinite, do: "#{@id}-infinite-stream"}
      phx-hook={if @pagination_mode == :infinite, do: "CinderInfiniteStream"}
    >
      <!-- Controls Area (filters + sort) -->
      <div :if={@show_filters || (@show_sort && SortControls.has_sortable_columns?(@columns))} class={[@theme.controls_class, "!flex !flex-col"]} data-key="controls_class">
        <!-- Filter Controls (including search) -->
        <Cinder.FilterManager.render_filter_controls
          :if={@show_filters}
          table_id={@id}
          columns={Map.get(assigns, :query_columns, @columns)}
          filters={@filters}
          theme={@theme}
          target={@myself}
          filters_label={@filters_label}
          filter_mode={@show_filters}
          search_term={@search_term}
          show_search={@search_enabled}
          search_label={@search_label}
          search_placeholder={@search_placeholder}
          raw_filter_params={Map.get(assigns, :raw_filter_params, %{})}
          controls_slot={Map.get(assigns, :controls_slot, [])}
        />

        <!-- Sort Controls (button group since no table headers) -->
        <SortControls.render
          :if={@show_sort}
          columns={@columns}
          sort_by={@sort_by}
          sort_label={@sort_label}
          theme={@theme}
          myself={@myself}
          loading={@loading}
        />
      </div>

      <!-- Bulk Actions -->
      <BulkActions.render
        selectable={@selectable}
        selected_ids={@selected_ids}
        bulk_action_slots={@bulk_action_slots}
        theme={@theme}
        myself={@myself}
      />

      <InfiniteStream.top_sentinel
        id={@id}
        myself={@myself}
        theme={@theme}
        show={@pagination_mode == :infinite and @infinite_has_previous and not @loading and not @error}
      />

      <!-- Grid Items Container -->
      <div
        id={"#{@id}-items"}
        class={@grid_container_class}
        data-key="grid_container_class"
        phx-update={if @pagination_mode == :infinite, do: "stream"}
      >
        <%= if @has_item_slot do %>
          <div
            :for={{dom_id, payload} <- @stream_items} :if={@pagination_mode == :infinite}
            id={dom_id}
            class={selection_classes(@grid_item_class, Map.get(assigns, :item_class), @item_click, Map.get(assigns, :selectable, false), Map.get(assigns, :selected_ids, MapSet.new()), payload.record, Map.get(assigns, :id_field, :id), Map.get(@theme, :selected_item_class))}
            data-item-id={payload.id}
            data-item-number={payload.number}
            data-key={@grid_item_data_key}
            phx-click={selection_click_action(@item_click, Map.get(assigns, :selectable, false), Map.get(assigns, :selected_ids, MapSet.new()), payload.record, Map.get(assigns, :id_field, :id), @myself)}
          >
            <span :if={@show_item_numbers} class={@theme.pagination_count_class} data-item-number>
              {payload.number}.
            </span>
            <div
              :if={Selection.enabled?(Map.get(assigns, :selectable, false))}
              class={@theme.grid_selection_overlay_class}
              data-key="grid_selection_overlay_class"
            >
              <input
                type="checkbox"
                disabled={not Selection.item_toggleable?(@selectable, @selected_ids, payload.record, @id_field)}
                checked={Selection.item_selected?(@selected_ids, payload.record, @id_field)}
                phx-click="toggle_select"
                phx-value-id={payload.id}
                phx-target={@myself}
                class={@theme.selection_checkbox_class}
                data-cinder-selection-checkbox
                data-key="selection_checkbox_class"
              />
            </div>
            {render_slot(@item_slot, payload.record)}
          </div>
          <div
            :for={{item, index} <- Enum.with_index(@data)} :if={@pagination_mode != :infinite and not @error}
            class={selection_classes(@grid_item_class, Map.get(assigns, :item_class), @item_click, Map.get(assigns, :selectable, false), Map.get(assigns, :selected_ids, MapSet.new()), item, Map.get(assigns, :id_field, :id), Map.get(@theme, :selected_item_class))}
            data-item-id={to_string(Map.get(item, @id_field))}
            data-item-number={item_number(index, @pagination_mode, @current_page, @page)}
            data-key={@grid_item_data_key}
            phx-click={selection_click_action(@item_click, Map.get(assigns, :selectable, false), Map.get(assigns, :selected_ids, MapSet.new()), item, Map.get(assigns, :id_field, :id), @myself)}
          >
            <span
              :if={@show_item_numbers}
              class={@theme.pagination_count_class}
              data-item-number
            >
              {item_number(index, @pagination_mode, @current_page, @page)}.
            </span>
            <div
              :if={Selection.enabled?(Map.get(assigns, :selectable, false))}
              class={@theme.grid_selection_overlay_class}
              data-key="grid_selection_overlay_class"
            >
              <input
                type="checkbox"
                disabled={not Selection.item_toggleable?(Map.get(assigns, :selectable, false), Map.get(assigns, :selected_ids, MapSet.new()), item, Map.get(assigns, :id_field, :id))}
                checked={Selection.item_selected?(Map.get(assigns, :selected_ids, MapSet.new()), item, Map.get(assigns, :id_field, :id))}
                phx-click="toggle_select"
                phx-value-id={to_string(Map.get(item, Map.get(assigns, :id_field, :id)))}
                phx-target={@myself}
                class={@theme.selection_checkbox_class}
                data-key="selection_checkbox_class"
              />
            </div>
            {render_slot(@item_slot, item)}
          </div>
        <% else %>
          <!-- No item slot provided - render message -->
          <div :if={not @loading} class={@theme.empty_class} data-key="empty_class">
            No item template provided. Add an &lt;:item&gt; slot to render items.
          </div>
        <% end %>

        <div id={"#{@id}-error"} :if={@pagination_mode != :infinite and @error and not @loading} class={[@theme.empty_class, "col-span-full"]} data-key="error_class">
          <%= if has_slot?(assigns, :error_slot) do %>
            {render_slot(@error_slot)}
          <% else %>
            <div class={@theme.error_container_class} data-key="error_container_class">
              <span class={@theme.error_message_class} data-key="error_message_class">{@error_message}</span>
            </div>
          <% end %>
        </div>

        <div id={"#{@id}-empty"} :if={@pagination_mode != :infinite and @data == [] and not @loading and not @error and @has_item_slot} class={[@theme.empty_class, "col-span-full"]} data-key="empty_class">
          <%= if has_slot?(assigns, :empty_slot) do %>
            {render_slot(@empty_slot, empty_context(assigns))}
          <% else %>
            {@empty_message}
          <% end %>
        </div>
      </div>

      <div :if={@pagination_mode == :infinite and @error and @infinite_loaded_count == 0 and not @loading} class={@theme.empty_class} data-key="error_class">
        <%= if has_slot?(assigns, :error_slot) do %>
          {render_slot(@error_slot)}
        <% else %>
          <div class={@theme.error_container_class} data-key="error_container_class">
            <span class={@theme.error_message_class} data-key="error_message_class">{@error_message}</span>
          </div>
        <% end %>
      </div>

      <div :if={@pagination_mode == :infinite and @infinite_loaded_count == 0 and not @loading and not @error and @has_item_slot} class={@theme.empty_class} data-key="empty_class">
        <%= if has_slot?(assigns, :empty_slot) do %>
          {render_slot(@empty_slot, empty_context(assigns))}
        <% else %>
          {@empty_message}
        <% end %>
      </div>

      <!-- Loading indicator -->
      <div :if={@loading and (@pagination_mode != :infinite or @infinite_loaded_count == 0)} class={@theme.loading_overlay_class} data-key="loading_overlay_class">
        <%= if has_slot?(assigns, :loading_slot) do %>
          {render_slot(@loading_slot)}
        <% else %>
          <div class={@theme.loading_container_class} data-key="loading_container_class">
            <svg class={@theme.loading_spinner_class} data-key="loading_spinner_class" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
              <circle class={@theme.loading_spinner_circle_class} data-key="loading_spinner_circle_class" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
              <path class={@theme.loading_spinner_path_class} data-key="loading_spinner_path_class" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
            </svg>
            {@loading_message}
          </div>
        <% end %>
      </div>

      <!-- Pagination -->
      <Pagination.render
        page={@page}
        page_size_config={@page_size_config}
        theme={@theme}
        myself={@myself}
        show_pagination={@show_pagination}
        pagination_mode={@pagination_mode}
        total_count={@total_count}
        count_mode={@count_mode}
        current_page={@current_page}
        loaded_count={if(@pagination_mode == :infinite, do: @infinite_loaded_count, else: length(@data))}
        range_start={@infinite_range_start}
        range_end={@infinite_range_end}
        has_previous={@infinite_has_previous}
        has_next={@infinite_has_next}
        loading={@loading}
        error={@error}
        infinite_load={Map.get(assigns, :infinite_load, :automatic)}
        overscan={Map.get(assigns, :overscan, 1)}
        load_more_label={Map.get(assigns, :load_more_label)}
        id={@id}
      />
    </div>
    """
  end

  # ============================================================================
  # CONTAINER AND ITEM HELPERS
  # ============================================================================

  # Explicit container_class override takes precedence
  defp get_container_class(custom_class, _grid_columns, _theme) when is_binary(custom_class) do
    custom_class
  end

  # Build from theme base + grid_columns
  defp get_container_class(nil, grid_columns, theme) do
    base = Map.get(theme, :grid_container_class, "grid gap-4")
    cols = build_grid_cols(grid_columns)
    [base, cols]
  end

  defp build_grid_cols(cols) when is_binary(cols) do
    build_grid_cols(String.to_integer(cols))
  end

  defp build_grid_cols(cols) when is_integer(cols) and cols in 1..12 do
    "grid grid-cols-#{cols}"
  end

  # If an invalid number is provided, default to 3
  defp build_grid_cols(cols) when is_integer(cols), do: "grid-cols-3"

  defp build_grid_cols(cols) when is_list(cols) do
    Enum.map(cols, &breakpoint_class/1)
  end

  defp build_grid_cols(_), do: "grid-cols-3"

  defp breakpoint_class({:xs, cols}), do: "grid-cols-#{cols}"
  defp breakpoint_class({:sm, cols}), do: "sm:grid-cols-#{cols}"
  defp breakpoint_class({:md, cols}), do: "md:grid-cols-#{cols}"
  defp breakpoint_class({:lg, cols}), do: "lg:grid-cols-#{cols}"
  defp breakpoint_class({:xl, cols}), do: "xl:grid-cols-#{cols}"
  defp breakpoint_class({:"2xl", cols}), do: "2xl:grid-cols-#{cols}"
  defp breakpoint_class(_), do: nil

  defp get_item_classes(theme, item_click) do
    base =
      Map.get(theme, :grid_item_class, "p-4 bg-white border border-gray-200 rounded-lg shadow-sm")

    if item_click do
      clickable =
        Map.get(
          theme,
          :grid_item_clickable_class,
          "cursor-pointer hover:shadow-md transition-shadow"
        )

      {[base, clickable], "grid_item_clickable_class"}
    else
      {base, "grid_item_class"}
    end
  end

  # Tailwind safelist - these classes are dynamically generated, keep them here for purge detection:
  # grid-cols-1 grid-cols-2 grid-cols-3 grid-cols-4 grid-cols-5 grid-cols-6 grid-cols-7 grid-cols-8 grid-cols-9 grid-cols-10 grid-cols-11 grid-cols-12
  # sm:grid-cols-1 sm:grid-cols-2 sm:grid-cols-3 sm:grid-cols-4 sm:grid-cols-5 sm:grid-cols-6
  # md:grid-cols-1 md:grid-cols-2 md:grid-cols-3 md:grid-cols-4 md:grid-cols-5 md:grid-cols-6
  # lg:grid-cols-1 lg:grid-cols-2 lg:grid-cols-3 lg:grid-cols-4 lg:grid-cols-5 lg:grid-cols-6
  # xl:grid-cols-1 xl:grid-cols-2 xl:grid-cols-3 xl:grid-cols-4 xl:grid-cols-5 xl:grid-cols-6
  # 2xl:grid-cols-1 2xl:grid-cols-2 2xl:grid-cols-3 2xl:grid-cols-4 2xl:grid-cols-5 2xl:grid-cols-6
end
