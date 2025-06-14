defmodule Cinder.Table.LiveComponent do
  @moduledoc """
  LiveComponent for interactive data tables with Ash query execution.

  Handles state management, data loading, and pagination for the table component.
  """

  use Phoenix.LiveComponent
  require Ash.Query
  require Logger

  @impl true
  def mount(socket) do
    {:ok, socket}
  end

  @impl true
  def update(%{loading: true} = assigns, socket) do
    # Keep existing data visible while loading
    {:ok, assign(socket, Map.take(assigns, [:loading]))}
  end

  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> assign_defaults()
      |> assign_column_definitions()
      |> decode_url_state(assigns)
      |> load_data_if_needed()

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class={[@theme.container_class, "relative"]} {@theme.container_data}>
      <!-- Filter Controls -->
      <div class={@theme.controls_class} {@theme.controls_data}>
        <Cinder.FilterManager.render_filter_controls
          columns={@columns}
          filters={@filters}
          theme={@theme}
          target={@myself}
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
            <tr :for={item <- @data} class={@theme.row_class} {@theme.row_data}>
              <td :for={column <- @columns} class={[@theme.td_class, column.class]} {@theme.td_data}>
                {render_slot(column.slot, item)}
              </td>
            </tr>
            <tr :if={@data == [] and not @loading}>
              <td colspan={length(@columns)} class={@theme.empty_class} {@theme.empty_data}>
                No results found
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
          Loading...
        </div>
      </div>

      <!-- Pagination -->
      <div :if={@page_info.total_pages > 1} class={@theme.pagination_wrapper_class} {@theme.pagination_wrapper_data}>
        <.pagination_controls
          page_info={@page_info}
          theme={@theme}
          myself={@myself}
        />
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("goto_page", %{"page" => page}, socket) do
    page = String.to_integer(page)

    socket =
      socket
      |> assign(:current_page, page)
      |> notify_state_change()
      |> load_data()

    {:noreply, socket}
  end

  @impl true
  def handle_event("clear_filter", %{"key" => key}, socket) do
    new_filters = Cinder.FilterManager.clear_filter(socket.assigns.filters, key)

    socket =
      socket
      |> assign(:filters, new_filters)
      |> assign(:current_page, 1)
      |> load_data()

    # Notify parent about state changes
    socket = notify_state_change(socket, new_filters)

    {:noreply, socket}
  end

  @impl true
  def handle_event("toggle_sort", %{"key" => key}, socket) do
    current_sort = socket.assigns.sort_by
    new_sort = Cinder.QueryBuilder.toggle_sort_direction(current_sort, key)

    socket =
      socket
      |> assign(:sort_by, new_sort)
      # Reset to first page when sorting changes
      |> assign(:current_page, 1)
      |> notify_state_change()
      |> load_data()

    {:noreply, socket}
  end

  @impl true
  def handle_event("clear_all_filters", _params, socket) do
    new_filters = Cinder.FilterManager.clear_all_filters(socket.assigns.filters)

    socket =
      socket
      |> assign(:filters, new_filters)
      |> assign(:current_page, 1)
      |> load_data()

    # Notify parent about state changes
    socket = notify_state_change(socket)

    {:noreply, socket}
  end

  @impl true
  def handle_event("filter_change", %{"filters" => filter_params}, socket) do
    new_filters = Cinder.FilterManager.params_to_filters(filter_params, socket.assigns.columns)

    socket =
      socket
      |> assign(:filters, new_filters)
      # Reset to first page when filters change
      |> assign(:current_page, 1)
      |> load_data()

    # Notify parent about state changes
    socket = notify_state_change(socket, new_filters)

    {:noreply, socket}
  end

  @impl true
  def handle_event(
        "toggle_multiselect_option",
        %{"field" => field, "option" => value},
        socket
      )
      when value != "" do
    # Get current filter values for this field
    current_filter =
      Map.get(socket.assigns.filters, field, %{type: :multi_select, value: [], operator: :in})

    current_values = Map.get(current_filter, :value, [])

    # Toggle the value - add if not present, remove if present
    new_values =
      if value in current_values do
        Enum.reject(current_values, &(&1 == value))
      else
        current_values ++ [value]
      end

    new_filters =
      if Enum.empty?(new_values) do
        # Remove the filter entirely if no values left
        Map.delete(socket.assigns.filters, field)
      else
        # Create proper filter structure
        new_filter = %{
          type: :multi_select,
          value: new_values,
          operator: :in
        }

        Map.put(socket.assigns.filters, field, new_filter)
      end

    socket =
      socket
      |> assign(:filters, new_filters)
      |> assign(:current_page, 1)
      |> load_data()

    # Notify parent about state changes
    socket = notify_state_change(socket, new_filters)

    {:noreply, socket}
  end

  # Notify parent LiveView about filter changes
  defp notify_state_change(socket, filters \\ nil) do
    filters = filters || socket.assigns.filters
    current_page = socket.assigns.current_page
    sort_by = socket.assigns.sort_by

    state = %{
      filters: filters,
      current_page: current_page,
      sort_by: sort_by
    }

    Cinder.UrlManager.notify_state_change(socket, state)
  end

  # Decode URL state from URL parameters
  defp decode_url_state(socket, assigns) do
    # Check if we have raw URL params (preferred method for proper filter decoding)
    raw_params = Map.get(assigns, :url_raw_params, %{})

    if not Enum.empty?(raw_params) do
      # Use raw params with actual columns for proper filter decoding
      decoded_state = Cinder.UrlManager.decode_state(raw_params, socket.assigns.columns)

      socket
      |> assign(:filters, decoded_state.filters)
      |> assign(:current_page, decoded_state.current_page)
      |> assign(:sort_by, decoded_state.sort_by)
    else
      # Fallback to old method (for backward compatibility)
      url_params =
        %{
          "page" => Map.get(assigns, :url_page),
          "sort" => Map.get(assigns, :url_sort)
        }
        |> Map.merge(Map.get(assigns, :url_filters, %{}))
        |> Enum.reject(fn {_k, v} -> is_nil(v) end)
        |> Enum.into(%{})

      if Enum.empty?(url_params) do
        socket
      else
        decoded_state = Cinder.UrlManager.decode_state(url_params, socket.assigns.columns)

        socket
        |> assign(:filters, decoded_state.filters)
        |> assign(:current_page, decoded_state.current_page)
        |> assign(:sort_by, decoded_state.sort_by)
      end
    end
  end

  # Pagination controls component
  defp pagination_controls(assigns) do
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
      <div class={@theme.pagination_nav_class} {@theme.pagination_nav_data}>
        <!-- First page and previous -->
        <button
          :if={@page_info.current_page > 2}
          phx-click="goto_page"
          phx-value-page="1"
          phx-target={@myself}
          class={@theme.pagination_button_class}
          {@theme.pagination_button_data}
          title="First page"
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
          title="Previous page"
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
          title="Next page"
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
          title="Last page"
        >
          &raquo;
        </button>
      </div>
    </div>
    """
  end

  # Build page range for pagination (show current page +/- 2 pages)
  defp build_page_range(page_info) do
    current = page_info.current_page
    total = page_info.total_pages

    # Calculate range around current page
    range_start = max(1, current - 2)
    range_end = min(total, current + 2)

    Enum.to_list(range_start..range_end)
  end

  # Sort arrow component - customizable via theme
  defp sort_arrow(assigns) do
    ~H"""
    <span class={Map.get(@theme, :sort_arrow_wrapper_class, "inline-block ml-1")}>
      <%= case @sort_direction do %>
        <% :asc -> %>
          <.icon
            name={Map.get(@theme, :sort_asc_icon_name, "hero-chevron-up")}
            class={[Map.get(@theme, :sort_asc_icon_class, "w-3 h-3 inline"), (@loading && "animate-pulse" || "")]}
          />
        <% :desc -> %>
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

  # Simple heroicon component
  defp icon(%{name: "hero-" <> _} = assigns) do
    ~H"""
    <span class={[@name, @class]} />
    """
  end

  # Private functions

  defp assign_defaults(socket) do
    assigns = socket.assigns

    socket
    |> assign(:page_size, assigns[:page_size] || 25)
    |> assign(:current_page, assigns[:current_page] || 1)
    |> assign(:loading, false)
    |> assign(:data, [])
    |> assign(:sort_by, [])
    |> assign(:filters, assigns[:filters] || %{})
    |> assign(:search_term, "")
    |> assign(:theme, Cinder.Theme.merge(assigns[:theme] || %{}))
    |> assign(:query_opts, assigns[:query_opts] || [])
    |> assign(:page_info, Cinder.QueryBuilder.build_error_page_info())
  end

  defp assign_column_definitions(socket) do
    resource = socket.assigns.query

    columns =
      socket.assigns.col
      |> Enum.map(&Cinder.Column.parse_column(&1, resource))
      |> Enum.map(&convert_column_to_legacy_format/1)

    assign(socket, :columns, columns)
  end

  defp load_data_if_needed(socket) do
    # Always load data on mount or update
    load_data(socket)
  end

  defp load_data(socket) do
    %{
      query: resource,
      query_opts: query_opts,
      actor: actor,
      page_size: page_size,
      current_page: current_page,
      sort_by: sort_by,
      filters: filters,
      columns: columns
    } = socket.assigns

    # Extract variables to avoid socket copying in async function
    resource_var = resource

    options = [
      actor: actor,
      query_opts: query_opts,
      filters: filters,
      sort_by: sort_by,
      page_size: page_size,
      current_page: current_page,
      columns: columns
    ]

    socket
    |> assign(:loading, true)
    |> start_async(:load_data, fn ->
      Cinder.QueryBuilder.build_and_execute(resource_var, options)
    end)
  end

  @impl true
  def handle_async(:load_data, {:ok, {:ok, {results, page_info}}}, socket) do
    socket =
      socket
      |> assign(:loading, false)
      |> assign(:data, results)
      |> assign(:page_info, page_info)

    {:noreply, socket}
  end

  @impl true
  def handle_async(:load_data, {:ok, {:error, error}}, socket) do
    # Log error for developer debugging
    Logger.error(
      "Cinder table query failed for #{socket.assigns.query}: #{inspect(error)}",
      %{
        resource: socket.assigns.query,
        filters: socket.assigns.filters,
        sort_by: socket.assigns.sort_by,
        current_page: socket.assigns.current_page,
        error: inspect(error)
      }
    )

    socket =
      socket
      |> assign(:loading, false)
      |> assign(:data, [])
      |> assign(:page_info, Cinder.QueryBuilder.build_error_page_info())

    {:noreply, socket}
  end

  @impl true
  def handle_async(:load_data, {:exit, reason}, socket) do
    # Log error for developer debugging
    Logger.error(
      "Cinder table query crashed for #{socket.assigns.query}: #{inspect(reason)}",
      %{
        resource: socket.assigns.query,
        filters: socket.assigns.filters,
        sort_by: socket.assigns.sort_by,
        current_page: socket.assigns.current_page,
        reason: inspect(reason)
      }
    )

    socket =
      socket
      |> assign(:loading, false)
      |> assign(:data, [])
      |> assign(:page_info, Cinder.QueryBuilder.build_error_page_info())

    {:noreply, socket}
  end

  # Convert new Column struct to legacy format for backward compatibility
  defp convert_column_to_legacy_format(%Cinder.Column{} = column) do
    %{
      field: column.field,
      label: column.label,
      sortable: column.sortable,
      searchable: column.searchable,
      filterable: column.filterable,
      filter_type: column.filter_type,
      filter_options: column.filter_options,
      filter_fn: column.filter_fn,
      options: column.options,
      display_field: column.display_field,
      sort_fn: column.sort_fn,
      search_fn: column.search_fn,
      class: column.class,
      slot: column.slot
    }
  end
end
