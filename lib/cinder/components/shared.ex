defmodule Cinder.Components.Shared do
  @moduledoc """
  Shared UI components used by both Table and Cards components.
  
  Contains reusable components like pagination controls, sort arrows, and icons
  that are used across different Cinder components.
  """

  use Phoenix.Component

  @doc """
  Renders pagination controls for navigating through pages of data.
  
  ## Attributes
  
  * `page_info` - Map containing pagination information (current_page, total_pages, etc.)
  * `theme` - Theme configuration for styling
  * `target` - Phoenix LiveComponent target for events
  """
  def pagination_controls(assigns) do
    page_range = build_page_range(assigns.page_info)
    assigns = assign(assigns, :page_range, page_range)

    ~H"""
    <div class={@theme.pagination_container_class} {@theme.pagination_container_data}>
      <!-- Left side: Page info -->
      <div class={@theme.pagination_info_class} {@theme.pagination_info_data}>
        Page {@page_info.current_page} of {@page_info.total_pages}
        <span class={@theme.pagination_count_class} {@theme.pagination_count_data}>
          (showing {@page_info.start_index}-{@page_info.end_index} of {@page_info.total_count})
        </span>
      </div>

      <!-- Right side: Page navigation -->
      <div class={@theme.pagination_controls_class} {@theme.pagination_controls_data}>
        <button
          :if={@page_info.current_page > 1}
          class={@theme.pagination_button_class}
          {@theme.pagination_button_data}
          phx-click="goto_page"
          phx-value-page={@page_info.current_page - 1}
          phx-target={@target}
        >
          <.icon name="hero-chevron-left" class={@theme.pagination_icon_class} />
          Previous
        </button>

        <button
          :for={page <- @page_range}
          class={[
            @theme.pagination_button_class,
            (@page_info.current_page == page && @theme.pagination_active_class || "")
          ]}
          {@theme.pagination_button_data}
          phx-click="goto_page"
          phx-value-page={page}
          phx-target={@target}
        >
          {page}
        </button>

        <button
          :if={@page_info.current_page < @page_info.total_pages}
          class={@theme.pagination_button_class}
          {@theme.pagination_button_data}
          phx-click="goto_page"
          phx-value-page={@page_info.current_page + 1}
          phx-target={@target}
        >
          Next
          <.icon name="hero-chevron-right" class={@theme.pagination_icon_class} />
        </button>
      </div>
    </div>
    """
  end

  @doc """
  Renders a sort arrow indicator based on the current sort direction.
  
  ## Attributes
  
  * `sort_direction` - Current sort direction (:asc, :desc, or nil)
  * `theme` - Theme configuration for styling
  * `loading` - Whether data is currently loading
  """
  def sort_arrow(assigns) do
    ~H"""
    <span class={["inline-block transition-all duration-200", (@loading && "opacity-50" || "")]}>
      <.icon
        :if={@sort_direction == :asc}
        name={Map.get(@theme, :sort_asc_icon_name, "hero-arrow-up")}
        class={Map.get(@theme, :sort_asc_icon_class, "w-3 h-3 inline text-blue-600")}
      />
      <.icon
        :if={@sort_direction == :desc}
        name={Map.get(@theme, :sort_desc_icon_name, "hero-arrow-down")}
        class={Map.get(@theme, :sort_desc_icon_class, "w-3 h-3 inline text-blue-600")}
      />
      <.icon
        :if={@sort_direction == nil}
        name={Map.get(@theme, :sort_none_icon_name, "hero-arrows-up-down")}
        class={Map.get(@theme, :sort_none_icon_class, "w-3 h-3 inline opacity-30")}
      />
    </span>
    """
  end

  @doc """
  Renders Heroicons icons with proper classes.
  
  ## Attributes
  
  * `name` - Icon name (should start with "hero-")
  * `class` - Additional CSS classes
  """
  def icon(%{name: "hero-" <> _} = assigns) do
    ~H"""
    <span class={[@name, @class]} />
    """
  end

  # Helper function to build page range for pagination
  defp build_page_range(page_info) do
    current = page_info.current_page
    total = page_info.total_pages

    # Show up to 5 pages around current page
    range_start = max(1, current - 2)
    range_end = min(total, current + 2)

    Enum.to_list(range_start..range_end)
  end
end