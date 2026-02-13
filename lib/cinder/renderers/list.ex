defmodule Cinder.Renderers.List do
  @moduledoc """
  Renderer for list layout.

  This module contains the render function for displaying data in a
  vertical list format with sort controls rendered as a button group.
  """

  use Phoenix.Component
  use Cinder.Messages
  require Logger

  alias Cinder.Renderers.BulkActions
  alias Cinder.Renderers.Pagination
  alias Cinder.Renderers.SortControls

  @doc """
  Renders the list layout.
  """
  def render(assigns) do
    has_item_slot = Map.get(assigns, :item_slot, []) != []

    unless has_item_slot do
      Logger.warning("Cinder.List: No <:item> slot provided. Items will not be rendered.")
    end

    container_class = get_container_class(assigns.container_class, assigns.theme)
    {item_class, item_data_key} = get_item_classes(assigns.theme, assigns.item_click)

    assigns =
      assigns
      |> assign(:has_item_slot, has_item_slot)
      |> assign(:list_container_class, container_class)
      |> assign(:list_item_class, item_class)
      |> assign(:list_item_data_key, item_data_key)

    ~H"""
    <div class={[@theme.container_class, "relative"]} data-key="container_class">
      <!-- Controls Area (filters + sort) -->
      <div :if={@show_filters or (@show_sort && SortControls.has_sortable_columns?(@columns))} class={[@theme.controls_class, "!flex !flex-col"]} data-key="controls_class">
        <!-- Filter Controls (including search) -->
        <Cinder.FilterManager.render_filter_controls
          :if={@show_filters}
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

        <!-- Sort Controls (button group since no table headers) -->
        <SortControls.render
          :if={@show_sort}
          columns={@columns}
          sort_by={@sort_by}
          sort_label={@sort_label}
          theme={@theme}
          myself={@myself}
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

      <!-- List Items Container -->
      <div class={@list_container_class} data-key="list_container_class">
        <%= if @has_item_slot do %>
          <div
            :for={item <- @data}
            class={get_item_classes_with_selection(@list_item_class, Map.get(assigns, :selectable, false), Map.get(assigns, :selected_ids, MapSet.new()), item, Map.get(assigns, :id_field, :id), @item_click, @theme)}
            data-key={@list_item_data_key}
            phx-click={item_click_action(@item_click, Map.get(assigns, :selectable, false), item, Map.get(assigns, :id_field, :id), @myself)}
          >
            <div
              :if={Map.get(assigns, :selectable, false)}
              class={@theme.list_selection_container_class}
            >
              <input
                type="checkbox"
                checked={item_selected?(Map.get(assigns, :selected_ids, MapSet.new()), item, Map.get(assigns, :id_field, :id))}
                phx-click="toggle_select"
                phx-value-id={to_string(Map.get(item, Map.get(assigns, :id_field, :id)))}
                phx-target={@myself}
                class={@theme.selection_checkbox_class}
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

        <!-- Empty State -->
        <div :if={@data == [] and not @loading and @has_item_slot} class={@theme.empty_class} data-key="empty_class">
          {@empty_message}
        </div>
      </div>

      <!-- Loading indicator -->
      <div :if={@loading} class={@theme.loading_overlay_class} data-key="loading_overlay_class">
        <div class={@theme.loading_container_class} data-key="loading_container_class">
          <svg class={@theme.loading_spinner_class} data-key="loading_spinner_class" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
            <circle class={@theme.loading_spinner_circle_class} data-key="loading_spinner_circle_class" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
            <path class={@theme.loading_spinner_path_class} data-key="loading_spinner_path_class" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
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
  # CONTAINER AND ITEM HELPERS
  # ============================================================================

  defp get_container_class(nil, theme) do
    Map.get(theme, :list_container_class, "divide-y divide-gray-200")
  end

  defp get_container_class(custom_class, _theme), do: custom_class

  defp get_item_classes(theme, item_click) do
    base = Map.get(theme, :list_item_class, "")

    if item_click do
      clickable =
        Map.get(
          theme,
          :list_item_clickable_class,
          "cursor-pointer hover:bg-gray-50 transition-colors"
        )

      {[base, clickable], "list_item_clickable_class"}
    else
      {base, "list_item_class"}
    end
  end

  # ============================================================================
  # SELECTION HELPERS
  # ============================================================================

  defp get_item_classes_with_selection(
         base_class,
         selectable,
         selected_ids,
         item,
         id_field,
         item_click,
         theme
       ) do
    classes = [base_class]

    # Add cursor-pointer if item is clickable (either via item_click or selectable without item_click)
    clickable = item_click != nil or (selectable and item_click == nil)
    classes = if clickable, do: classes ++ ["cursor-pointer"], else: classes

    if selectable and item_selected?(selected_ids, item, id_field) do
      classes ++ [theme.selected_item_class]
    else
      classes
    end
  end

  defp item_click_action(item_click, _selectable, item, _id_field, _myself)
       when item_click != nil do
    item_click.(item)
  end

  defp item_click_action(nil, true, item, id_field, myself) do
    Phoenix.LiveView.JS.push("toggle_select",
      value: %{id: to_string(Map.get(item, id_field))},
      target: myself
    )
  end

  defp item_click_action(nil, false, _item, _id_field, _myself), do: nil

  defp item_selected?(selected_ids, item, id_field) do
    id = to_string(Map.get(item, id_field))
    MapSet.member?(selected_ids, id)
  end
end
