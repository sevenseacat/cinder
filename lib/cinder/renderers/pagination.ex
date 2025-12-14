defmodule Cinder.Renderers.Pagination do
  @moduledoc """
  Shared pagination component used by Table, List, and Grid renderers.
  """

  use Phoenix.Component
  alias Phoenix.LiveView.JS
  use Cinder.Messages

  @doc """
  Renders pagination controls with page navigation and optional page size selector.

  ## Required assigns
  - `page_info` - Map with pagination state (current_page, total_pages, etc.)
  - `page_size_config` - Map with page size configuration
  - `theme` - Theme configuration map
  - `myself` - LiveComponent reference for event targeting
  """
  def render(assigns) do
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
