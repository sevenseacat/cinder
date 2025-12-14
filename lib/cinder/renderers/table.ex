defmodule Cinder.Renderers.Table do
  @moduledoc """
  Renderer for table layout.

  This module contains the render function and helper components for
  displaying data in a traditional HTML table format.
  """

  use Phoenix.Component
  alias Phoenix.LiveView.JS
  use Cinder.Messages

  @doc """
  Renders the table layout.
  """
  def render(assigns) do
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

      <!-- Main table -->
      <div class={@theme.table_wrapper_class} {@theme.table_wrapper_data}>
        <table class={@theme.table_class} {@theme.table_data}>
          <thead class={@theme.thead_class} {@theme.thead_data}>
            <tr class={@theme.header_row_class} {@theme.header_row_data}>
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
                class={get_row_classes(@theme.row_class, @row_click)}
                {@theme.row_data}
                phx-click={@row_click && @row_click.(item)}>
              <td :for={column <- @columns} class={[@theme.td_class, column.class]} {@theme.td_data}>
                {render_slot(column.slot, item)}
              </td>
            </tr>
            <tr :if={@data == [] and not @loading}>
              <td colspan={length(@columns)} class={@theme.empty_class} {@theme.empty_data}>
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
      <div :if={@page_info.total_pages > 1} class={@theme.pagination_wrapper_class} {@theme.pagination_wrapper_data}>
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
  # HELPER COMPONENTS
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

  defp build_page_range(page_info) do
    current = page_info.current_page
    total = page_info.total_pages

    range_start = max(1, current - 2)
    range_end = min(total, current + 2)

    Enum.to_list(range_start..range_end)
  end

  defp get_row_classes(base_classes, row_click) do
    if row_click do
      [base_classes, "cursor-pointer"]
    else
      base_classes
    end
  end
end
