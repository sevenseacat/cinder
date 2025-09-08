defmodule Cinder.Table.LiveComponent do
  @moduledoc """
  LiveComponent for interactive data tables with Ash query execution.

  Handles state management, data loading, and pagination for the table component.
  """

  use Phoenix.LiveComponent
  require Ash.Query
  require Logger
  alias Phoenix.LiveView.JS
  alias Cinder.Messages

  @impl true
  def mount(socket) do
    {:ok, socket}
  end

  @impl true
  def update(%{loading: true} = assigns, socket) do
    # Keep existing data visible while loading
    {:ok, assign(socket, Map.take(assigns, [:loading]))}
  end

  def update(%{refresh: true} = assigns, socket) do
    # Force refresh of table data
    socket =
      socket
      |> assign(Map.drop(assigns, [:refresh]))
      |> assign_defaults()
      |> assign_column_definitions()
      |> load_data()

    {:ok, socket}
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
      <!-- Filter Controls (including search) -->
      <div class={@theme.controls_class} {@theme.controls_data}>
        <Cinder.FilterManager.render_filter_controls
          columns={@columns}
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
  def handle_event("change_page_size", %{"page_size" => page_size}, socket) do
    page_size = String.to_integer(page_size)

    # Update the page size config with the new selected size
    updated_config = %{socket.assigns.page_size_config | selected_page_size: page_size}

    socket =
      socket
      |> assign(:page_size, page_size)
      |> assign(:page_size_config, updated_config)
      # Reset to page 1 when changing page size
      |> assign(:current_page, 1)
      |> notify_state_change()
      |> load_data()

    {:noreply, socket}
  end

  @impl true
  def handle_event("clear_filter", %{"key" => "search"}, socket) do
    # Handle search clearing
    socket =
      socket
      |> assign(:search_term, "")
      |> assign(:current_page, 1)
      |> load_data()

    # Notify parent about state changes
    socket = notify_state_change(socket)

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

    # Find the column to get its sort cycle configuration
    column = Enum.find(socket.assigns.col, &(&1.field == key))
    sort_cycle = if column, do: column.sort_cycle, else: nil

    # Use cycle-aware sort toggling
    new_sort = Cinder.QueryBuilder.toggle_sort_with_cycle(current_sort, key, sort_cycle)

    # Check if URL sync is enabled - if so, skip data loading and let handle_params do it
    url_sync_enabled = !!socket.assigns[:on_state_change]

    socket =
      if url_sync_enabled do
        # URL sync enabled: update state but don't load data yet
        # Data will be loaded via handle_params when URL updates
        socket
        |> assign(:sort_by, new_sort)
        |> assign(:current_page, 1)
        |> assign(:user_has_interacted, true)
      else
        # URL sync disabled: load data immediately
        socket
        |> assign(:sort_by, new_sort)
        |> assign(:current_page, 1)
        |> assign(:user_has_interacted, true)
        |> load_data()
      end

    notify_state_change(socket)

    {:noreply, socket}
  end

  @impl true
  def handle_event("refresh", _params, socket) do
    socket = load_data(socket)
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
  def handle_event("filter_change", params, socket) do
    # Process filters - use empty map when no "filters" key to handle unchecked checkboxes
    new_filters =
      Map.get(params, "filters", %{})
      |> Cinder.FilterManager.params_to_filters(socket.assigns.columns)

    # Process search if present
    search_term =
      case Map.get(params, "search") do
        nil -> socket.assigns.search_term
        term -> term
      end

    # Check if URL sync is enabled - if so, skip data loading and let handle_params do it
    url_sync_enabled = !!socket.assigns[:on_state_change]

    socket =
      if url_sync_enabled do
        # URL sync enabled: update state but don't load data yet
        # Data will be loaded via handle_params when URL updates
        socket
        |> assign(:filters, new_filters)
        |> assign(:search_term, search_term)
        |> assign(:current_page, 1)
      else
        # URL sync disabled: load data immediately
        socket
        |> assign(:filters, new_filters)
        |> assign(:search_term, search_term)
        |> assign(:current_page, 1)
        |> load_data()
      end

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

  @impl true
  def handle_event("select_option", %{"field" => field, "option" => value}, socket) do
    current_filters = Map.get(socket.assigns, :filters, %{})

    new_filters =
      if value == "" do
        Map.delete(current_filters, field)
      else
        # Create proper filter structure for single select
        new_filter = %{
          type: :select,
          value: value,
          operator: :equals
        }

        Map.put(current_filters, field, new_filter)
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
    page_size_config = socket.assigns.page_size_config
    search_term = socket.assigns.search_term

    state = %{
      filters: filters,
      current_page: current_page,
      sort_by: sort_by,
      page_size: page_size_config.selected_page_size,
      default_page_size: page_size_config.default_page_size,
      search_term: search_term
    }

    Cinder.UrlManager.notify_state_change(socket, state)
  end

  # Decode URL state from URL parameters
  defp decode_url_state(socket, assigns) do
    if Map.has_key?(assigns, :url_raw_params) do
      raw_params = assigns.url_raw_params

      # Use raw params with actual columns for proper filter decoding
      decoded_state = Cinder.UrlManager.decode_state(raw_params, socket.assigns.columns)

      # Only use extracted query sorts if this is the initial load (no previous user interaction)
      # If URL params are empty after user interaction, preserve the user's choice (empty sort)
      final_sort_by =
        cond do
          # URL has explicit sorts - use them
          decoded_state.sort_by != [] and not is_nil(decoded_state.sort_by) ->
            decoded_state.sort_by

          # URL has no sorts AND this is likely after user interaction - preserve empty sort
          Map.get(socket.assigns, :user_has_interacted, false) ->
            []

          # URL has no sorts AND this is initial load - use extracted query sorts
          true ->
            socket.assigns.sort_by
        end

      # Update page_size_config if URL explicitly contains a page_size parameter
      updated_socket =
        if Map.has_key?(raw_params, "page_size") do
          updated_page_size_config = %{
            socket.assigns.page_size_config
            | selected_page_size: decoded_state.page_size
          }

          socket
          |> assign(:page_size, decoded_state.page_size)
          |> assign(:page_size_config, updated_page_size_config)
        else
          socket
        end

      updated_socket
      |> assign(:filters, decoded_state.filters)
      |> assign(:current_page, decoded_state.current_page)
      |> assign(:sort_by, final_sort_by)
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

        final_sort_by =
          cond do
            # URL has explicit sorts - use them
            decoded_state.sort_by != [] and not is_nil(decoded_state.sort_by) ->
              decoded_state.sort_by

            # URL has no sorts AND this is likely after user interaction - preserve empty sort
            Map.get(socket.assigns, :user_has_interacted, false) ->
              []

            # URL has no sorts AND this is initial load - use extracted query sorts
            true ->
              socket.assigns.sort_by
          end

        socket
        |> assign(:filters, decoded_state.filters)
        |> assign(:current_page, decoded_state.current_page)
        |> assign(:sort_by, final_sort_by)
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
        {Messages.dgettext("cinder", "Page %{current} of %{total}", current: @page_info.current_page, total: @page_info.total_pages)}
        <span class={@theme.pagination_count_class} {@theme.pagination_count_data}>
          ({Messages.dgettext("cinder", "showing %{start}-%{end} of %{total}", start: @page_info.start_index, end: @page_info.end_index, total: @page_info.total_count)})
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
          title={Messages.dgettext("cinder", "First page")}
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
          title={Messages.dgettext("cinder", "Previous page")}
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
            title={Messages.dgettext("cinder", "Go to page %{page}", %{page: page})}
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
          title={Messages.dgettext("cinder", "Next page")}
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
          title={Messages.dgettext("cinder", "Last page")}
        >
          &raquo;
        </button>
        </div>
      </div>
    </div>
    """
  end

  # Page size selector component
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

  # Private functions

  defp assign_defaults(socket) do
    assigns = socket.assigns

    page_size_config =
      assigns[:page_size_config] ||
        %{
          selected_page_size: 25,
          page_size_options: [],
          default_page_size: 25,
          configurable: false
        }

    selected_page_size = page_size_config.selected_page_size

    socket
    |> assign(:page_size, selected_page_size)
    |> assign(:page_size_config, page_size_config)
    |> assign(:current_page, assigns[:current_page] || 1)
    |> assign(:loading, false)
    |> assign(:data, assigns[:data] || [])
    |> assign(:sort_by, assigns[:sort_by] || extract_initial_sorts(assigns))
    |> assign(:filters, assigns[:filters] || %{})
    |> assign(:search_term, assigns[:search_term] || "")
    |> assign(:theme, assigns[:theme] || Cinder.Theme.default())
    |> assign(:query_opts, assigns[:query_opts] || [])
    |> assign(:page_info, Cinder.QueryBuilder.build_error_page_info())
    |> assign(:user_has_interacted, Map.get(socket.assigns, :user_has_interacted, false))
  end

  defp assign_column_definitions(socket) do
    resource = socket.assigns.query

    columns =
      socket.assigns.col
      |> Enum.map(&Cinder.Column.parse_column(&1, resource))
      |> Enum.map(&convert_column_to_legacy_format/1)

    assign(socket, :columns, columns)
  end

  defp extract_initial_sorts(assigns) do
    # Extract sorts from query if present, otherwise use empty list
    # This allows table UI to show initial sort state from incoming queries
    query = assigns[:query]
    columns = assigns[:col] || []

    # Convert column slots to simple column format for sort extraction
    simple_columns =
      Enum.map(columns, fn col ->
        field_name =
          case col.field do
            field when is_atom(field) -> Atom.to_string(field)
            field when is_binary(field) -> field
            field -> inspect(field)
          end

        %{field: field_name}
      end)

    case query do
      nil -> []
      query -> Cinder.QueryBuilder.extract_query_sorts(query, simple_columns)
    end
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
      tenant: tenant,
      page_size: page_size,
      current_page: current_page,
      sort_by: sort_by,
      filters: filters,
      columns: columns,
      search_term: search_term
    } = socket.assigns

    # Extract variables to avoid socket copying in async function
    resource_var = resource

    options = [
      actor: actor,
      tenant: tenant,
      query_opts: query_opts,
      filters: filters,
      sort_by: sort_by,
      page_size: page_size,
      current_page: current_page,
      columns: columns,
      search_term: search_term,
      search_fn: socket.assigns.search_fn,
      pagination_configured: socket.assigns.page_size_config.configurable || page_size != 25
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
      "Cinder table query failed for #{inspect(socket.assigns.query)}: #{inspect(error)}",
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
      "Cinder table query crashed for #{inspect(socket.assigns.query)}: #{inspect(reason)}",
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
      search_fn: column.search_fn,
      class: column.class,
      slot: column.slot
    }
  end

  # Helper functions for row click functionality
  defp get_row_classes(base_classes, row_click) do
    if row_click do
      [base_classes, "cursor-pointer"]
    else
      base_classes
    end
  end
end
