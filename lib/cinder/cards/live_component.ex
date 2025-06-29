defmodule Cinder.Cards.LiveComponent do
  @moduledoc """
  LiveComponent for interactive card layouts with Ash query execution.

  Handles state management, data loading, and pagination for the cards component.
  Reuses the same core logic as the table component but renders data as cards.
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

  def update(%{refresh: true} = assigns, socket) do
    # Force refresh of cards data
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

      <!-- Cards Grid -->
      <div class={@theme.cards_wrapper_class} {@theme.cards_wrapper_data}>
        <div class={@theme.cards_grid_class} {@theme.cards_grid_data}>
          <div :for={item <- @data}
               class={get_card_classes(@theme.card_class, @card_click)}
               {@theme.card_data}
               phx-click={@card_click && @card_click.(item)}>
            {render_slot(@card_slot, item)}
          </div>
        </div>

        <!-- Empty State -->
        <div :if={@data == [] and not @loading} class={@theme.empty_class} {@theme.empty_data}>
          {@empty_message}
        </div>
      </div>

      <!-- Loading indicator -->
      <div :if={@loading} class={@theme.loading_overlay_class} {@theme.loading_overlay_data}>
        <div class={@theme.loading_spinner_class}>
          {@loading_message}
        </div>
      </div>

      <!-- Pagination -->
      <div :if={@show_pagination and @page_info.total_pages > 1}
           class={@theme.pagination_wrapper_class} {@theme.pagination_wrapper_data}>
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
  def handle_event("filter_change", %{"filters" => filter_params}, socket) do
    new_filters = Cinder.FilterManager.params_to_filters(filter_params, socket.assigns.columns)

    socket =
      socket
      |> assign(:filters, new_filters)
      |> assign(:current_page, 1)
      |> load_data()
      |> notify_state_change()

    {:noreply, socket}
  end

  def handle_event("clear_filter", %{"field" => field}, socket) do
    new_filters = Map.delete(socket.assigns.filters, field)

    socket =
      socket
      |> assign(:filters, new_filters)
      |> assign(:current_page, 1)
      |> load_data()
      |> notify_state_change()

    {:noreply, socket}
  end

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
      |> notify_state_change()

    {:noreply, socket}
  end

  # Private functions

  defp assign_defaults(socket) do
    socket
    |> assign_new(:filters, fn -> %{} end)
    |> assign_new(:sort_by, fn -> [] end)
    |> assign_new(:current_page, fn -> 1 end)
    |> assign_new(:loading, fn -> false end)
    |> assign_new(:data, fn -> [] end)
    |> assign_new(:page_info, fn -> Cinder.QueryBuilder.build_error_page_info() end)
  end

  defp assign_column_definitions(socket) do
    # Convert props to column format for compatibility with existing logic
    columns = Enum.map(socket.assigns.props, fn prop ->
      %{
        field: prop.field,
        label: prop.label,
        filterable: prop.filterable,
        filter_type: prop.filter_type,
        filter_options: prop.filter_options,
        sortable: prop.sortable,
        class: ""
      }
    end)

    assign(socket, :columns, columns)
  end

  defp decode_url_state(socket, assigns) do
    socket
    |> assign_new(:filters, fn -> assigns.url_filters || %{} end)
    |> assign_new(:current_page, fn -> assigns.url_page || 1 end)
    |> assign_new(:sort_by, fn -> assigns.url_sort || [] end)
  end

  defp load_data_if_needed(socket) do
    if socket.assigns[:data] == [] do
      load_data(socket)
    else
      socket
    end
  end

  defp load_data(socket) do
    socket = assign(socket, :loading, true)

    case execute_query(socket) do
      {:ok, {data, page_info}} ->
        socket
        |> assign(:data, data)
        |> assign(:page_info, page_info)
        |> assign(:loading, false)

      {:error, error} ->
        Logger.error("Cards query failed: #{inspect(error)}")

        socket
        |> assign(:data, [])
        |> assign(:page_info, Cinder.QueryBuilder.build_error_page_info())
        |> assign(:loading, false)
        |> assign(:error, error)
    end
  end

  defp execute_query(socket) do
    assigns = socket.assigns

    Cinder.QueryBuilder.build_and_execute(assigns.query, [
      actor: assigns.actor,
      tenant: assigns.tenant,
      filters: assigns.filters,
      sort_by: assigns.sort_by,
      page_size: assigns.page_size,
      current_page: assigns.current_page,
      columns: assigns.columns,
      query_opts: assigns.query_opts
    ])
  end

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


  defp notify_state_change(socket) do
    if socket.assigns.on_state_change do
      state = %{
        filters: socket.assigns.filters,
        sort_by: socket.assigns.sort_by,
        current_page: socket.assigns.current_page
      }

      send(self(), {socket.assigns.on_state_change, socket.assigns.id, state})
    end

    socket
  end

  defp get_card_classes(base_classes, card_click) do
    classes = [base_classes]

    if card_click do
      classes ++ ["cursor-pointer"]
    else
      classes
    end
  end
end