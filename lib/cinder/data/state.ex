defmodule Cinder.Data.State do
  @moduledoc """
  Shared state management functions for Cinder data components.

  This module provides helper functions that can be used by both Table and List
  LiveComponents to handle common state operations like filtering, sorting,
  pagination, and data loading.

  These functions follow a consistent pattern: they take a socket and parameters,
  perform state updates, and return the updated socket. This allows each component
  to maintain its own event handlers while delegating the actual logic to shared code.
  """

  import Phoenix.Component, only: [assign: 3]
  require Logger
  require Phoenix.LiveView

  # ============================================================================
  # FILTER STATE MANAGEMENT
  # ============================================================================

  @doc """
  Updates filter state from filter_change event parameters.

  Returns the updated socket with new filters, search term, and current_page reset to 1.
  """
  def apply_filter_change(socket, params) do
    filter_columns = Map.get(socket.assigns, :filter_columns, socket.assigns.columns)

    new_filters =
      Map.get(params, "filters", %{})
      |> Cinder.FilterManager.params_to_filters(filter_columns)

    search_term =
      case Map.get(params, "search") do
        nil -> socket.assigns.search_term
        term -> term
      end

    socket
    |> assign(:filters, new_filters)
    |> assign(:search_term, search_term)
    |> assign(:current_page, 1)
  end

  @doc """
  Clears a specific filter by key.

  Returns the updated socket with the filter removed and current_page reset to 1.
  """
  def clear_filter(socket, key) do
    new_filters = Cinder.FilterManager.clear_filter(socket.assigns.filters, key)

    socket
    |> assign(:filters, new_filters)
    |> assign(:current_page, 1)
  end

  @doc """
  Clears the search term.

  Returns the updated socket with empty search_term and current_page reset to 1.
  """
  def clear_search(socket) do
    socket
    |> assign(:search_term, "")
    |> assign(:current_page, 1)
  end

  @doc """
  Clears all filters.

  Returns the updated socket with empty filters and current_page reset to 1.
  """
  def clear_all_filters(socket) do
    new_filters = Cinder.FilterManager.clear_all_filters(socket.assigns.filters)

    socket
    |> assign(:filters, new_filters)
    |> assign(:current_page, 1)
  end

  # ============================================================================
  # SORT STATE MANAGEMENT
  # ============================================================================

  @doc """
  Toggles sort direction for a field.

  Uses the column's sort_cycle configuration if available.
  Returns the updated socket with new sort_by, current_page reset to 1, and
  user_has_interacted set to true.
  """
  def toggle_sort(socket, field) do
    current_sort = socket.assigns.sort_by

    # Find the column to get its sort cycle configuration
    column = Enum.find(socket.assigns.col, &(&1.field == field))
    sort_cycle = if column, do: column.sort_cycle, else: nil

    new_sort = Cinder.QueryBuilder.toggle_sort_with_cycle(current_sort, field, sort_cycle)

    socket
    |> assign(:sort_by, new_sort)
    |> assign(:current_page, 1)
    |> assign(:user_has_interacted, true)
  end

  # ============================================================================
  # PAGINATION STATE MANAGEMENT
  # ============================================================================

  @doc """
  Updates the current page.

  Accepts page as string (from event params) or integer.
  """
  def goto_page(socket, page) when is_binary(page) do
    goto_page(socket, String.to_integer(page))
  end

  def goto_page(socket, page) when is_integer(page) do
    assign(socket, :current_page, page)
  end

  @doc """
  Updates the page size.

  Accepts page_size as string (from event params) or integer.
  Also updates the page_size_config and resets current_page to 1.
  """
  def change_page_size(socket, page_size) when is_binary(page_size) do
    change_page_size(socket, String.to_integer(page_size))
  end

  def change_page_size(socket, page_size) when is_integer(page_size) do
    updated_config = %{socket.assigns.page_size_config | selected_page_size: page_size}

    socket
    |> assign(:page_size, page_size)
    |> assign(:page_size_config, updated_config)
    |> assign(:current_page, 1)
  end

  # ============================================================================
  # DATA LOADING
  # ============================================================================

  @doc """
  Initiates async data loading.

  Sets loading to true and starts an async task to build and execute the query.
  Returns the socket with the async task started.
  """
  def load_data(socket) do
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

    # Capture resource to avoid socket copying in async function
    resource_var = resource

    socket
    |> assign(:loading, true)
    |> Phoenix.LiveView.start_async(:load_data, fn ->
      Cinder.QueryBuilder.build_and_execute(resource_var, options)
    end)
  end

  @doc """
  Handles successful async data load result.

  Updates the socket with the loaded data and page info, sets loading to false.
  """
  def handle_load_success(socket, results, page_info) do
    socket
    |> assign(:loading, false)
    |> assign(:data, results)
    |> assign(:page_info, page_info)
  end

  @doc """
  Handles failed async data load result.

  Logs the error and updates the socket with empty data.
  """
  def handle_load_error(socket, error) do
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

    socket
    |> assign(:loading, false)
    |> assign(:data, [])
    |> assign(:page_info, Cinder.QueryBuilder.build_error_page_info())
  end

  @doc """
  Handles crashed async data load.

  Logs the crash reason and updates the socket with empty data.
  """
  def handle_load_crash(socket, reason) do
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

    socket
    |> assign(:loading, false)
    |> assign(:data, [])
    |> assign(:page_info, Cinder.QueryBuilder.build_error_page_info())
  end

  # ============================================================================
  # URL SYNC HELPERS
  # ============================================================================

  @doc """
  Checks if URL sync is enabled for the component.
  """
  def url_sync_enabled?(socket) do
    !!socket.assigns[:on_state_change]
  end

  @doc """
  Conditionally loads data based on URL sync status.

  When URL sync is enabled, data loading is deferred to handle_params.
  When URL sync is disabled, data is loaded immediately.
  """
  def maybe_load_data(socket) do
    if url_sync_enabled?(socket) do
      socket
    else
      load_data(socket)
    end
  end

  # ============================================================================
  # STATE NOTIFICATION
  # ============================================================================

  @doc """
  Notifies parent LiveView about state changes for URL synchronization.

  Builds a state map and delegates to UrlManager.
  """
  def notify_state_change(socket, filters \\ nil) do
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
  # URL STATE DECODING
  # ============================================================================

  @doc """
  Decodes URL state from URL parameters and updates socket assigns.
  """
  def decode_url_state(socket, assigns) do
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
  # INITIALIZATION
  # ============================================================================

  @doc """
  Assigns default values to socket for data component state.
  """
  def assign_defaults(socket) do
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

  @doc """
  Assigns column definitions from col slots and computes filter metadata.
  """
  def assign_column_definitions(socket) do
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

  @doc """
  Extracts initial sort configuration from query if present.
  """
  def extract_initial_sorts(assigns) do
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
end
