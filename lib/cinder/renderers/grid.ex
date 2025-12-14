defmodule Cinder.Renderers.Grid do
  @moduledoc """
  Renderer for grid/card layout.

  This module contains the render function for displaying data in a
  responsive grid format with sort controls rendered as a button group.
  """

  use Phoenix.Component
  use Cinder.Messages
  require Logger

  alias Cinder.Renderers.Pagination
  alias Cinder.Renderers.SortControls

  @doc """
  Renders the grid layout.
  """
  def render(assigns) do
    has_item_slot = Map.get(assigns, :item_slot, []) != []

    unless has_item_slot do
      Logger.warning("Cinder.Grid: No <:item> slot provided. Items will not be rendered.")
    end

    assigns = assign(assigns, :has_item_slot, has_item_slot)

    ~H"""
    <div class={[@theme.container_class, "relative"]} {@theme.container_data}>
      <!-- Controls Area (filters + sort) -->
      <div :if={@show_filters or (@show_sort && SortControls.has_sortable_columns?(@columns))} class={[@theme.controls_class, "!flex !flex-col"]} {@theme.controls_data}>
        <!-- Filter Controls (including search) -->
        <Cinder.FilterManager.render_filter_controls
          :if={@show_filters}
          columns={Map.get(assigns, :filter_columns, @columns)}
          filters={@filters}
          theme={@theme}
          target={@myself}
          filters_label={@filters_label}
          search_term={@search_term}
          show_search={@search_enabled}
          search_label={@search_label}
          search_placeholder={@search_placeholder}
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

      <!-- Grid Items Container -->
      <div class={get_container_class(@container_class, @theme)}>
        <%= if @has_item_slot do %>
          <div
            :for={item <- @data}
            class={get_item_classes(@theme, @item_click)}
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
        <div :if={@data == [] and not @loading and @has_item_slot} class={[@theme.empty_class, "col-span-full"]} {@theme.empty_data}>
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
      <div :if={@show_pagination and @page_info.total_pages > 1} class={@theme.pagination_wrapper_class} {@theme.pagination_wrapper_data}>
        <Pagination.render
          page_info={@page_info}
          page_size_config={@page_size_config}
          theme={@theme}
          myself={@myself}
        />
      </div>
    </div>
    """
  end

  # ============================================================================
  # CONTAINER AND ITEM HELPERS
  # ============================================================================

  defp get_container_class(nil, theme) do
    Map.get(theme, :grid_container_class, "grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4")
  end

  defp get_container_class(custom_class, _theme), do: custom_class

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

      [base, clickable]
    else
      base
    end
  end
end
