defmodule Cinder.Renderers.Table do
  @moduledoc """
  Renderer for table layout.

  This module contains the render function and helper components for
  displaying data in a traditional HTML table format.
  """

  use Phoenix.Component
  use Cinder.Messages

  import Cinder.Renderers.Helpers

  alias Cinder.Renderers.BulkActions
  alias Cinder.Renderers.InfiniteStream
  alias Cinder.Renderers.Pagination
  alias Cinder.Renderers.SortIcon
  alias Cinder.Selection

  @doc """
  Renders the table layout.
  """
  def render(assigns) do
    assigns =
      assigns
      |> assign_infinite_defaults()
      |> assign_new(:show_item_numbers, fn -> false end)
      |> assign_new(:current_page, fn -> 1 end)

    ~H"""
    <div
      class={[@theme.container_class, "relative"]}
      data-key="container_class"
      data-cinder-infinite-root={@pagination_mode == :infinite}
      data-selected-ids={if @pagination_mode == :infinite, do: InfiniteStream.encode_selected_ids(@selected_ids, Map.get(assigns, :infinite_item_ids))}
      data-selected-classes={if @pagination_mode == :infinite, do: InfiniteStream.encode_selected_classes(InfiniteStream.selected_classes(Map.get(@theme, :selected_row_class)))}
      id={if @pagination_mode == :infinite, do: "#{@id}-infinite-stream"}
      phx-hook={if @pagination_mode == :infinite, do: "CinderInfiniteStream"}
    >
      <!-- Filter Controls (including search) -->
      <div :if={@show_filters} class={@theme.controls_class} data-key="controls_class">
        <Cinder.FilterManager.render_filter_controls
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

      <!-- Main table -->
      <div class={@theme.table_wrapper_class} data-key="table_wrapper_class">
        <table class={@theme.table_class} data-key="table_class">
          <thead class={@theme.thead_class} data-key="thead_class">
            <tr class={@theme.header_row_class} data-key="header_row_class">
              <th :if={@show_item_numbers} class={[@theme.th_class, "w-10"]} data-item-number-heading>
                #
              </th>
              <th :if={Selection.enabled?(@selectable)} class={[@theme.th_class, "w-10"]} data-key="th_class">
                <input
                  type="checkbox"
                  checked={all_page_selected?(@selected_ids, @data, @id_field, @selectable, @pagination_mode, @infinite_selectable_ids)}
                  phx-click="toggle_select_all_page"
                  phx-target={@myself}
                  class={@theme.selection_checkbox_class}
                  data-key="selection_checkbox_class"
                />
              </th>
              <th :for={column <- @columns} class={[@theme.th_class, column.class]} data-key="th_class">
                <div :if={column.sortable}
                     class={["cursor-pointer select-none", (@loading && "opacity-75" || "")]}
                     phx-click="toggle_sort"
                     phx-value-key={column.field}
                     phx-target={@myself}>
                     {column.label}
                     <span class={@theme.sort_indicator_class} data-key="sort_indicator_class">
                       <SortIcon.sort_icon sort_direction={Cinder.QueryBuilder.get_sort_direction(@sort_by, column.field)} theme={@theme} loading={@loading} />
                     </span>
                </div>
                <div :if={not column.sortable}>
                  {column.label}
                </div>
              </th>
            </tr>
          </thead>
          <tbody
            id={"#{@id}-items"}
            class={[@theme.tbody_class, (@loading && "opacity-75" || "")]}
            data-key="tbody_class"
            phx-update={if @pagination_mode == :infinite, do: "stream"}
          >
            <tr
                :for={{dom_id, payload} <- @stream_items} :if={@pagination_mode == :infinite}
                id={dom_id}
                class={selection_classes(@theme.row_class, Map.get(assigns, :item_class), @row_click, @selectable, @selected_ids, payload.record, @id_field, Map.get(@theme, :selected_row_class))}
                data-item-id={payload.id}
                data-item-number={payload.number}
                data-key="row_class"
                phx-click={selection_click_action(@row_click, @selectable, @selected_ids, payload.record, @id_field, @myself)}>
              <td :if={@show_item_numbers} class={[@theme.td_class, "w-10"]} data-item-number>
                {payload.number}
              </td>
              <td :if={Selection.enabled?(@selectable)} class={[@theme.td_class, "w-10"]} data-key="td_class">
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
              </td>
              <td :for={column <- @columns} class={[@theme.td_class, column.class]} data-key="td_class">
                {render_slot(column.slot, payload.record)}
              </td>
            </tr>
            <tr :for={{item, index} <- Enum.with_index(@data)} :if={@pagination_mode != :infinite and not @error}
                class={selection_classes(@theme.row_class, Map.get(assigns, :item_class), @row_click, @selectable, @selected_ids, item, @id_field, Map.get(@theme, :selected_row_class))}
                data-item-id={to_string(Map.get(item, @id_field))}
                data-item-number={item_number(index, @pagination_mode, @current_page, @page)}
                data-key="row_class"
                phx-click={selection_click_action(@row_click, @selectable, @selected_ids, item, @id_field, @myself)}>
              <td :if={@show_item_numbers} class={[@theme.td_class, "w-10"]} data-item-number>
                {item_number(index, @pagination_mode, @current_page, @page)}
              </td>
              <td :if={Selection.enabled?(@selectable)} class={[@theme.td_class, "w-10"]} data-key="td_class">
                <input
                  type="checkbox"
                  disabled={not Selection.item_toggleable?(@selectable, @selected_ids, item, @id_field)}
                  checked={Selection.item_selected?(@selected_ids, item, @id_field)}
                  phx-click="toggle_select"
                  phx-value-id={to_string(Map.get(item, @id_field))}
                  phx-target={@myself}
                  class={@theme.selection_checkbox_class}
                  data-key="selection_checkbox_class"
                />
              </td>
              <td :for={column <- @columns} class={[@theme.td_class, column.class]} data-key="td_class">
                {render_slot(column.slot, item)}
              </td>
            </tr>
            <tr id={"#{@id}-error"} :if={@pagination_mode != :infinite and @error and not @loading}>
              <td colspan={column_count(@columns, @selectable, @show_item_numbers)} class={@theme.empty_class} data-key="error_class">
                <%= if has_slot?(assigns, :error_slot) do %>
                  {render_slot(@error_slot)}
                <% else %>
                  <div class={@theme.error_container_class} data-key="error_container_class">
                    <span class={@theme.error_message_class} data-key="error_message_class">{@error_message}</span>
                  </div>
                <% end %>
              </td>
            </tr>
            <tr id={"#{@id}-empty"} :if={@pagination_mode != :infinite and @data == [] and not @loading and not @error}>
              <td colspan={column_count(@columns, @selectable, @show_item_numbers)} class={@theme.empty_class} data-key="empty_class">
                <%= if has_slot?(assigns, :empty_slot) do %>
                  {render_slot(@empty_slot, empty_context(assigns))}
                <% else %>
                  {@empty_message}
                <% end %>
              </td>
            </tr>
          </tbody>
        </table>
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

      <div :if={@pagination_mode == :infinite and @infinite_loaded_count == 0 and not @loading and not @error} class={@theme.empty_class} data-key="empty_class">
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
  # HELPER FUNCTIONS
  # ============================================================================

  defp all_page_selected?(selected_ids, _data, _id_field, _selectable, :infinite, selectable_ids) do
    not Enum.empty?(selectable_ids) and MapSet.subset?(selectable_ids, selected_ids)
  end

  defp all_page_selected?(selected_ids, data, id_field, selectable, _mode, _selectable_ids)
       when is_list(data) do
    selectable_items = Enum.filter(data, &Selection.item_selectable?(selectable, &1))

    selectable_items != [] and
      Enum.all?(selectable_items, fn item ->
        Selection.item_selected?(selected_ids, item, id_field)
      end)
  end

  defp all_page_selected?(_selected_ids, _data, _id_field, _selectable, _mode, _ids), do: false

  defp column_count(columns, selectable, show_item_numbers) do
    base_count = length(columns)
    selection_count = if Selection.enabled?(selectable), do: 1, else: 0
    number_count = if show_item_numbers, do: 1, else: 0
    base_count + selection_count + number_count
  end
end
