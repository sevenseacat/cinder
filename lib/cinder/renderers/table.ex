defmodule Cinder.Renderers.Table do
  @moduledoc """
  Renderer for table layout.

  This module contains the render function and helper components for
  displaying data in a traditional HTML table format.
  """

  use Phoenix.Component
  use Cinder.Messages

  alias Cinder.Renderers.Pagination

  @doc """
  Renders the table layout.
  """
  def render(assigns) do
    ~H"""
    <div class={[@theme.container_class, "relative"]} {@theme.container_data}>
      <!-- Filter Controls (including search) -->
      <div :if={@show_filters} class={@theme.controls_class} {@theme.controls_data}>
        <Cinder.FilterManager.render_filter_controls
          table_id={@id}
          columns={Map.get(assigns, :query_columns, @columns)}
          filters={@filters}
          theme={@theme}
          target={@myself}
          filters_label={@filters_label}
          search_term={@search_term}
          show_search={@search_enabled}
          search_label={@search_label}
          search_placeholder={@search_placeholder}
          raw_filter_params={Map.get(assigns, :raw_filter_params, %{})}
        />
      </div>

      <!-- Main table -->
      <div class={@theme.table_wrapper_class} {@theme.table_wrapper_data}>
        <table class={@theme.table_class} {@theme.table_data}>
          <thead class={@theme.thead_class} {@theme.thead_data}>
            <tr class={@theme.header_row_class} {@theme.header_row_data}>
              <th :if={@selectable} class={@theme.selection_th_class} {@theme.selection_th_data}>
                <input
                  type="checkbox"
                  checked={all_page_selected?(@selected_ids, @data, @id_field)}
                  phx-click="toggle_select_all_page"
                  phx-target={@myself}
                  class={@theme.selection_checkbox_class}
                />
              </th>
              <th :for={column <- @columns} class={[@theme.th_class, column.class]} {@theme.th_data}>
                <div :if={column.sortable}
                     class={["cursor-pointer select-none", (@loading && "opacity-75" || "")]}
                     phx-click="toggle_sort"
                     phx-value-key={column.field}
                     phx-target={@myself}>
                     {column.label}
                     <span class={@theme.sort_indicator_class} {@theme.sort_indicator_data}>
                       <.sort_arrow sort_direction={Cinder.QueryBuilder.get_sort_direction(@sort_by, column.field)} theme={@theme} loading={@loading} />
                     </span>
                </div>
                <div :if={not column.sortable}>
                  {column.label}
                </div>
              </th>
            </tr>
          </thead>
          <tbody class={[@theme.tbody_class, (@loading && "opacity-75" || "")]} {@theme.tbody_data}>
            <tr :for={item <- @data}
                class={get_row_classes(@theme.row_class, @row_click, @selectable, @selected_ids, item, @id_field, @theme)}
                {@theme.row_data}
                phx-click={row_click_action(@row_click, @selectable, item, @id_field, @myself)}>
              <td :if={@selectable} class={@theme.selection_td_class} {@theme.selection_td_data}>
                <input
                  type="checkbox"
                  checked={item_selected?(@selected_ids, item, @id_field)}
                  phx-click="toggle_select"
                  phx-value-id={to_string(Map.get(item, @id_field))}
                  phx-target={@myself}
                  class={@theme.selection_checkbox_class}
                />
              </td>
              <td :for={column <- @columns} class={[@theme.td_class, column.class]} {@theme.td_data}>
                {render_slot(column.slot, item)}
              </td>
            </tr>
            <tr :if={@data == [] and not @loading}>
              <td colspan={column_count(@columns, @selectable)} class={@theme.empty_class} {@theme.empty_data}>
                {@empty_message}
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <!-- Loading indicator -->
      <div :if={@loading} class={@theme.loading_overlay_class} {@theme.loading_overlay_data}>
        <div class={@theme.loading_container_class} {@theme.loading_container_data}>
          <svg class={@theme.loading_spinner_class} {@theme.loading_spinner_data} xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
            <circle class={@theme.loading_spinner_circle_class} {@theme.loading_spinner_circle_data} cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
            <path class={@theme.loading_spinner_path_class} {@theme.loading_spinner_path_data} fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
          </svg>
          {@loading_message}
        </div>
      </div>

      <!-- Pagination -->
      <Pagination.render
        page={@page}
        page_size_config={@page_size_config}
        theme={@theme}
        myself={@myself}
        show_pagination={@show_pagination}
        pagination_mode={@pagination_mode}
        id={@id}
      />
    </div>
    """
  end

  # ============================================================================
  # HELPER COMPONENTS
  # ============================================================================

  defp sort_arrow(assigns) do
    ~H"""
    <span class={Map.get(@theme, :sort_arrow_wrapper_class, "inline-block ml-1")}>
      <%= case @sort_direction do %>
        <% direction when direction in [:asc, :asc_nils_first, :asc_nils_last] -> %>
          <.icon
            name={Map.get(@theme, :sort_asc_icon_name, "hero-chevron-up")}
            class={[Map.get(@theme, :sort_asc_icon_class, "w-3 h-3 inline"), (@loading && "animate-pulse" || "")]}
          />
        <% direction when direction in [:desc, :desc_nils_first, :desc_nils_last] -> %>
          <.icon
            name={Map.get(@theme, :sort_desc_icon_name, "hero-chevron-down")}
            class={[Map.get(@theme, :sort_desc_icon_class, "w-3 h-3 inline"), (@loading && "animate-pulse" || "")]}
          />
        <% _ -> %>
          <.icon
            name={Map.get(@theme, :sort_none_icon_name, "hero-chevron-up-down")}
            class={Map.get(@theme, :sort_none_icon_class, "w-3 h-3 inline opacity-30")}
          />
      <% end %>
    </span>
    """
  end

  defp icon(%{name: _, class: _} = assigns) do
    ~H"""
    <span class={[@name, @class]} />
    """
  end

  # ============================================================================
  # HELPER FUNCTIONS
  # ============================================================================

  defp get_row_classes(base_classes, row_click, selectable, selected_ids, item, id_field, theme) do
    # Add cursor-pointer if row is clickable (either via row_click or selectable without row_click)
    clickable = row_click != nil or (selectable and row_click == nil)
    classes = if clickable, do: [base_classes, "cursor-pointer"], else: [base_classes]

    if selectable and item_selected?(selected_ids, item, id_field) do
      classes ++ [theme.selected_row_class]
    else
      classes
    end
  end

  defp row_click_action(row_click, _selectable, item, _id_field, _myself) when row_click != nil do
    row_click.(item)
  end

  defp row_click_action(nil, true, item, id_field, myself) do
    Phoenix.LiveView.JS.push("toggle_select",
      value: %{id: to_string(Map.get(item, id_field))},
      target: myself
    )
  end

  defp row_click_action(nil, false, _item, _id_field, _myself), do: nil

  defp all_page_selected?(selected_ids, data, id_field) when is_list(data) and length(data) > 0 do
    Enum.all?(data, fn item ->
      item_selected?(selected_ids, item, id_field)
    end)
  end

  defp all_page_selected?(_selected_ids, _data, _id_field), do: false

  defp item_selected?(selected_ids, item, id_field) do
    id = to_string(Map.get(item, id_field))
    MapSet.member?(selected_ids, id)
  end

  defp column_count(columns, selectable) do
    base_count = length(columns)
    if selectable, do: base_count + 1, else: base_count
  end
end
