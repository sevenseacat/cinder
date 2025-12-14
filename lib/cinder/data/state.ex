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
end
