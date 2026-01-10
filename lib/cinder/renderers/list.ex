defmodule Cinder.Renderers.List do
  @moduledoc """
  Renderer for list layout.

  This module contains the render function for displaying data in a
  vertical list format with sort controls rendered as a button group.
  """

  use Phoenix.Component
  use Cinder.Messages
  require Logger

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

    {container_class, container_data} =
      get_container_class(assigns.container_class, assigns.theme)

    {item_class, item_data} = get_item_classes(assigns.theme, assigns.item_click)

    assigns =
      assigns
      |> assign(:has_item_slot, has_item_slot)
      |> assign(:list_container_class, container_class)
      |> assign(:list_container_data, container_data)
      |> assign(:list_item_class, item_class)
      |> assign(:list_item_data, item_data)

    ~H"""
    <div class={[@theme.container_class, "relative"]} {@theme.container_data}>
      <!-- Bulk Action Buttons -->
      <div :if={Map.get(assigns, :bulk_actions, []) != []} class={Map.get(@theme, :bulk_actions_container_class, "flex justify-end gap-2 p-4")}>
        <button
          :for={action <- Map.get(assigns, :bulk_actions, [])}
          type="button"
          phx-click="bulk_action"
          phx-value-event={Map.get(action, :event, "bulk_action_all_ids")}
          phx-target={@myself}
          disabled={Map.get(assigns, :bulk_action_loading) != nil}
          class={[
            Map.get(@theme, :bulk_action_button_class, "px-4 py-2 text-sm font-medium rounded-lg border border-gray-300 bg-white text-gray-700 hover:bg-gray-50"),
            Map.get(assigns, :bulk_action_loading) == Map.get(action, :event) && Map.get(@theme, :bulk_loading_class, "animate-pulse")
          ]}
        >
          {Map.get(action, :label, "Action")}
        </button>
      </div>

      <!-- Controls Area (filters + sort) -->
      <div :if={@show_filters or (@show_sort && SortControls.has_sortable_columns?(@columns))} class={[@theme.controls_class, "!flex !flex-col"]} {@theme.controls_data}>
        <!-- Filter Controls (including search) -->
        <Cinder.FilterManager.render_filter_controls
          :if={@show_filters}
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

      <!-- List Items Container -->
      <div class={@list_container_class} {@list_container_data}>
        <%= if @has_item_slot do %>
          <div
            :for={item <- @data}
            class={@list_item_class}
            {@list_item_data}
            phx-click={@item_click && @item_click.(item)}
          >
            {render_slot(@item_slot, item)}
          </div>
        <% else %>
          <!-- No item slot provided - render message -->
          <div :if={not @loading} class={@theme.empty_class} {@theme.empty_data}>
            No item template provided. Add an &lt;:item&gt; slot to render items.
          </div>
        <% end %>

        <!-- Empty State -->
        <div :if={@data == [] and not @loading and @has_item_slot} class={@theme.empty_class} {@theme.empty_data}>
          {@empty_message}
        </div>
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
      />
    </div>
    """
  end

  # ============================================================================
  # CONTAINER AND ITEM HELPERS
  # ============================================================================

  defp get_container_class(nil, theme) do
    class = Map.get(theme, :list_container_class, "divide-y divide-gray-200")
    data = Map.get(theme, :list_container_data, %{})
    {class, data}
  end

  defp get_container_class(custom_class, _theme), do: {custom_class, %{}}

  defp get_item_classes(theme, item_click) do
    base = Map.get(theme, :list_item_class, "")
    base_data = Map.get(theme, :list_item_data, %{})

    if item_click do
      clickable =
        Map.get(
          theme,
          :list_item_clickable_class,
          "cursor-pointer hover:bg-gray-50 transition-colors"
        )

      clickable_data = Map.get(theme, :list_item_clickable_data, %{})
      {[base, clickable], Map.merge(base_data, clickable_data)}
    else
      {base, base_data}
    end
  end
end
