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
      |> decode_url_state(assigns)
      |> load_data_if_needed()

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class={[@theme.container_class, "relative"]}>
      <!-- Filter Controls -->
      <div class={@theme.controls_class}>
        <Cinder.FilterManager.render_filter_controls
          columns={@columns}
          filters={@filters}
          theme={@theme}
          target={@myself}
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
                       <.sort_arrow sort_direction={Cinder.QueryBuilder.get_sort_direction(@sort_by, column.key)} theme={@theme} loading={@loading} />
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
      |> Enum.map(&parse_column_definition(&1, resource))

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

    options = [
      actor: current_user,
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
    socket =
      socket
      |> assign(:loading, false)
      |> assign(:data, [])
      |> assign(:page_info, Cinder.QueryBuilder.build_error_page_info())
      |> put_flash(:error, "Failed to load data: #{inspect(error)}")

    {:noreply, socket}
  end

  @impl true
  def handle_async(:load_data, {:exit, reason}, socket) do
    socket =
      socket
      |> assign(:loading, false)
      |> assign(:data, [])
      |> assign(:page_info, Cinder.QueryBuilder.build_error_page_info())
      |> put_flash(:error, "Failed to load data: #{inspect(reason)}")

    {:noreply, socket}
  end

  defp parse_column_definition(slot, resource) do
    # Infer filter type and options from Ash resource if not explicitly set
    inferred = Cinder.FilterManager.infer_filter_config(slot.key, resource, slot)

    %{
      key: slot.key,
      label: Map.get(slot, :label, to_string(slot.key)),
      sortable: Map.get(slot, :sortable, false),
      searchable: Map.get(slot, :searchable, false),
      filterable: Map.get(slot, :filterable, false),
      filter_type: Map.get(slot, :filter_type, inferred.filter_type),
      filter_options: Map.get(slot, :filter_options, inferred.filter_options),
      filter_fn: Map.get(slot, :filter_fn),
      options: Map.get(slot, :options, []),
      display_field: Map.get(slot, :display_field),
      sort_fn: Map.get(slot, :sort_fn),
      search_fn: Map.get(slot, :search_fn),
      class: Map.get(slot, :class, ""),
      slot: slot
    }
  end
end
