defmodule Cinder.Data.LiveComponent do
  @moduledoc """
  Shared LiveComponent for all Cinder data layouts (Table, List, etc.).

  This component handles all data management logic:
  - State management (filters, sorting, pagination)
  - Event handling (filter_change, toggle_sort, goto_page, etc.)
  - Async data loading
  - URL state synchronization

  The actual HTML rendering is delegated to a renderer module passed via
  the `renderer` assign. Each renderer implements a `render/1` function
  that receives the assigns and returns HEEx.
  """

  use Phoenix.LiveComponent
  require Ash.Query
  require Logger
  use Cinder.Messages

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
    # Force refresh of data
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
    # Delegate rendering to the renderer module
    assigns.renderer.render(assigns)
  end

  # ============================================================================
  # EVENT HANDLERS
  # ============================================================================

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
    updated_config = %{socket.assigns.page_size_config | selected_page_size: page_size}

    socket =
      socket
      |> assign(:page_size, page_size)
      |> assign(:page_size_config, updated_config)
      |> assign(:current_page, 1)
      |> notify_state_change()
      |> load_data()

    {:noreply, socket}
  end

  @impl true
  def handle_event("clear_filter", %{"key" => "search"}, socket) do
    socket =
      socket
      |> assign(:search_term, "")
      |> assign(:current_page, 1)
      |> load_data()
      |> notify_state_change()

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

    socket = notify_state_change(socket, new_filters)

    {:noreply, socket}
  end

  @impl true
  def handle_event("toggle_sort", %{"key" => key}, socket) do
    current_sort = socket.assigns.sort_by

    # Find the column to get its sort cycle configuration
    column = Enum.find(socket.assigns.col, &(&1.field == key))
    sort_cycle = if column, do: column.sort_cycle, else: nil

    new_sort = Cinder.QueryBuilder.toggle_sort_with_cycle(current_sort, key, sort_cycle)

    # Check if URL sync is enabled
    url_sync_enabled = !!socket.assigns[:on_state_change]

    socket =
      socket
      |> assign(:sort_by, new_sort)
      |> assign(:current_page, 1)
      |> assign(:user_has_interacted, true)

    socket =
      if url_sync_enabled do
        socket
      else
        load_data(socket)
      end

    notify_state_change(socket)

    {:noreply, socket}
  end

  @impl true
  def handle_event("refresh", _params, socket) do
    {:noreply, load_data(socket)}
  end

  @impl true
  def handle_event("clear_all_filters", _params, socket) do
    new_filters = Cinder.FilterManager.clear_all_filters(socket.assigns.filters)

    socket =
      socket
      |> assign(:filters, new_filters)
      |> assign(:current_page, 1)
      |> load_data()
      |> notify_state_change()

    {:noreply, socket}
  end

  @impl true
  def handle_event("filter_change", params, socket) do
    filter_columns = Map.get(socket.assigns, :filter_columns, socket.assigns.columns)

    new_filters =
      Map.get(params, "filters", %{})
      |> Cinder.FilterManager.params_to_filters(filter_columns)

    search_term =
      case Map.get(params, "search") do
        nil -> socket.assigns.search_term
        term -> term
      end

    url_sync_enabled = !!socket.assigns[:on_state_change]

    socket =
      socket
      |> assign(:filters, new_filters)
      |> assign(:search_term, search_term)
      |> assign(:current_page, 1)

    socket =
      if url_sync_enabled do
        socket
      else
        load_data(socket)
      end

    socket = notify_state_change(socket, new_filters)

    {:noreply, socket}
  end

  # ============================================================================
  # ASYNC HANDLERS
  # ============================================================================

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
    Logger.error(
      "Cinder query failed for #{inspect(socket.assigns.query)}: #{inspect(error)}",
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
    Logger.error(
      "Cinder query crashed for #{inspect(socket.assigns.query)}: #{inspect(reason)}",
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

  # ============================================================================
  # PRIVATE FUNCTIONS - State Notification
  # ============================================================================

  defp notify_state_change(socket, filters \\ nil) do
    filters = filters || socket.assigns.filters
    current_page = socket.assigns.current_page
    sort_by = socket.assigns.sort_by
    page_size_config = socket.assigns.page_size_config
    search_term = socket.assigns.search_term
    filter_field_names = socket.assigns.filter_field_names

    state = %{
      filters: filters,
      current_page: current_page,
      sort_by: sort_by,
      page_size: page_size_config.selected_page_size,
      default_page_size: page_size_config.default_page_size,
      search_term: search_term,
      filter_field_names: filter_field_names
    }

    Cinder.UrlManager.notify_state_change(socket, state)
  end

  # ============================================================================
  # PRIVATE FUNCTIONS - URL State Decoding
  # ============================================================================

  defp decode_url_state(socket, assigns) do
    if Map.has_key?(assigns, :url_raw_params) do
      raw_params = assigns.url_raw_params

      decoded_filters =
        Cinder.UrlManager.decode_filters(raw_params, socket.assigns.filter_columns)

      decoded_sorts =
        Cinder.UrlManager.decode_sort(Map.get(raw_params, "sort"), socket.assigns.columns)

      decoded_state = %{
        filters: decoded_filters,
        current_page: Cinder.UrlManager.decode_page(Map.get(raw_params, "page")),
        sort_by: decoded_sorts,
        page_size: Cinder.UrlManager.decode_page_size(Map.get(raw_params, "page_size")),
        search_term: Map.get(raw_params, "search", "")
      }

      final_sort_by =
        cond do
          decoded_state.sort_by != [] and not is_nil(decoded_state.sort_by) ->
            decoded_state.sort_by

          Map.get(socket.assigns, :user_has_interacted, false) ->
            []

          true ->
            socket.assigns.sort_by
        end

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
      |> assign(:search_term, decoded_state.search_term)
    else
      decode_url_state_legacy(socket, assigns)
    end
  end

  defp decode_url_state_legacy(socket, assigns) do
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
      decoded_state =
        Cinder.UrlManager.decode_state(
          url_params,
          socket.assigns.columns
        )

      final_sort_by =
        cond do
          decoded_state.sort_by != [] and not is_nil(decoded_state.sort_by) ->
            decoded_state.sort_by

          Map.get(socket.assigns, :user_has_interacted, false) ->
            []

          true ->
            socket.assigns.sort_by
        end

      socket
      |> assign(:filters, decoded_state.filters)
      |> assign(:current_page, decoded_state.current_page)
      |> assign(:sort_by, final_sort_by)
      |> assign(:search_term, decoded_state.search_term)
    end
  end

  # ============================================================================
  # PRIVATE FUNCTIONS - Initialization
  # ============================================================================

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

    selected_page_size =
      Map.get(socket.assigns, :page_size) || page_size_config.selected_page_size

    updated_page_size_config = %{page_size_config | selected_page_size: selected_page_size}

    socket
    |> assign(:page_size, selected_page_size)
    |> assign(:page_size_config, updated_page_size_config)
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

    filter_columns =
      case Map.get(socket.assigns, :filter_configs) do
        nil -> columns
        filter_configs -> filter_configs
      end

    filter_field_names =
      filter_columns
      |> Enum.filter(& &1.filterable)
      |> Enum.map(& &1.field)

    socket
    |> assign(:columns, columns)
    |> assign(:filter_columns, filter_columns)
    |> assign(:filter_field_names, filter_field_names)
  end

  defp extract_initial_sorts(assigns) do
    query = assigns[:query]
    columns = assigns[:col] || []

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

  # ============================================================================
  # PRIVATE FUNCTIONS - Data Loading
  # ============================================================================

  defp load_data_if_needed(socket) do
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
end
