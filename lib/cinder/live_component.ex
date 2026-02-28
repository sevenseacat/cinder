defmodule Cinder.LiveComponent do
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

  def update(%{__update_item__: {id, update_fn}}, socket) do
    id_field = socket.assigns[:id_field] || :id

    updated_data =
      Enum.map(socket.assigns.data || [], fn item ->
        if Map.get(item, id_field) == id, do: update_fn.(item), else: item
      end)

    {:ok, assign(socket, :data, updated_data)}
  end

  def update(%{__update_items__: {ids, update_fn}}, socket) do
    id_field = socket.assigns[:id_field] || :id
    id_set = MapSet.new(ids)

    updated_data =
      Enum.map(socket.assigns.data || [], fn item ->
        if Map.get(item, id_field) in id_set, do: update_fn.(item), else: item
      end)

    {:ok, assign(socket, :data, updated_data)}
  end

  # Single item update - raw item passed (has id field)
  def update(%{__update_item_if_visible__: {%{} = raw_item, update_fn}}, socket) do
    id_field = socket.assigns[:id_field] || :id
    id = Map.get(raw_item, id_field)
    do_update_item_if_visible(socket, id, raw_item, update_fn, id_field)
  end

  # Single item update - just ID passed
  def update(%{__update_item_if_visible__: {id, update_fn}}, socket) do
    id_field = socket.assigns[:id_field] || :id
    do_update_item_if_visible(socket, id, nil, update_fn, id_field)
  end

  # Single raw item passed (not in a list)
  def update(%{__update_items_if_visible__: {%{} = item, update_fn}}, socket) do
    id_field = socket.assigns[:id_field] || :id
    items_by_id = %{Map.get(item, id_field) => item}
    do_update_items_if_visible(socket, items_by_id, update_fn, id_field)
  end

  # List of raw items passed
  def update(%{__update_items_if_visible__: {[%{} | _] = items, update_fn}}, socket) do
    id_field = socket.assigns[:id_field] || :id
    items_by_id = Map.new(items, &{Map.get(&1, id_field), &1})
    do_update_items_if_visible(socket, items_by_id, update_fn, id_field)
  end

  # List of IDs passed (use old table data)
  def update(%{__update_items_if_visible__: {ids, update_fn}}, socket) when is_list(ids) do
    id_field = socket.assigns[:id_field] || :id
    do_update_items_if_visible(socket, nil, ids, update_fn, id_field)
  end

  def update(assigns, socket) do
    prev_state = data_state(socket.assigns)

    socket =
      socket
      |> assign(assigns)
      |> assign_defaults()
      |> assign_column_definitions()
      |> decode_url_state(assigns)
      |> load_data_if_needed(prev_state)

    {:ok, socket}
  end

  defp do_update_item_if_visible(socket, id, raw_item, update_fn, id_field) do
    data = socket.assigns.data || []

    case Enum.find(data, &(Map.get(&1, id_field) == id)) do
      nil ->
        {:ok, socket}

      old_item ->
        input = raw_item || old_item
        updated = update_fn.(input)
        updated_data = Enum.map(data, &if(Map.get(&1, id_field) == id, do: updated, else: &1))
        {:ok, assign(socket, :data, updated_data)}
    end
  end

  # When raw items provided as map
  defp do_update_items_if_visible(socket, items_by_id, update_fn, id_field) do
    do_update_items_if_visible(socket, items_by_id, Map.keys(items_by_id), update_fn, id_field)
  end

  defp do_update_items_if_visible(socket, items_by_id, ids, update_fn, id_field) do
    data = socket.assigns.data || []
    id_set = MapSet.new(ids)
    visible_ids = data |> Enum.map(&Map.get(&1, id_field)) |> MapSet.new()
    ids_to_update = MapSet.intersection(id_set, visible_ids)

    if MapSet.size(ids_to_update) == 0 do
      {:ok, socket}
    else
      input_items = get_input_items(data, items_by_id, ids_to_update, id_field)
      updated_by_id = update_fn.(input_items) |> to_map_by_id(id_field)

      updated_data =
        Enum.map(data, fn item ->
          id = Map.get(item, id_field)
          Map.get(updated_by_id, id, item)
        end)

      {:ok, assign(socket, :data, updated_data)}
    end
  end

  # Get input items from raw data if provided, otherwise from table data
  defp get_input_items(_data, items_by_id, ids_to_update, _id_field) when is_map(items_by_id) do
    ids_to_update |> Enum.map(&items_by_id[&1]) |> Enum.filter(& &1)
  end

  defp get_input_items(data, nil, ids_to_update, id_field) do
    Enum.filter(data, &(Map.get(&1, id_field) in ids_to_update))
  end

  # Normalize function return to map
  defp to_map_by_id(items, id_field) when is_list(items) do
    Map.new(items, &{Map.get(&1, id_field), &1})
  end

  defp to_map_by_id(items, _id_field) when is_map(items), do: items

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
    # Only works in offset pagination mode
    if socket.assigns.pagination_mode == :offset do
      page = String.to_integer(page)

      socket =
        socket
        |> assign(:current_page, page)
        |> notify_state_change()
        |> load_data()

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  # Keyset pagination: Navigate to next page
  @impl true
  def handle_event("next_page", _params, socket) do
    if socket.assigns.pagination_mode == :keyset do
      socket =
        socket
        |> assign(:after_keyset, socket.assigns.last_keyset)
        |> assign(:before_keyset, nil)
        |> notify_state_change()
        |> load_data()

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  # Keyset pagination: Navigate to previous page
  @impl true
  def handle_event("prev_page", _params, socket) do
    if socket.assigns.pagination_mode == :keyset do
      socket =
        socket
        |> assign(:before_keyset, socket.assigns.first_keyset)
        |> assign(:after_keyset, nil)
        |> notify_state_change()
        |> load_data()

      {:noreply, socket}
    else
      {:noreply, socket}
    end
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
      # Clear keyset cursors to restart from beginning when page size changes
      |> assign(:after_keyset, nil)
      |> assign(:before_keyset, nil)
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
      |> assign(:after_keyset, nil)
      |> assign(:before_keyset, nil)
      |> load_data()
      |> notify_state_change()

    {:noreply, socket}
  end

  @impl true
  def handle_event("clear_filter", %{"key" => key}, socket) do
    new_filters = Cinder.FilterManager.clear_filter(socket.assigns.filters, key)

    # Also clear the autocomplete search term for this field
    raw_filter_params = Map.get(socket.assigns, :raw_filter_params, %{})
    autocomplete_search_key = "#{key}_autocomplete_search"
    raw_filter_params = Map.delete(raw_filter_params, autocomplete_search_key)

    socket =
      socket
      |> assign(:filters, new_filters)
      |> assign(:raw_filter_params, raw_filter_params)
      |> assign(:current_page, 1)
      |> assign(:after_keyset, nil)
      |> assign(:before_keyset, nil)
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

    new_sort =
      Cinder.QueryBuilder.toggle_sort_with_cycle(
        current_sort,
        key,
        sort_cycle,
        socket.assigns.sort_mode
      )

    # Check if URL sync is enabled
    url_sync_enabled = !!socket.assigns[:on_state_change]

    socket =
      socket
      |> assign(:sort_by, new_sort)
      |> assign(:current_page, 1)
      |> assign(:after_keyset, nil)
      |> assign(:before_keyset, nil)
      |> assign(:user_has_interacted, true)

    socket =
      if url_sync_enabled do
        assign(socket, :__reload_requested__, true)
      else
        load_data(socket)
      end

    socket = notify_state_change(socket)

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
      |> assign(:after_keyset, nil)
      |> assign(:before_keyset, nil)
      |> load_data()
      |> notify_state_change()

    {:noreply, socket}
  end

  # ============================================================================
  # SELECTION EVENT HANDLERS
  # ============================================================================

  @impl true
  def handle_event("toggle_select", %{"id" => id}, socket) do
    selected_ids = socket.assigns.selected_ids

    new_selected =
      if MapSet.member?(selected_ids, id) do
        MapSet.delete(selected_ids, id)
      else
        MapSet.put(selected_ids, id)
      end

    socket =
      socket
      |> assign(:selected_ids, new_selected)
      |> notify_selection_change(:toggle)

    {:noreply, socket}
  end

  @impl true
  def handle_event("toggle_select_all_page", _params, socket) do
    id_field = socket.assigns[:id_field] || :id
    page_ids = socket.assigns.data |> Enum.map(&to_string(Map.get(&1, id_field))) |> MapSet.new()
    all_selected? = MapSet.subset?(page_ids, socket.assigns.selected_ids)

    new_selected =
      if all_selected? do
        MapSet.difference(socket.assigns.selected_ids, page_ids)
      else
        MapSet.union(socket.assigns.selected_ids, page_ids)
      end

    socket =
      socket
      |> assign(:selected_ids, new_selected)
      |> notify_selection_change(:select_all)

    {:noreply, socket}
  end

  @impl true
  def handle_event("clear_selection", _params, socket) do
    socket =
      socket
      |> assign(:selected_ids, MapSet.new())
      |> notify_selection_change(:clear)

    {:noreply, socket}
  end

  # ============================================================================
  # BULK ACTION EVENT HANDLERS
  # ============================================================================

  @impl true
  def handle_event("bulk_action_execute", %{"index" => index}, socket) do
    slots = socket.assigns[:bulk_action_slots] || []
    slot = Enum.at(slots, index)

    if slot do
      execute_bulk_action(slot, socket)
    else
      Logger.warning("Cinder: Bulk action slot not found at index #{index}")
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("filter_change", params, socket) do
    query_columns = Map.get(socket.assigns, :query_columns, socket.assigns.columns)

    raw_filter_params = Map.get(params, "filters", %{})

    new_filters =
      raw_filter_params
      |> Cinder.FilterManager.params_to_filters(query_columns)

    search_term =
      case Map.get(params, "search") do
        nil -> socket.assigns.search_term
        term -> term
      end

    url_sync_enabled = !!socket.assigns[:on_state_change]

    # Only reset pagination when filters or search actually change
    filters_changed = new_filters != socket.assigns.filters
    search_changed = search_term != socket.assigns.search_term

    socket =
      socket
      |> assign(:filters, new_filters)
      |> assign(:raw_filter_params, raw_filter_params)
      |> assign(:search_term, search_term)

    socket =
      if filters_changed or search_changed do
        socket
        |> assign(:current_page, 1)
        |> assign(:after_keyset, nil)
        |> assign(:before_keyset, nil)
      else
        socket
      end

    socket =
      if url_sync_enabled do
        assign(socket, :__reload_requested__, true)
      else
        load_data(socket)
      end

    socket = notify_state_change(socket, new_filters)

    {:noreply, socket}
  end

  # ============================================================================
  # BULK ACTION HELPERS
  # ============================================================================

  defp execute_bulk_action(slot, socket) do
    action = slot[:action]
    selected_ids = socket.assigns.selected_ids |> MapSet.to_list()

    if selected_ids == [] do
      {:noreply, socket}
    else
      resource = extract_resource(socket.assigns)

      if resource do
        result =
          Cinder.BulkActionExecutor.execute(action,
            resource: resource,
            ids: selected_ids,
            id_field: socket.assigns[:id_field] || :id,
            actor: socket.assigns[:actor],
            tenant: socket.assigns[:tenant],
            action_opts: slot[:action_opts] || []
          )

        handle_bulk_action_result(result, slot, socket)
      else
        Logger.error("Cinder: No resource configured for bulk action")
        {:noreply, socket}
      end
    end
  end

  defp handle_bulk_action_result(result, slot, socket) do
    case result do
      {:ok, bulk_result} ->
        handle_bulk_action_success(slot, socket, bulk_result)

      {:error, reason} ->
        handle_bulk_action_error(slot, socket, reason)
    end
  end

  defp handle_bulk_action_success(slot, socket, result) do
    selected_count = MapSet.size(socket.assigns.selected_ids)

    socket =
      socket
      |> assign(:selected_ids, MapSet.new())
      |> notify_selection_change(:clear)
      |> load_data()

    if event_name = slot[:on_success] do
      send(
        self(),
        {event_name,
         %{
           component_id: socket.assigns.id,
           action: slot[:action],
           count: selected_count,
           result: result
         }}
      )
    end

    {:noreply, socket}
  end

  defp handle_bulk_action_error(slot, socket, reason) do
    Logger.error("Cinder: Bulk action failed: #{inspect(reason)}")

    if event_name = slot[:on_error] do
      send(
        self(),
        {event_name,
         %{
           component_id: socket.assigns.id,
           action: slot[:action],
           reason: reason
         }}
      )
    end

    {:noreply, socket}
  end

  defp extract_resource(assigns) do
    case assigns[:query] do
      %Ash.Query{resource: resource} -> resource
      resource when is_atom(resource) and not is_nil(resource) -> resource
      _ -> nil
    end
  end

  defp notify_selection_change(socket, action) do
    if event_name = socket.assigns[:on_selection_change] do
      payload = %{
        component_id: socket.assigns.id,
        selected_ids: socket.assigns.selected_ids,
        selected_count: MapSet.size(socket.assigns.selected_ids),
        action: action
      }

      send(self(), {event_name, payload})
    end

    socket
  end

  # ============================================================================
  # ASYNC HANDLERS
  # ============================================================================

  @impl true
  def handle_async(:load_data, {:ok, {:ok, page}}, socket) do
    socket =
      socket
      |> assign(:loading, false)
      |> assign(:error, false)
      |> assign(:data, page.results)
      |> assign(:page, page)
      # Update keyset cursors for navigation (only relevant in keyset mode)
      |> maybe_update_keyset_cursors(page)

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
      |> assign(:error, true)
      |> assign(:data, [])
      |> assign(:page, nil)

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
      |> assign(:error, true)
      |> assign(:data, [])
      |> assign(:page, nil)

    {:noreply, socket}
  end

  defp maybe_update_keyset_cursors(socket, %Ash.Page.Keyset{} = page) do
    results = page.results
    # Extract keysets from first and last results for navigation
    first_keyset = get_keyset_from_result(List.first(results))
    last_keyset = get_keyset_from_result(List.last(results))

    socket
    |> assign(:first_keyset, first_keyset)
    |> assign(:last_keyset, last_keyset)
  end

  defp maybe_update_keyset_cursors(socket, _page), do: socket

  defp get_keyset_from_result(nil), do: nil

  defp get_keyset_from_result(result) do
    case result do
      %{__metadata__: %{keyset: keyset}} -> keyset
      _ -> nil
    end
  end

  defp maybe_put_cursor(state, _key, nil), do: state
  defp maybe_put_cursor(state, key, cursor), do: Map.put(state, key, cursor)

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
    pagination_mode = socket.assigns.pagination_mode

    state = %{
      filters: filters,
      current_page: current_page,
      sort_by: sort_by,
      page_size: page_size_config.selected_page_size,
      default_page_size: page_size_config.default_page_size,
      search_term: search_term,
      filter_field_names: filter_field_names
    }

    # For keyset pagination, include after/before cursors for URL persistence
    state =
      if pagination_mode == :keyset do
        state
        |> maybe_put_cursor(:after, socket.assigns.after_keyset)
        |> maybe_put_cursor(:before, socket.assigns.before_keyset)
      else
        state
      end

    Cinder.UrlManager.notify_state_change(socket, state)
  end

  # ============================================================================
  # PRIVATE FUNCTIONS - URL State Decoding
  # ============================================================================

  defp get_raw_url_params(url_state) when is_map(url_state) do
    Map.get(url_state, :filters, %{})
  end

  defp get_raw_url_params(_), do: %{}

  defp decode_url_state(socket, %{url_state: url_state}) do
    raw_params = get_raw_url_params(url_state)

    decoded_filters =
      Cinder.UrlManager.decode_filters(raw_params, socket.assigns.query_columns)

    decoded_sorts =
      Cinder.UrlManager.decode_sort(Map.get(raw_params, "sort"), socket.assigns.columns)

    decoded_search_term = Cinder.UrlManager.get_search(url_state)

    decoded_state = %{
      filters: decoded_filters,
      current_page: Cinder.UrlManager.decode_page(Map.get(raw_params, "page")),
      sort_by: decoded_sorts,
      page_size: Cinder.UrlManager.decode_page_size(Map.get(raw_params, "page_size")),
      after: Cinder.UrlManager.decode_cursor(Map.get(raw_params, "after")),
      before: Cinder.UrlManager.decode_cursor(Map.get(raw_params, "before"))
    }

    final_sort_by =
      cond do
        decoded_state.sort_by != [] ->
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

    # Handle keyset cursors from URL (after/before params)
    updated_socket =
      if socket.assigns.pagination_mode == :keyset do
        updated_socket
        |> maybe_assign_cursor(:after_keyset, decoded_state.after)
        |> maybe_assign_cursor(:before_keyset, decoded_state.before)
      else
        updated_socket
      end

    updated_socket
    |> assign(:filters, decoded_state.filters)
    |> assign(:current_page, decoded_state.current_page)
    |> assign(:sort_by, final_sort_by)
    |> assign(:search_term, decoded_search_term)
  end

  defp decode_url_state(socket, assigns), do: decode_url_state_legacy(socket, assigns)

  defp maybe_assign_cursor(socket, _key, nil), do: socket
  defp maybe_assign_cursor(socket, key, cursor), do: assign(socket, key, cursor)

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
          decoded_state.sort_by != [] ->
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

    # Use existing page_size_config if already parsed by Collection,
    # otherwise parse the global default
    page_size_config =
      assigns[:page_size_config] || Cinder.PageSize.parse(nil)

    selected_page_size =
      Map.get(socket.assigns, :page_size) || page_size_config.selected_page_size

    updated_page_size_config = %{page_size_config | selected_page_size: selected_page_size}

    # Determine pagination mode (default to :offset for backwards compatibility)
    pagination_mode = assigns[:pagination_mode] || :offset

    socket
    |> assign(:page_size, selected_page_size)
    |> assign(:page_size_config, updated_page_size_config)
    |> assign(:current_page, assigns[:current_page] || 1)
    |> assign(:loading, false)
    |> assign(:error, assigns[:error] || false)
    |> assign(:data, assigns[:data] || [])
    |> assign(:sort_by, assigns[:sort_by] || extract_initial_sorts(assigns))
    |> assign(:filters, assigns[:filters] || %{})
    |> assign(:search_term, assigns[:search_term] || "")
    |> assign(:theme, assigns[:theme] || Cinder.Theme.default())
    |> assign(:query_opts, assigns[:query_opts] || [])
    |> assign_new(:action, fn -> nil end)
    |> assign_new(:page, fn -> nil end)
    |> assign(:user_has_interacted, Map.get(socket.assigns, :user_has_interacted, false))
    # Keyset pagination state
    |> assign(:pagination_mode, pagination_mode)
    |> assign(:after_keyset, assigns[:after_keyset])
    |> assign(:before_keyset, assigns[:before_keyset])
    |> assign(:first_keyset, assigns[:first_keyset])
    |> assign(:last_keyset, assigns[:last_keyset])
    # Selection state
    |> assign(:selectable, assigns[:selectable] || false)
    |> assign_new(:selected_ids, fn -> MapSet.new() end)
    |> assign(:on_selection_change, assigns[:on_selection_change])
    |> assign(:id_field, assigns[:id_field] || :id)
    |> assign(:sort_mode, assigns[:sort_mode] || :additive)
    # Bulk actions
    |> assign_new(:bulk_action_slots, fn -> [] end)
  end

  defp assign_column_definitions(socket) do
    # Display columns - already processed by Collection, use directly
    columns = socket.assigns.col

    # Query columns - columns used for filtering and searching
    # Includes filterable columns, searchable columns, and filter-only slots
    query_columns =
      case Map.get(socket.assigns, :query_columns) do
        nil -> columns
        qc -> qc
      end

    # Field names of filterable columns (for URL state management)
    filter_field_names =
      query_columns
      |> Enum.filter(& &1.filterable)
      |> Enum.map(& &1.field)

    socket
    |> assign(:columns, columns)
    |> assign(:query_columns, query_columns)
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

  # Keys that affect data queries - changes to these trigger a reload.
  # Note: actor, tenant, and scope are normalized separately to avoid
  # false positives from Ecto struct metadata differences.
  @data_keys ~w(filters sort_by current_page page_size search_term query query_opts after_keyset before_keyset)a

  defp data_state(assigns) do
    base_state = Map.take(assigns, @data_keys)

    Map.merge(base_state, %{
      actor_id: normalize_auth(assigns[:actor]),
      tenant_id: normalize_auth(assigns[:tenant]),
      scope_id: normalize_scope(assigns[:scope])
    })
  end

  defp normalize_auth(nil), do: nil
  defp normalize_auth(value) when is_binary(value) or is_atom(value), do: value
  defp normalize_auth(%{id: id}), do: id
  defp normalize_auth(value), do: value

  # Normalize scope by extracting IDs from nested structs
  defp normalize_scope(nil), do: nil

  defp normalize_scope(%_{} = scope) do
    scope
    |> Map.from_struct()
    |> normalize_scope()
  end

  defp normalize_scope(scope) when is_map(scope) do
    scope
    |> Enum.map(fn
      {key, %{id: id}} -> {key, id}
      {key, value} when is_map(value) -> {key, normalize_scope(value)}
      {key, value} -> {key, value}
    end)
    |> Enum.sort()
  end

  defp normalize_scope(value), do: value

  defp load_data_if_needed(socket, prev) do
    first_load = socket.assigns[:page] == nil
    curr = data_state(socket.assigns)
    state_changed = curr != prev
    reload_requested = socket.assigns[:__reload_requested__] == true
    socket = assign(socket, :__reload_requested__, false)

    if first_load or state_changed or reload_requested do
      load_data(socket)
    else
      socket
    end
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
      search_term: search_term,
      pagination_mode: pagination_mode,
      after_keyset: after_keyset,
      before_keyset: before_keyset
    } = socket.assigns

    scope = Map.get(socket.assigns, :scope)

    resource_var = resource

    # Use query_columns for filtering and searching (includes filter-only slots)
    query_columns = Map.get(socket.assigns, :query_columns, columns)

    action = Map.get(socket.assigns, :action)

    options = [
      actor: actor,
      tenant: tenant,
      scope: scope,
      action: action,
      query_opts: query_opts,
      filters: filters,
      sort_by: sort_by,
      page_size: page_size,
      current_page: current_page,
      columns: query_columns,
      search_term: search_term,
      search_fn: socket.assigns.search_fn,
      pagination_configured: socket.assigns.page_size_config.configurable || page_size != 25,
      # Keyset pagination options
      pagination_mode: pagination_mode,
      after_keyset: after_keyset,
      before_keyset: before_keyset
    ]

    socket
    |> assign(:loading, true)
    |> assign(:error, false)
    |> start_async(:load_data, fn ->
      Cinder.QueryBuilder.build_and_execute(resource_var, options)
    end)
  end
end
