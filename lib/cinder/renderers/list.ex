defmodule Cinder.Renderers.List do
  @moduledoc """
  Renderer for list layout.

  This module contains the render function for displaying data in a
  vertical list format with sort controls rendered as a button group.
  """

  use Phoenix.Component
  use Cinder.Messages
  require Logger

  import Cinder.Renderers.Helpers

  alias Cinder.Renderers.BulkActions
  alias Cinder.Renderers.Pagination
  alias Cinder.Renderers.SortControls
  alias Cinder.Selection

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

      <!-- List Items Container -->
      <div class={@list_container_class} data-key="list_container_class">
        <%= if @has_item_slot do %>
          <div
            :for={item <- @data} :if={not @error}
            class={get_item_classes_with_selection(@list_item_class, Map.get(assigns, :selectable, false), Map.get(assigns, :selected_ids, MapSet.new()), item, Map.get(assigns, :id_field, :id), @item_click, @theme)}
            data-key={@list_item_data_key}
            phx-click={item_click_action(@item_click, Map.get(assigns, :selectable, false), Map.get(assigns, :selected_ids, MapSet.new()), item, Map.get(assigns, :id_field, :id), @myself)}
          >
            <div
              :if={Selection.enabled?(Map.get(assigns, :selectable, false))}
              class={@theme.list_selection_container_class}
              data-key="list_selection_container_class"
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

        <!-- Error State -->
        <div :if={@error and not @loading} class={@theme.empty_class} data-key="error_class">
          <%= if has_slot?(assigns, :error_slot) do %>
            {render_slot(@error_slot)}
          <% else %>
            <div class={@theme.error_container_class} data-key="error_container_class">
              <span class={@theme.error_message_class} data-key="error_message_class">{@error_message}</span>
            </div>
          <% end %>
        </div>

        <!-- Empty State (only when not loading and not error) -->
        <div :if={@data == [] and not @loading and not @error and @has_item_slot} class={@theme.empty_class} data-key="empty_class">
          <%= if has_slot?(assigns, :empty_slot) do %>
            {render_slot(@empty_slot, empty_context(assigns))}
          <% else %>
            {@empty_message}
          <% end %>
        </div>
      </div>

      <!-- Loading indicator -->
      <div :if={@loading} class={@theme.loading_overlay_class} data-key="loading_overlay_class">
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
    selected? = Selection.item_selected?(selected_ids, item, id_field)
    toggleable = Selection.item_selectable?(selectable, item) or selected?

    clickable = item_click != nil or toggleable
    classes = if clickable, do: classes ++ ["cursor-pointer"], else: classes

    if selected? do
      classes ++ [theme.selected_item_class]
    else
      classes
    end
  end

  defp item_click_action(item_click, _selectable, _selected_ids, item, _id_field, _myself)
       when item_click != nil do
    item_click.(item)
  end

  defp item_click_action(nil, selectable, selected_ids, item, id_field, myself) do
    if Selection.item_toggleable?(selectable, selected_ids, item, id_field) do
      Phoenix.LiveView.JS.push("toggle_select",
        value: %{id: to_string(Map.get(item, id_field))},
        target: myself
      )
    end
  end
end
