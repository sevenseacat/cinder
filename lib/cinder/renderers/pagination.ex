defmodule Cinder.Renderers.Pagination do
  @moduledoc """
  Shared pagination component used by Table, List, and Grid renderers.

  Supports three pagination modes:
  - `Ash.Page.Offset` - Traditional page numbers with jump-to-page
  - `Ash.Page.Keyset` - Cursor-based with prev/next navigation (faster for large datasets)
  - Infinite scrolling - Cursor-based batches appended as the viewport reaches the sentinel

  Uses `AshPhoenix.LiveView` helpers for working with Ash.Page structs directly.
  """

  use Phoenix.Component
  alias Phoenix.LiveView.JS
  use Cinder.Messages

  @doc """
  Checks if pagination controls should be shown based on page.

  Returns true if there are more results than fit on one page.
  """
  def show_pagination?(%Ash.Page.Offset{count: count, limit: limit}) when is_integer(count),
    do: count > limit

  def show_pagination?(%Ash.Page.Keyset{count: count, limit: limit}) when is_integer(count),
    do: count > limit

  def show_pagination?(%{more?: more?}), do: more?
  def show_pagination?(_), do: false

  @doc """
  Renders pagination controls with page navigation and optional page size selector.

  Handles the wrapper div and conditional display internally.
  Returns empty content if pagination should not be shown.

  ## Required assigns
  - `page` - An `Ash.Page.Offset`, `Ash.Page.Keyset`, or nil
  - `page_size_config` - Map with page size configuration
  - `theme` - Theme configuration map
  - `myself` - LiveComponent reference for event targeting
  - `show_pagination` - Boolean to enable/disable pagination (default: true)
  """
  def render(assigns) do
    pagination_mode = Map.get(assigns, :pagination_mode, :offset)

    show =
      Map.get(assigns, :show_pagination, true) and
        show_pagination?(assigns.page, pagination_mode, assigns)

    if show do
      # Use pagination_mode (if provided) to determine UI, not just page struct type.
      # This handles the case where keyset mode returns Ash.Page.Offset on the first page
      # (when no cursor is provided yet).
      case pagination_mode do
        :keyset -> render_keyset(assigns)
        :infinite -> render_infinite(assigns)
        :offset -> render_offset(assigns)
      end
    else
      render_empty(assigns)
    end
  end

  defp show_pagination?(nil, _pagination_mode, _assigns), do: false
  defp show_pagination?(_page, :infinite, _assigns), do: true

  defp show_pagination?(page, :keyset, assigns) do
    show_pagination?(page) or keyset_cursor?(page) or Map.get(assigns, :current_page, 1) > 1
  end

  defp show_pagination?(%Ash.Page.Offset{offset: offset} = page, :offset, _assigns) do
    show_pagination?(page) or offset > 0
  end

  defp show_pagination?(page, _pagination_mode, _assigns), do: show_pagination?(page)

  defp keyset_cursor?(%Ash.Page.Keyset{after: after_cursor, before: before_cursor}),
    do: not is_nil(after_cursor) or not is_nil(before_cursor)

  defp keyset_cursor?(_page), do: false

  defp render_empty(assigns) do
    ~H"""
    """
  end

  # Offset pagination (traditional page numbers)
  # In offset mode, we always pass `offset:` to Ash.Query.page, so Ash returns Ash.Page.Offset
  defp render_offset(assigns) do
    %Ash.Page.Offset{} = page = assigns.page
    page_number = AshPhoenix.LiveView.page_number(page) + 1
    total_count = Map.get(assigns, :total_count) || page.count

    total_pages =
      if is_integer(total_count) and total_count > 0, do: ceil(total_count / page.limit)

    start_index = page.offset + 1
    end_index = page.offset + length(page.results)
    end_index = if is_integer(total_count), do: min(end_index, total_count), else: end_index
    page_range = if total_pages, do: build_page_range(page_number, total_pages), else: []

    assigns =
      assigns
      |> assign(:page_range, page_range)
      |> assign(:page_number, page_number)
      |> assign(:total_pages, total_pages)
      |> assign(:start_index, if(page.results == [], do: 0, else: start_index))
      |> assign(:end_index, if(page.results == [], do: 0, else: end_index))
      |> assign(:total_count, total_count)
      |> assign(:has_total_count, is_integer(total_count))
      |> assign(:has_prev, page.offset > 0)
      |> assign(:has_next, page.more?)

    ~H"""
    <div class={@theme.pagination_wrapper_class} data-key="pagination_wrapper_class">
      <div class={@theme.pagination_container_class} data-key="pagination_container_class">
      <!-- Left side: Page info -->
      <div class={@theme.pagination_info_class} data-key="pagination_info_class">
        <%= if @has_total_count do %>
          {dgettext("cinder", "Page %{current} of %{total}", current: @page_number, total: @total_pages)}
        <% else %>
          {dgettext("cinder", "Page %{current}", current: @page_number)}
        <% end %>
        <span :if={@has_total_count} class={@theme.pagination_count_class} data-key="pagination_count_class">
          ({dgettext("cinder", "showing %{start}-%{end} of %{total}", start: @start_index, end: @end_index, total: @total_count)})
        </span>
      </div>

      <!-- Right side: Page size selector and navigation -->
      <div class="flex items-center space-x-6">
        <!-- Page size selector (if configurable) -->
        <div :if={@page_size_config.configurable} class={@theme.page_size_container_class} data-key="page_size_container_class">
          <.page_size_selector page_size_config={@page_size_config} theme={@theme} myself={@myself} id={@id} />
        </div>

        <!-- Page navigation -->
        <div class={@theme.pagination_nav_class} data-key="pagination_nav_class">
          <!-- First page and previous -->
          <button
            :if={@page_number > 2}
            phx-click="goto_page"
            phx-value-page="1"
            phx-target={@myself}
            class={@theme.pagination_button_class}
            data-key="pagination_button_class"
            title={dgettext("cinder", "First page")}
          >
            &laquo;
          </button>

          <button
            :if={@has_prev}
            phx-click="goto_page"
            phx-value-page={@page_number - 1}
            phx-target={@myself}
            class={@theme.pagination_button_class}
            data-key="pagination_button_class"
            title={dgettext("cinder", "Previous page")}
          >
            &lsaquo;
          </button>

          <!-- Page numbers -->
          <span :for={page <- @page_range} class="inline-flex">
            <button
              :if={page != @page_number}
              phx-click="goto_page"
              phx-value-page={page}
              phx-target={@myself}
              class={@theme.pagination_button_class}
              data-key="pagination_button_class"
              title={dgettext("cinder", "Go to page %{page}", %{page: page})}
            >
              {page}
            </button>
            <span :if={page == @page_number} class={@theme.pagination_current_class} data-key="pagination_current_class">
              {page}
            </span>
          </span>

          <!-- Next and last page -->
          <button
            :if={@has_next}
            phx-click="goto_page"
            phx-value-page={@page_number + 1}
            phx-target={@myself}
            class={@theme.pagination_button_class}
            data-key="pagination_button_class"
            title={dgettext("cinder", "Next page")}
          >
            &rsaquo;
          </button>

          <button
            :if={@total_pages && @page_number < @total_pages - 1}
            phx-click="goto_page"
            phx-value-page={@total_pages}
            phx-target={@myself}
            class={@theme.pagination_button_class}
            data-key="pagination_button_class"
            title={dgettext("cinder", "Last page")}
          >
            &raquo;
          </button>
        </div>
      </div>
      </div>
    </div>
    """
  end

  # Keyset pagination (cursor-based prev/next)
  # Note: "First" and "Last" buttons are not included because keyset pagination
  # doesn't support arbitrary page jumps - only sequential navigation.
  #
  # Why we handle both Ash.Page.Keyset and Ash.Page.Offset here:
  # On the first page (no cursor), there's no way to force keyset mode - Ash falls back
  # to app config. New Ash installs default to keyset, but older apps may default to offset.
  # Once navigation begins (after/before cursor provided), Ash returns Keyset.
  defp render_keyset(assigns) do
    page = assigns.page

    has_prev = has_previous_keyset_page?(page)
    has_next = has_next_keyset_page?(page)
    page_number = Map.get(assigns, :current_page, 1)
    total_count = Map.get(assigns, :total_count) || page.count
    start_index = if page.results == [], do: 0, else: (page_number - 1) * page.limit + 1
    end_index = start_index + length(page.results) - 1
    end_index = if is_integer(total_count), do: min(end_index, total_count), else: end_index

    assigns =
      assigns
      |> assign(:total_count, total_count)
      |> assign(:has_total_count, is_integer(total_count))
      |> assign(:has_prev, has_prev)
      |> assign(:has_next, has_next)
      |> assign(:page_number, page_number)
      |> assign(:start_index, start_index)
      |> assign(:end_index, max(end_index, 0))

    ~H"""
    <div class={@theme.pagination_wrapper_class} data-key="pagination_wrapper_class">
      <div class={@theme.pagination_container_class} data-key="pagination_container_class">
      <!-- Left side: Count and stable ordinal range -->
      <div class={@theme.pagination_info_class} data-key="pagination_info_class">
        {dgettext("cinder", "Page %{current}", current: @page_number)}
        <span :if={@has_total_count} class={@theme.pagination_count_class} data-key="pagination_count_class">
          ({dgettext("cinder", "showing %{start}-%{end} of %{total}", start: @start_index, end: @end_index, total: @total_count)})
        </span>
      </div>

      <!-- Right side: Page size selector and navigation -->
      <div class="flex items-center space-x-6">
        <!-- Page size selector (if configurable) -->
        <div :if={@page_size_config.configurable} class={@theme.page_size_container_class} data-key="page_size_container_class">
          <.page_size_selector page_size_config={@page_size_config} theme={@theme} myself={@myself} id={@id} />
        </div>

        <!-- Keyset navigation: Prev / Next only -->
        <div class={@theme.pagination_nav_class} data-key="pagination_nav_class">
          <!-- Previous page -->
          <button
            phx-click="prev_page"
            phx-target={@myself}
            class={@theme.pagination_button_class}
            data-key="pagination_button_class"
            disabled={!@has_prev}
            title={dgettext("cinder", "Previous page")}
          >
            &lsaquo; {dgettext("cinder", "Prev")}
          </button>

          <!-- Next page -->
          <button
            phx-click="next_page"
            phx-target={@myself}
            class={@theme.pagination_button_class}
            data-key="pagination_button_class"
            disabled={!@has_next}
            title={dgettext("cinder", "Next page")}
          >
            {dgettext("cinder", "Next")} &rsaquo;
          </button>
        </div>
      </div>
      </div>
    </div>
    """
  end

  defp render_infinite(assigns) do
    page = assigns.page
    has_next = Map.get(assigns, :has_next, has_next_keyset_page?(page))
    total_count = Map.get(assigns, :total_count) || Map.get(page, :count)

    assigns =
      assigns
      |> assign(:error, Map.get(assigns, :error, false))
      |> assign(:has_next, has_next)
      |> assign(:loading, Map.get(assigns, :loading, false))
      |> assign(:infinite_load, Map.get(assigns, :infinite_load, :automatic))
      |> assign(:overscan, Map.get(assigns, :overscan, 1))
      |> assign(
        :load_more_label,
        Map.get(assigns, :load_more_label) || dgettext("cinder", "Load more")
      )
      |> assign(:total_count, total_count)

    ~H"""
    <div
      class={@theme.pagination_wrapper_class}
      data-key="pagination_wrapper_class"
      data-pagination-mode="infinite"
    >
      <div class={@theme.pagination_container_class} data-key="pagination_container_class">
        <div
          :if={is_integer(@total_count)}
          class={[
            @theme.pagination_info_class,
            @infinite_load == :automatic && "h-px overflow-hidden p-0"
          ]}
          data-key="pagination_info_class"
          data-pagination-state="counted"
        >
          {dgettext("cinder", "%{total} items", total: @total_count)}
        </div>

        <div
          :if={@loading}
          class={@theme.pagination_info_class}
          data-key="pagination_info_class"
          data-pagination-state="loading"
          role="status"
        >
          {dgettext("cinder", "Loading more items...")}
        </div>

        <button
          :if={@error}
          type="button"
          class={@theme.pagination_button_class}
          data-pagination-state="error"
          phx-click="retry_load_more"
          phx-target={@myself}
        >
          {dgettext("cinder", "Loading failed. Try again")}
        </button>

        <div
          :if={@has_next and not @loading and not @error}
          id={"#{@id}-infinite-sentinel"}
          class={@theme.pagination_info_class}
          data-key="pagination_info_class"
          data-pagination-state="ready"
          data-infinite-prefetch-distance={if @infinite_load == :automatic, do: "viewport"}
          data-infinite-overscan={if @infinite_load == :automatic, do: @overscan}
          phx-hook={if @infinite_load == :automatic, do: "CinderInfiniteSentinel"}
          phx-target={@myself}
        >
          <button
            type="button"
            class={[@theme.pagination_button_class, @infinite_load == :automatic && "sr-only"]}
            phx-click="load_more"
            phx-target={@myself}
          >
            {@load_more_label}
          </button>
        </div>

        <div
          :if={not @has_next and not @loading and not @error}
          class={@theme.pagination_info_class}
          data-key="pagination_info_class"
          data-pagination-state="end"
          role="status"
        >
          {dgettext("cinder", "You have reached the end of this list")}
        </div>
      </div>
    </div>
    """
  end

  defp page_size_selector(assigns) do
    dropdown_id = "#{assigns.id}-page-size-options"
    # Split the translated string on {selector} to allow flexible word order
    [before_selector, after_selector] =
      dgettext("cinder", "Show {selector} per page")
      |> String.split("{selector}")

    assigns =
      assigns
      |> assign(:dropdown_id, dropdown_id)
      |> assign(:before_selector, before_selector)
      |> assign(:after_selector, after_selector)

    ~H"""
    <div class="flex items-center space-x-2">
      <span :if={@before_selector != ""} class={@theme.page_size_label_class} data-key="page_size_label_class">
        {@before_selector}
      </span>
      <div class="relative">
        <button
          type="button"
          class={@theme.page_size_dropdown_class}
          data-key="page_size_dropdown_class"
          phx-click={JS.toggle(to: "##{@dropdown_id}")}
          aria-haspopup="true"
          aria-expanded="false"
        >
          {@page_size_config.selected_page_size}
          <svg class="w-4 h-4 ml-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7"></path>
          </svg>
        </button>
        <div
          id={@dropdown_id}
          class={["absolute top-full right-0 mt-1 z-50 hidden", @theme.page_size_dropdown_container_class]}
          data-key="page_size_dropdown_container_class"
          phx-click-away={JS.hide(to: "##{@dropdown_id}")}
        >
          <button
            :for={option <- @page_size_config.page_size_options}
            type="button"
            class={[
              @theme.page_size_option_class,
              (@page_size_config.selected_page_size == option && @theme.page_size_selected_class || "")
            ]}
            data-key="page_size_option_class"
            phx-click={JS.push("change_page_size") |> JS.hide(to: "##{@dropdown_id}")}
            phx-value-page_size={option}
            phx-target={@myself}
          >
            {option}
          </button>
        </div>
      </div>
      <span :if={@after_selector != ""} class={@theme.page_size_label_class} data-key="page_size_label_class">
        {@after_selector}
      </span>
    </div>
    """
  end

  defp build_page_range(current_page, total_pages) do
    range_start = max(1, current_page - 2)
    range_end = min(total_pages, current_page + 2)

    if range_start <= range_end do
      Enum.to_list(range_start..range_end)
    else
      [1]
    end
  end

  # Check if there's a previous page in keyset mode.
  # - If we used `after` cursor (forward navigation): there's always a previous page
  # - If we used `before` cursor (backward navigation): `more?` tells us if there's more behind
  # - If neither: we're on the first page
  defp has_previous_keyset_page?(%Ash.Page.Keyset{
         after: after_cursor,
         before: before_cursor,
         more?: more?
       }) do
    cond do
      not is_nil(after_cursor) -> true
      not is_nil(before_cursor) -> more?
      true -> false
    end
  end

  defp has_previous_keyset_page?(%Ash.Page.Offset{offset: offset}), do: offset > 0

  # Check if there's a next page in keyset mode.
  # - If we used `before` cursor (backward navigation): there's always a next page (we came from there)
  # - If we used `after` cursor or no cursor: `more?` tells us if there's more ahead
  defp has_next_keyset_page?(%Ash.Page.Keyset{before: before_cursor})
       when not is_nil(before_cursor),
       do: true

  defp has_next_keyset_page?(%Ash.Page.Keyset{more?: more?}), do: more?

  defp has_next_keyset_page?(%Ash.Page.Offset{more?: more?}), do: more?
end
