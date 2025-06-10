defmodule Cinder.Table.LiveComponent do
  @moduledoc """
  LiveComponent for interactive data tables with Ash query execution.

  Handles state management, data loading, and pagination for the table component.
  """

  use Phoenix.LiveComponent
  require Ash.Query

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
      |> load_data_if_needed()

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class={[@theme.container_class, "relative"]}>
      <!-- Filter Controls -->
      <div class={@theme.controls_class}>
        <.filter_controls
          columns={@columns}
          filters={@filters}
          theme={@theme}
          myself={@myself}
        />
      </div>

      <!-- Main table -->
      <div class={@theme.table_wrapper_class}>
        <table class={@theme.table_class}>
          <thead class={@theme.thead_class}>
            <tr class={@theme.header_row_class}>
              <th :for={column <- @columns} class={[@theme.th_class, column.class]}>
                <div :if={column.sortable}
                     class={["cursor-pointer select-none", (@loading && "opacity-75" || "")]}
                     phx-click="toggle_sort"
                     phx-value-key={column.key}
                     phx-target={@myself}>
                  {column.label}
                  <span class={@theme.sort_indicator_class}>
                    <.sort_arrow sort_direction={get_sort_direction(@sort_by, column.key)} theme={@theme} loading={@loading} />
                  </span>
                </div>
                <div :if={not column.sortable}>
                  {column.label}
                </div>
              </th>
            </tr>
          </thead>
          <tbody class={[@theme.tbody_class, (@loading && "opacity-75" || "")]}>
            <tr :for={item <- @data} class={@theme.row_class}>
              <td :for={column <- @columns} class={[@theme.td_class, column.class]}>
                {render_slot(column.slot, item)}
              </td>
            </tr>
            <tr :if={@data == [] and not @loading}>
              <td colspan={length(@columns)} class={@theme.empty_class}>
                No results found
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <!-- Loading indicator -->
      <div :if={@loading} class="absolute top-0 right-0 mt-2 mr-2">
        <div class="flex items-center text-sm text-gray-500">
          <svg class="animate-spin -ml-1 mr-2 h-4 w-4 text-gray-500" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
            <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
            <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
          </svg>
          Loading...
        </div>
      </div>

      <!-- Pagination -->
      <div class={@theme.pagination_wrapper_class}>
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
      |> load_data()

    {:noreply, socket}
  end

  @impl true
  def handle_event("toggle_sort", %{"key" => key}, socket) do
    current_sort = socket.assigns.sort_by
    new_sort = toggle_sort_direction(current_sort, key)

    socket =
      socket
      |> assign(:sort_by, new_sort)
      # Reset to first page when sorting changes
      |> assign(:current_page, 1)
      |> load_data()

    {:noreply, socket}
  end

  @impl true
  def handle_event("clear_all_filters", _params, socket) do
    socket =
      socket
      |> assign(:filters, %{})
      # Reset to first page when filters change
      |> assign(:current_page, 1)
      |> load_data()

    {:noreply, socket}
  end

  @impl true
  def handle_event("update_filter", %{"key" => key, "value" => value, "type" => type}, socket) do
    current_filters = socket.assigns.filters
    
    new_filters = 
      if value == "" or is_nil(value) do
        Map.delete(current_filters, key)
      else
        operator = case type do
          "text" -> :contains
          "select" -> :equals
          _ -> :equals
        end
        
        Map.put(current_filters, key, %{
          type: String.to_atom(type),
          value: value,
          operator: operator
        })
      end

    socket =
      socket
      |> assign(:filters, new_filters)
      # Reset to first page when filters change
      |> assign(:current_page, 1)
      |> load_data()

    {:noreply, socket}
  end

  @impl true
  def handle_event("clear_filter", %{"key" => key}, socket) do
    current_filters = socket.assigns.filters
    new_filters = Map.delete(current_filters, key)

    socket =
      socket
      |> assign(:filters, new_filters)
      # Reset to first page when filters change
      |> assign(:current_page, 1)
      |> load_data()

    {:noreply, socket}
  end

  # Pagination controls component
  defp pagination_controls(assigns) do
    ~H"""
    <div :if={@page_info.total_pages > 1} class={@theme.pagination_container_class}>
      <!-- Previous button -->
      <button
        :if={@page_info.has_previous_page}
        phx-click="goto_page"
        phx-value-page={@page_info.current_page - 1}
        phx-target={@myself}
        class={@theme.pagination_button_class}
      >
        Previous
      </button>

      <!-- Page info -->
      <span class={@theme.pagination_info_class}>
        Page {@page_info.current_page} of {@page_info.total_pages}
        <span class={@theme.pagination_count_class}>
          (showing {@page_info.start_index}-{@page_info.end_index} of {@page_info.total_count})
        </span>
      </span>

      <!-- Next button -->
      <button
        :if={@page_info.has_next_page}
        phx-click="goto_page"
        phx-value-page={@page_info.current_page + 1}
        phx-target={@myself}
        class={@theme.pagination_button_class}
      >
        Next
      </button>
    </div>
    """
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

  # Filter controls component
  defp filter_controls(assigns) do
    filterable_columns = Enum.filter(assigns.columns, & &1.filterable)
    active_filters = Enum.count(assigns.filters)
    
    assigns = assign(assigns, :filterable_columns, filterable_columns)
    assigns = assign(assigns, :active_filters, active_filters)
    
    ~H"""
    <div :if={@filterable_columns != []} class={@theme.filter_container_class}>
      <div class={@theme.filter_header_class}>
        <span class={@theme.filter_title_class}>
          🔍 Filters
          <span :if={@active_filters > 0} class={@theme.filter_count_class}>
            ({@active_filters} active)
          </span>
        </span>
        <button
          :if={@active_filters > 0}
          phx-click="clear_all_filters"
          phx-target={@myself}
          class={@theme.filter_clear_all_class}
        >
          Clear All
        </button>
      </div>
      
      <div class={@theme.filter_inputs_class}>
        <div :for={column <- @filterable_columns} class={@theme.filter_input_wrapper_class}>
          <label class={@theme.filter_label_class}>{column.label}:</label>
          <.filter_input 
            column={column}
            filter_value={Map.get(@filters, column.key)}
            theme={@theme}
            myself={@myself}
          />
        </div>
      </div>
    </div>
    """
  end

  # Filter input component
  defp filter_input(assigns) do
    filter_value = assigns.filter_value
    has_value = filter_value && filter_value.value != ""
    
    assigns = assign(assigns, :has_value, has_value)
    assigns = assign(assigns, :current_value, if(has_value, do: filter_value.value, else: ""))
    
    ~H"""
    <div class="flex items-center space-x-2">
      <div class="flex-1">
        <%= case @column.filter_type do %>
          <% :text -> %>
            <.text_filter_input 
              column={@column}
              current_value={@current_value}
              theme={@theme}
              myself={@myself}
            />
          <% :select -> %>
            <.select_filter_input
              column={@column}
              current_value={@current_value}
              theme={@theme}
              myself={@myself}
            />
          <% _ -> %>
            <div class={@theme.filter_placeholder_class}>
              [Filter type {@column.filter_type} not yet implemented]
            </div>
        <% end %>
      </div>
      
      <!-- Clear individual filter button -->
      <button
        :if={@has_value}
        phx-click="clear_filter"
        phx-value-key={@column.key}
        phx-target={@myself}
        class={@theme.filter_clear_button_class}
        title="Clear filter"
      >
        ✕
      </button>
    </div>
    """
  end

  # Text filter input component
  defp text_filter_input(assigns) do
    placeholder = get_in(assigns.column.filter_options, [:placeholder]) || "Filter #{assigns.column.label}..."
    assigns = assign(assigns, :placeholder, placeholder)
    
    ~H"""
    <input
      type="text"
      value={@current_value}
      placeholder={@placeholder}
      phx-blur="update_filter"
      phx-value-key={@column.key}
      phx-value-type="text"
      phx-target={@myself}
      class={@theme.filter_text_input_class}
    />
    """
  end

  # Select filter input component  
  defp select_filter_input(assigns) do
    options = get_in(assigns.column.filter_options, [:options]) || []
    prompt = get_in(assigns.column.filter_options, [:prompt]) || "All #{assigns.column.label}"
    
    assigns = assign(assigns, :options, options)
    assigns = assign(assigns, :prompt, prompt)
    
    ~H"""
    <select
      phx-change="update_filter"
      phx-value-key={@column.key}
      phx-value-type="select"
      phx-target={@myself}
      class={@theme.filter_select_input_class}
    >
      <option value="">{@prompt}</option>
      <option 
        :for={{label, value} <- @options}
        value={value}
        selected={@current_value == value}
      >
        {label}
      </option>
    </select>
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
    |> assign(:theme, merge_theme(assigns[:theme] || %{}))
    |> assign(:query_opts, assigns[:query_opts] || [])
    |> assign(:page_info, build_error_page_info())
  end

  defp assign_column_definitions(socket) do
    columns =
      socket.assigns.col
      |> Enum.map(&parse_column_definition/1)

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
      current_user: current_user,
      page_size: page_size,
      current_page: current_page,
      sort_by: sort_by,
      filters: filters,
      columns: columns
    } = socket.assigns

    # Extract variables to avoid socket copying in async function
    resource_var = resource
    query_opts_var = query_opts
    current_user_var = current_user
    page_size_var = page_size
    current_page_var = current_page
    sort_by_var = sort_by
    filters_var = filters
    columns_var = columns

    socket
    |> assign(:loading, true)
    |> start_async(:load_data, fn ->
      # Build the query with pagination, sorting, and filtering
      query =
        resource_var
        |> Ash.Query.for_read(:read, %{}, actor: current_user_var)
        |> apply_query_opts(query_opts_var)
        |> apply_filters(filters_var, columns_var)
        |> apply_sorting(sort_by_var, columns_var)
        |> Ash.Query.limit(page_size_var)
        |> Ash.Query.offset((current_page_var - 1) * page_size_var)

      # Execute the query
      case Ash.read(query, actor: current_user_var) do
        {:ok, results} when is_list(results) ->
          {results, current_page_var, page_size_var}

        {:error, error} ->
          {:error, error}
      end
    end)
  end

  @impl true
  def handle_async(:load_data, {:ok, {results, current_page, page_size}}, socket) do
    socket =
      socket
      |> assign(:loading, false)
      |> assign(:data, results)
      |> assign(:page_info, build_page_info_from_list(results, current_page, page_size))

    {:noreply, socket}
  end

  @impl true
  def handle_async(:load_data, {:ok, {:error, error}}, socket) do
    socket =
      socket
      |> assign(:loading, false)
      |> assign(:data, [])
      |> assign(:page_info, build_error_page_info())
      |> put_flash(:error, "Failed to load data: #{inspect(error)}")

    {:noreply, socket}
  end

  @impl true
  def handle_async(:load_data, {:exit, reason}, socket) do
    socket =
      socket
      |> assign(:loading, false)
      |> assign(:data, [])
      |> assign(:page_info, build_error_page_info())
      |> put_flash(:error, "Failed to load data: #{inspect(reason)}")

    {:noreply, socket}
  end

  defp apply_query_opts(query, opts) do
    Enum.reduce(opts, query, fn
      {:load, load_opts}, query ->
        Ash.Query.load(query, load_opts)

      {:select, select_opts}, query ->
        Ash.Query.select(query, select_opts)

      {:filter, _filter_opts}, query ->
        # Filters now handled in apply_filters/3 function
        query

      _other, query ->
        query
    end)
  end

  defp apply_filters(query, filters, _columns) when filters == %{}, do: query

  defp apply_filters(query, filters, columns) do
    Enum.reduce(filters, query, fn {key, filter_config}, query ->
      column = Enum.find(columns, &(&1.key == key))

      cond do
        column && column.filter_fn ->
          # Use custom filter function
          column.filter_fn.(query, filter_config)

        true ->
          # Apply standard filter based on type
          apply_standard_filter(query, key, filter_config, column)
      end
    end)
  end

  defp apply_standard_filter(query, key, filter_config, _column) do
    %{type: type, value: value, operator: operator} = filter_config
    
    case {type, operator} do
      {:text, :contains} ->
        # Use Ash's ilike filter for case insensitive text search
        if String.contains?(key, ".") do
          # Handle relationship fields (e.g., "artist.name") - simplified for now
          query
        else
          field_ref = Ash.Expr.ref(String.to_atom(key))
          search_value = "%#{value}%"
          Ash.Query.filter(query, ilike(^field_ref, ^search_value))
        end
        
      {:text, :starts_with} ->
        if String.contains?(key, ".") do
          query
        else
          # Use ilike filter that matches from the beginning
          field_ref = Ash.Expr.ref(String.to_atom(key))
          search_value = "#{value}%"
          Ash.Query.filter(query, ilike(^field_ref, ^search_value))
        end
        
      {:text, :equals} ->
        if String.contains?(key, ".") do
          query
        else
          field_ref = Ash.Expr.ref(String.to_atom(key))
          Ash.Query.filter(query, ^field_ref == ^value)
        end
        
      {:select, :equals} ->
        if String.contains?(key, ".") do
          query
        else
          field_ref = Ash.Expr.ref(String.to_atom(key))
          Ash.Query.filter(query, ^field_ref == ^value)
        end
        
      _ ->
        # Fallback for unsupported filter types
        query
    end
  end



  defp apply_sorting(query, [], _columns), do: query

  defp apply_sorting(query, sort_by, columns) do
    Enum.reduce(sort_by, query, fn {key, direction}, query ->
      column = Enum.find(columns, &(&1.key == key))

      cond do
        column && column.sort_fn ->
          # Use custom sort function
          column.sort_fn.(query, direction)

        String.contains?(key, ".") ->
          # Handle dot notation for relationship sorting
          sort_expr = build_expression_sort(key)
          Ash.Query.sort(query, [{sort_expr, direction}])

        true ->
          # Standard attribute sorting
          Ash.Query.sort(query, [{String.to_atom(key), direction}])
      end
    end)
  end

  defp build_expression_sort(key) do
    # Convert "author.name" to expression sort
    parts = String.split(key, ".")

    case parts do
      [rel, field] ->
        # For now, create a simple expression - this may need adjustment based on Ash version
        {String.to_atom(rel), String.to_atom(field)}

      _ ->
        String.to_atom(key)
    end
  end

  defp toggle_sort_direction(current_sort, key) do
    case Enum.find(current_sort, fn {sort_key, _direction} -> sort_key == key end) do
      {^key, :asc} ->
        # Currently ascending, change to descending
        Enum.map(current_sort, fn
          {^key, :asc} -> {key, :desc}
          other -> other
        end)

      {^key, :desc} ->
        # Currently descending, remove sort
        Enum.reject(current_sort, fn {sort_key, _direction} -> sort_key == key end)

      nil ->
        # Not currently sorted, add ascending sort
        [{key, :asc} | current_sort]
    end
  end

  defp get_sort_direction(sort_by, key) do
    case Enum.find(sort_by, fn {sort_key, _direction} -> sort_key == key end) do
      {^key, direction} -> direction
      nil -> nil
    end
  end

  # This will be used when we implement actual Ash pagination
  # defp build_page_info_from_ash_page(page, current_page, page_size) do
  #   total_count = page.count || length(page.results)
  #   total_pages = max(1, ceil(total_count / page_size))
  #   start_index = (current_page - 1) * page_size + 1
  #   end_index = min(current_page * page_size, total_count)
  #
  #   %{
  #     current_page: current_page,
  #     total_pages: total_pages,
  #     total_count: total_count,
  #     has_next_page: page.more?,
  #     has_previous_page: current_page > 1,
  #     start_index: if(total_count > 0, do: start_index, else: 0),
  #     end_index: if(total_count > 0, do: end_index, else: 0)
  #   }
  # end

  defp build_page_info_from_list(results, current_page, page_size) do
    total_count = length(results)
    total_pages = max(1, ceil(total_count / page_size))
    start_index = (current_page - 1) * page_size + 1
    end_index = min(current_page * page_size, total_count)

    %{
      current_page: current_page,
      total_pages: total_pages,
      total_count: total_count,
      has_next_page: current_page < total_pages,
      has_previous_page: current_page > 1,
      start_index: if(total_count > 0, do: start_index, else: 0),
      end_index: if(total_count > 0, do: end_index, else: 0)
    }
  end

  defp build_error_page_info do
    %{
      current_page: 1,
      total_pages: 1,
      total_count: 0,
      has_next_page: false,
      has_previous_page: false,
      start_index: 0,
      end_index: 0
    }
  end

  defp parse_column_definition(slot) do
    %{
      key: slot.key,
      label: Map.get(slot, :label, to_string(slot.key)),
      sortable: Map.get(slot, :sortable, false),
      searchable: Map.get(slot, :searchable, false),
      filterable: Map.get(slot, :filterable, false),
      filter_type: Map.get(slot, :filter_type, :text),
      filter_options: Map.get(slot, :filter_options, []),
      filter_fn: Map.get(slot, :filter_fn),
      options: Map.get(slot, :options, []),
      display_field: Map.get(slot, :display_field),
      sort_fn: Map.get(slot, :sort_fn),
      search_fn: Map.get(slot, :search_fn),
      class: Map.get(slot, :class, ""),
      slot: slot
    }
  end

  defp merge_theme(custom_theme) do
    default_theme()
    |> Map.merge(custom_theme)
  end

  defp default_theme do
    %{
      container_class: "cinder-table-container",
      controls_class: "cinder-table-controls mb-4",
      table_wrapper_class: "cinder-table-wrapper overflow-x-auto",
      table_class: "cinder-table w-full border-collapse",
      thead_class: "cinder-table-head",
      tbody_class: "cinder-table-body",
      header_row_class: "cinder-table-header-row",
      row_class: "cinder-table-row border-b",
      th_class: "cinder-table-th px-4 py-2 text-left font-medium border-b",
      td_class: "cinder-table-td px-4 py-2",
      sort_indicator_class: "cinder-sort-indicator ml-1",
      loading_class: "cinder-table-loading text-center py-8 text-gray-500",
      empty_class: "cinder-table-empty text-center py-8 text-gray-500",
      pagination_wrapper_class: "cinder-pagination-wrapper mt-4",
      pagination_container_class: "cinder-pagination-container flex items-center justify-between",
      pagination_button_class:
        "cinder-pagination-button px-3 py-1 border rounded hover:bg-gray-100",
      pagination_info_class: "cinder-pagination-info text-sm text-gray-600",
      pagination_count_class: "cinder-pagination-count text-xs text-gray-500",
      # Sort icon customization
      sort_arrow_wrapper_class: "inline-block ml-1",
      sort_asc_icon_name: "hero-chevron-up",
      sort_asc_icon_class: "w-3 h-3 inline-block",
      sort_desc_icon_name: "hero-chevron-down",
      sort_desc_icon_class: "w-3 h-3 inline-block",
      sort_none_icon_name: "hero-chevron-up-down",
      sort_none_icon_class: "w-3 h-3 inline-block opacity-30",
      # Filter customization
      filter_container_class: "cinder-filter-container border rounded-lg p-4 mb-4 bg-gray-50",
      filter_header_class: "cinder-filter-header flex items-center justify-between mb-3",
      filter_title_class: "cinder-filter-title text-sm font-medium text-gray-700",
      filter_count_class: "cinder-filter-count text-xs text-gray-500",
      filter_clear_all_class: "cinder-filter-clear-all text-xs text-blue-600 hover:text-blue-800 underline",
      filter_inputs_class: "cinder-filter-inputs grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4",
      filter_input_wrapper_class: "cinder-filter-input-wrapper",
      filter_label_class: "cinder-filter-label block text-sm font-medium text-gray-700 mb-1",
      filter_placeholder_class: "cinder-filter-placeholder text-xs text-gray-400 italic p-2 border rounded",
      filter_text_input_class: "cinder-filter-text-input w-full px-3 py-2 border border-gray-300 rounded-md text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500",
      filter_select_input_class: "cinder-filter-select-input w-full px-3 py-2 border border-gray-300 rounded-md text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500",
      filter_clear_button_class: "cinder-filter-clear-button text-gray-400 hover:text-gray-600 text-sm font-medium px-2 py-1 rounded hover:bg-gray-100"
    }
  end
end
