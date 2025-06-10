defmodule Cinder.Table.LiveComponent do
  @moduledoc """
  LiveComponent for interactive data tables with Ash query execution.

  Handles state management, data loading, and pagination for the table component.
  """

  use Phoenix.LiveComponent

  @impl true
  def mount(socket) do
    {:ok, socket}
  end

  @impl true
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
    <div class={@theme.container_class}>
      <!-- Filters and Search will go here in later phases -->
      <div class={@theme.controls_class}>
        <!-- Placeholder for filters and search -->
      </div>
      
      <!-- Main table -->
      <div class={@theme.table_wrapper_class}>
        <table class={@theme.table_class}>
          <thead class={@theme.thead_class}>
            <tr class={@theme.header_row_class}>
              <th :for={column <- @columns} class={@theme.th_class}>
                {column.label}
                <span :if={column.sortable} class={@theme.sort_indicator_class}>
                  <!-- Sort arrows will be added in Phase 3 -->
                </span>
              </th>
            </tr>
          </thead>
          <tbody class={@theme.tbody_class}>
            <tr :if={@loading}>
              <td colspan={length(@columns)} class={@theme.loading_class}>
                Loading...
              </td>
            </tr>
            <tr :for={item <- @data} :if={not @loading} class={@theme.row_class}>
              <td :for={column <- @columns} class={@theme.td_class}>
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

  # Private functions

  defp assign_defaults(socket) do
    assigns = socket.assigns

    socket
    |> assign(:page_size, assigns[:page_size] || 25)
    |> assign(:current_page, assigns[:current_page] || 1)
    |> assign(:loading, false)
    |> assign(:data, [])
    |> assign(:sort_by, [])
    |> assign(:filters, %{})
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
      current_page: current_page
    } = socket.assigns

    socket
    |> assign(:loading, true)
    |> start_async(:load_data, fn ->
      # Build the query with pagination
      query =
        resource
        |> Ash.Query.for_read(:read, %{}, actor: current_user)
        |> apply_query_opts(query_opts)
        |> Ash.Query.limit(page_size)
        |> Ash.Query.offset((current_page - 1) * page_size)

      # Execute the query
      case Ash.read(query, actor: current_user) do
        {:ok, results} when is_list(results) ->
          {results, current_page, page_size}

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
        # TODO: Implement filter support in Phase 4
        query

      _other, query ->
        query
    end)
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
      options: Map.get(slot, :options, []),
      display_field: Map.get(slot, :display_field),
      sort_fn: Map.get(slot, :sort_fn),
      search_fn: Map.get(slot, :search_fn),
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
      pagination_count_class: "cinder-pagination-count text-xs text-gray-500"
    }
  end
end
