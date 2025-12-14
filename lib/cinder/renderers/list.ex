defmodule Cinder.Renderers.List do
  @moduledoc """
  Renderer for list/card layout.

  This module contains the render function and helper components for
  displaying data in a flexible list or grid format. The layout is
  controlled purely through CSS - the same renderer can display as
  a vertical list, grid, or cards by changing the container class.
  """

  use Phoenix.Component
  alias Phoenix.LiveView.JS
  use Cinder.Messages
  require Logger

  @doc """
  Renders the list layout.
  """
  def render(assigns) do
    # Check if item slot is provided
    has_item_slot = Map.get(assigns, :item_slot, []) != []

    unless has_item_slot do
      Logger.warning("Cinder.List: No <:item> slot provided. Items will not be rendered.")
    end

    assigns = assign(assigns, :has_item_slot, has_item_slot)

    ~H"""
    <div class={[@theme.container_class, "relative"]} {@theme.container_data}>
      <!-- Filter Controls (including search) -->
      <div :if={@show_filters} class={@theme.controls_class} {@theme.controls_data}>
        <Cinder.FilterManager.render_filter_controls
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
      </div>

      <!-- Sort Controls (button group since no table headers) -->
      <div :if={@show_sort && has_sortable_columns?(@columns)} class={get_sort_controls_class(@theme)}>
        <span class={get_sort_label_class(@theme)}>{@sort_label}</span>
        <div class={get_sort_buttons_class(@theme)}>
          <button
            :for={column <- get_sortable_columns(@columns)}
            type="button"
            class={get_sort_button_class(column, @sort_by, @theme)}
            phx-click="toggle_sort"
            phx-value-key={column.field}
            phx-target={@myself}
          >
            {column.label}
            <span :if={get_sort_direction(@sort_by, column.field)} class={get_sort_icon_class(@theme)}>
              {get_sort_icon(get_sort_direction(@sort_by, column.field), @theme)}
            </span>
          </button>
        </div>
      </div>

      <!-- List Items Container -->
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
      <div :if={@show_pagination and @page_info.total_pages > 1} class={@theme.pagination_wrapper_class} {@theme.pagination_wrapper_data}>
        <.pagination_controls
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
  # SORT CONTROL HELPERS
  # ============================================================================

  defp has_sortable_columns?(columns) do
    Enum.any?(columns, & &1.sortable)
  end

  defp get_sortable_columns(columns) do
    Enum.filter(columns, & &1.sortable)
  end

  defp get_sort_direction(sort_by, field) when is_list(sort_by) do
    case Enum.find(sort_by, fn {f, _dir} -> f == field end) do
      {_, dir} -> dir
      nil -> nil
    end
  end

  defp get_sort_direction(_, _), do: nil

  defp get_sort_controls_class(theme) do
    Map.get(theme, :sort_controls_class, "flex items-center gap-2 p-3 border-b bg-gray-50")
  end

  defp get_sort_label_class(theme) do
    Map.get(theme, :sort_controls_label_class, "text-sm text-gray-600 font-medium")
  end

  defp get_sort_buttons_class(theme) do
    Map.get(theme, :sort_buttons_class, "flex gap-1")
  end

  defp get_sort_button_class(column, sort_by, theme) do
    base =
      Map.get(theme, :sort_button_class, "px-3 py-1 text-sm border rounded transition-colors")

    active = Map.get(theme, :sort_button_active_class, "bg-blue-50 border-blue-300 text-blue-700")

    inactive =
      Map.get(theme, :sort_button_inactive_class, "bg-white border-gray-300 hover:bg-gray-50")

    if get_sort_direction(sort_by, column.field) do
      [base, active]
    else
      [base, inactive]
    end
  end

  defp get_sort_icon_class(theme) do
    Map.get(theme, :sort_icon_class, "ml-1")
  end

  defp get_sort_icon(:asc, theme), do: Map.get(theme, :sort_asc_icon, "↑")
  defp get_sort_icon(:desc, theme), do: Map.get(theme, :sort_desc_icon, "↓")
  defp get_sort_icon(_, _), do: ""

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

      [base, clickable]
    else
      base
    end
  end

  # ============================================================================
  # PAGINATION COMPONENT
  # ============================================================================

  defp pagination_controls(assigns) do
    page_range = build_page_range(assigns.page_info)
    assigns = assign(assigns, :page_range, page_range)

    ~H"""
    <div class={@theme.pagination_container_class} {@theme.pagination_container_data}>
      <!-- Left side: Page info -->
      <div class={@theme.pagination_info_class} {@theme.pagination_info_data}>
        {dgettext("cinder", "Page %{current} of %{total}", current: @page_info.current_page, total: @page_info.total_pages)}
        <span class={@theme.pagination_count_class} {@theme.pagination_count_data}>
          ({dgettext("cinder", "showing %{start}-%{end} of %{total}", start: @page_info.start_index, end: @page_info.end_index, total: @page_info.total_count)})
        </span>
      </div>

      <!-- Right side: Page size selector and navigation -->
      <div class="flex items-center space-x-6">
        <!-- Page size selector (if configurable) -->
        <div :if={@page_size_config.configurable} class={@theme.page_size_container_class} {@theme.page_size_container_data}>
          <.page_size_selector page_size_config={@page_size_config} theme={@theme} myself={@myself} />
        </div>

        <!-- Page navigation -->
        <div class={@theme.pagination_nav_class} {@theme.pagination_nav_data}>
          <!-- First page and previous -->
          <button
            :if={@page_info.current_page > 2}
            phx-click="goto_page"
            phx-value-page="1"
            phx-target={@myself}
            class={@theme.pagination_button_class}
            {@theme.pagination_button_data}
            title={dgettext("cinder", "First page")}
          >
            &laquo;
          </button>

          <button
            :if={@page_info.has_previous_page}
            phx-click="goto_page"
            phx-value-page={@page_info.current_page - 1}
            phx-target={@myself}
            class={@theme.pagination_button_class}
            {@theme.pagination_button_data}
            title={dgettext("cinder", "Previous page")}
          >
            &lsaquo;
          </button>

          <!-- Page numbers -->
          <span :for={page <- @page_range} class="inline-flex">
            <button
              :if={page != @page_info.current_page}
              phx-click="goto_page"
              phx-value-page={page}
              phx-target={@myself}
              class={@theme.pagination_button_class}
              {@theme.pagination_button_data}
              title={dgettext("cinder", "Go to page %{page}", %{page: page})}
            >
              {page}
            </button>
            <span :if={page == @page_info.current_page} class={@theme.pagination_current_class} {@theme.pagination_current_data}>
              {page}
            </span>
          </span>

          <!-- Next and last page -->
          <button
            :if={@page_info.has_next_page}
            phx-click="goto_page"
            phx-value-page={@page_info.current_page + 1}
            phx-target={@myself}
            class={@theme.pagination_button_class}
            {@theme.pagination_button_data}
            title={dgettext("cinder", "Next page")}
          >
            &rsaquo;
          </button>

          <button
            :if={@page_info.current_page < @page_info.total_pages - 1}
            phx-click="goto_page"
            phx-value-page={@page_info.total_pages}
            phx-target={@myself}
            class={@theme.pagination_button_class}
            {@theme.pagination_button_data}
            title={dgettext("cinder", "Last page")}
          >
            &raquo;
          </button>
        </div>
      </div>
    </div>
    """
  end

  defp page_size_selector(assigns) do
    ~H"""
    <div class="flex items-center space-x-2">
      <span class={@theme.page_size_label_class} {@theme.page_size_label_data}>
        Show
      </span>
      <div class="relative">
        <button
          type="button"
          class={@theme.page_size_dropdown_class}
          {@theme.page_size_dropdown_data}
          phx-click={JS.toggle(to: "#page-size-options")}
          aria-haspopup="true"
          aria-expanded="false"
        >
          {@page_size_config.selected_page_size}
          <svg class="w-4 h-4 ml-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7"></path>
          </svg>
        </button>
        <div
          id="page-size-options"
          class={["absolute top-full right-0 mt-1 z-50 hidden", @theme.page_size_dropdown_container_class]}
          {@theme.page_size_dropdown_container_data}
          phx-click-away={JS.hide(to: "#page-size-options")}
        >
          <button
            :for={option <- @page_size_config.page_size_options}
            type="button"
            class={[
              @theme.page_size_option_class,
              (@page_size_config.selected_page_size == option && @theme.page_size_selected_class || "")
            ]}
            {@theme.page_size_option_data}
            phx-click={JS.push("change_page_size") |> JS.hide(to: "#page-size-options")}
            phx-value-page_size={option}
            phx-target={@myself}
          >
            {option}
          </button>
        </div>
      </div>
      <span class={@theme.page_size_label_class} {@theme.page_size_label_data}>
        per page
      </span>
    </div>
    """
  end

  defp build_page_range(page_info) do
    current = page_info.current_page
    total = page_info.total_pages

    range_start = max(1, current - 2)
    range_end = min(total, current + 2)

    Enum.to_list(range_start..range_end)
  end
end
