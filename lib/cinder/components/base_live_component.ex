defmodule Cinder.Components.BaseLiveComponent do
  @moduledoc """
  Base module for shared LiveComponent functionality between Table and Cards components.
  
  This module contains all the common event handlers, state management, and data loading
  logic that is shared between the Table and Cards LiveComponents.
  """

  defmacro __using__(_opts) do
    quote do
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

      def update(%{refresh: true} = assigns, socket) do
        # Force refresh of component data
        socket =
          socket
          |> assign(Map.drop(assigns, [:refresh]))
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

      # Event Handlers - Shared between Table and Cards

      @impl true
      def handle_event("filter_change", %{"filters" => filter_params}, socket) do
        # Use FilterManager to process filters with proper column definitions
        new_filters = Cinder.FilterManager.process_filter_params(filter_params, socket.assigns.columns)
        
        socket = notify_state_change(socket, new_filters)
        {:noreply, socket}
      end

      def handle_event("clear_filter", %{"key" => key}, socket) do
        filters = Map.delete(socket.assigns.filters, key)
        
        socket =
          socket
          |> assign(:filters, filters)
          |> assign(:current_page, 1)
          |> load_data()
        
        socket = notify_state_change(socket, filters)
        {:noreply, socket}
      end

      def handle_event("clear_filter", %{"field" => field}, socket) do
        filters = Map.delete(socket.assigns.filters, field)
        
        socket =
          socket
          |> assign(:filters, filters)
          |> assign(:current_page, 1)
          |> load_data()
        
        socket = notify_state_change(socket, filters)
        {:noreply, socket}
      end

      def handle_event("clear_all_filters", _params, socket) do
        socket =
          socket
          |> assign(:filters, %{})
          |> assign(:current_page, 1)
          |> load_data()
          |> notify_state_change()
        
        {:noreply, socket}
      end

      def handle_event("toggle_sort", %{"key" => field}, socket) do
        new_sort_by = Cinder.QueryBuilder.toggle_sort_direction(socket.assigns.sort_by, field)
        
        socket =
          socket
          |> assign(:sort_by, new_sort_by)
          |> assign(:current_page, 1)
          |> load_data()
          |> notify_state_change()
        
        {:noreply, socket}
      end

      def handle_event("goto_page", %{"page" => page}, socket) do
        page = String.to_integer(page)
        
        socket =
          socket
          |> assign(:current_page, page)
          |> load_data()
          |> notify_state_change()
        
        {:noreply, socket}
      end

      def handle_event("refresh", _params, socket) do
        {:noreply, load_data(socket)}
      end

      def handle_event(
            "live_select_change",
            %{"text" => text, "id" => live_component_id, "field" => field},
            socket
          ) do
        send_update(LiveSelect.Component, id: live_component_id, options: [])
        {:noreply, socket}
      end

      # Async Handlers - Shared between Table and Cards

      @impl true
      def handle_async(:load_data, {:ok, {:ok, {results, page_info}}}, socket) do
        socket =
          socket
          |> assign(:loading, false)
          |> assign(:data, results)
          |> assign(:page_info, page_info)

        {:noreply, socket}
      end

      def handle_async(:load_data, {:ok, {:error, error}}, socket) do
        # Log error for developer debugging
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

      def handle_async(:load_data, {:exit, reason}, socket) do
        # Log error for developer debugging  
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

      # Private Helper Functions - Shared between Table and Cards

      defp assign_defaults(socket) do
        socket
        |> assign_new(:loading, fn -> false end)
        |> assign_new(:data, fn -> [] end)
        |> assign_new(:page_info, fn -> %{current_page: 1, total_pages: 1, total_count: 0, start_index: 0, end_index: 0} end)
        |> assign_new(:filters, fn -> %{} end)
        |> assign_new(:sort_by, fn -> [] end)
        |> assign_new(:current_page, fn -> 1 end)
      end

      defp assign_column_definitions(socket) do
        # Extract columns from props (Cards) or col (Table) slots
        columns = get_columns_from_slots(socket.assigns)
        assign(socket, :columns, columns)
      end

      defp extract_initial_sorts(assigns) do
        # Get sorts from URL state first, then from query, then empty
        url_sorts = Map.get(assigns, :url_sort, [])
        
        if not Enum.empty?(url_sorts) do
          url_sorts
        else
          # Extract sorts from query if no URL sorts
          query_sorts = 
            case assigns.query do
              %Ash.Query{sort: sorts} when sorts != [] ->
                Enum.map(sorts, fn 
                  {field, direction} when is_atom(field) -> {to_string(field), direction}
                  {field, direction} when is_binary(field) -> {field, direction}
                  field when is_atom(field) -> {to_string(field), :asc}
                  field when is_binary(field) -> {field, :asc}
                end)
              _ -> []
            end
          
          query_sorts
        end
      end

      defp decode_url_state(socket, assigns) do
        url_state = Map.get(assigns, :url_state)
        
        if is_map(url_state) and map_size(url_state) > 0 do
          # Extract state from URL parameters  
          filters = Map.get(assigns, :url_filters, %{})
          page = Map.get(assigns, :url_page, 1)
          sort_by = Map.get(assigns, :url_sort, [])
          
          socket
          |> assign(:filters, filters)
          |> assign(:current_page, page)
          |> assign(:sort_by, sort_by)
        else
          # Use initial sorts from query or props
          initial_sorts = extract_initial_sorts(assigns)
          assign(socket, :sort_by, initial_sorts)
        end
      end

      defp load_data_if_needed(socket) do
        if socket.assigns.data == [] do
          load_data(socket)
        else
          socket
        end
      end

      defp load_data(socket) do
        %{
          query: query,
          actor: actor,
          tenant: tenant,
          page_size: page_size,
          current_page: current_page,
          sort_by: sort_by,
          filters: filters,
          columns: columns
        } = socket.assigns

        # Extract variables to avoid socket copying in async function
        resource_var = query

        options = [
          actor: actor,
          tenant: tenant,
          query_opts: socket.assigns[:query_opts] || [],
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

      defp build_page_range(page_info) do
        current = page_info.current_page
        total = page_info.total_pages

        # Show up to 5 pages around current page
        range_start = max(1, current - 2)
        range_end = min(total, current + 2)

        Enum.to_list(range_start..range_end)
      end

      # Component-specific functions that need to be implemented by each component
      defp get_columns_from_slots(_assigns) do
        raise "get_columns_from_slots/1 must be implemented by the component using BaseLiveComponent"
      end

      # Allow components to override any of these functions
      defoverridable [
        mount: 1,
        update: 2,
        handle_event: 3,
        handle_async: 3,
        assign_defaults: 1,
        assign_column_definitions: 1,
        extract_initial_sorts: 1,
        decode_url_state: 2,
        load_data_if_needed: 1,
        load_data: 1,
        notify_state_change: 1,
        notify_state_change: 2,
        build_page_range: 1,
        get_columns_from_slots: 1
      ]
    end
  end
end