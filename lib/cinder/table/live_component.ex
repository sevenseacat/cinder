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
      |> decode_url_filters(assigns)
      |> decode_url_pagination(assigns)
      |> decode_url_sorting(assigns)
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
      |> notify_state_change()
      |> load_data()

    {:noreply, socket}
  end

  @impl true
  def handle_event("clear_filter", %{"key" => key}, socket) do
    new_filters = Map.delete(socket.assigns.filters, key)

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
    new_sort = toggle_sort_direction(current_sort, key)

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
    socket =
      socket
      |> assign(:filters, %{})
      |> assign(:current_page, 1)
      |> load_data()

    # Notify parent about state changes
    socket = notify_state_change(socket, %{})

    {:noreply, socket}
  end

  @impl true
  def handle_event("filter_change", %{"filters" => filter_params}, socket) do
    # Ensure multi-select fields are included even when no checkboxes are selected
    complete_filter_params = ensure_multiselect_fields(filter_params, socket.assigns.columns)

    # Handle special cases for range inputs
    processed_params = process_filter_params(complete_filter_params, socket.assigns.columns)

    # Start with existing filters and only update/remove changed ones
    new_filters =
      processed_params
      |> Enum.reduce(socket.assigns.filters, fn {string_key, value}, acc ->
        if value == "" or is_nil(value) or value == "all" or
             (is_list(value) and Enum.empty?(value)) do
          # Remove filter if value is empty
          Map.delete(acc, string_key)
        else
          # Determine filter type from column configuration
          column = Enum.find(socket.assigns.columns, &(&1.key == string_key))
          filter_type = if column, do: column.filter_type, else: :text

          operator =
            case filter_type do
              :text -> :contains
              :select -> :equals
              :multi_select -> :in
              :boolean -> :equals
              :date_range -> :between
              :number_range -> :between
              _ -> :equals
            end

          processed_value =
            case filter_type do
              :boolean when value == "true" ->
                "true"

              :boolean when value == "false" ->
                "false"

              :date_range ->
                case String.split(value, ",") do
                  [from, to] -> %{from: from, to: to}
                  [from] -> %{from: from, to: ""}
                  _ -> %{from: "", to: ""}
                end

              :number_range ->
                result =
                  case String.split(value, ",") do
                    [min, max] -> %{min: min, max: max}
                    [min] -> %{min: min, max: ""}
                    _ -> %{min: "", max: ""}
                  end

                result

              :multi_select ->
                # For multi-select, value is already processed as comma-separated string
                # Split it back into list for the filter
                String.split(value, ",")

              _ ->
                value
            end

          Map.put(acc, string_key, %{
            type: filter_type,
            value: processed_value,
            operator: operator
          })
        end
      end)

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
    if socket.assigns[:on_state_change] do
      filters = filters || socket.assigns.filters
      current_page = socket.assigns.current_page
      sort_by = socket.assigns.sort_by

      encoded_state = encode_state_for_url(filters, current_page, sort_by)
      # Use send/2 with self() to send to the current LiveView process
      # This works because LiveComponents run in the same process as their parent LiveView
      send(self(), {socket.assigns.on_state_change, socket.assigns.id, encoded_state})
    end

    socket
  end

  # Decode filter state from URL parameters
  defp decode_url_filters(socket, assigns) do
    url_filters = Map.get(assigns, :url_filters, %{})

    # Only decode URL filters if they are provided, otherwise keep existing filters
    if Enum.empty?(url_filters) do
      socket
    else
      decoded_filters = decode_filters_from_url(url_filters, socket.assigns.columns)
      assign(socket, :filters, decoded_filters)
    end
  end

  defp decode_url_pagination(socket, assigns) do
    url_page = Map.get(assigns, :url_page)

    if url_page && is_binary(url_page) do
      case Integer.parse(url_page) do
        {page, ""} when page > 0 ->
          assign(socket, :current_page, page)

        _ ->
          socket
      end
    else
      socket
    end
  end

  defp decode_url_sorting(socket, assigns) do
    url_sort = Map.get(assigns, :url_sort)

    if url_sort && is_binary(url_sort) do
      sort_by = decode_sort_from_url(url_sort)
      assign(socket, :sort_by, sort_by)
    else
      socket
    end
  end

  # Encode filters for URL parameters
  defp encode_filters_for_url(filters) do
    filters
    |> Enum.map(fn {key, filter} ->
      encoded_value =
        case filter.type do
          :multi_select when is_list(filter.value) ->
            Enum.join(filter.value, ",")

          :date_range ->
            "#{filter.value.from},#{filter.value.to}"

          :number_range ->
            "#{filter.value.min},#{filter.value.max}"

          _ ->
            to_string(filter.value)
        end

      {key, encoded_value}
    end)
    |> Enum.into(%{})
  end

  defp encode_state_for_url(filters, current_page, sort_by) do
    encoded_filters = encode_filters_for_url(filters)

    state =
      if current_page > 1 do
        Map.put(encoded_filters, :page, to_string(current_page))
      else
        encoded_filters
      end

    state =
      if not Enum.empty?(sort_by) do
        Map.put(state, :sort, encode_sort_for_url(sort_by))
      else
        state
      end

    state
  end

  defp encode_sort_for_url(sort_by) do
    sort_by
    |> Enum.map(fn {key, direction} ->
      case direction do
        :desc -> "-#{key}"
        _ -> key
      end
    end)
    |> Enum.join(",")
  end

  defp decode_sort_from_url(url_sort) do
    # Parse Ash sort string format manually since sort_input needs a query
    url_sort
    |> String.split(",")
    |> Enum.filter(&(&1 != ""))
    |> Enum.map(fn sort_item ->
      case String.starts_with?(sort_item, "-") do
        true ->
          key = String.slice(sort_item, 1..-1//1)
          {key, :desc}

        false ->
          {sort_item, :asc}
      end
    end)
  end

  # Decode filters from URL parameters
  defp decode_filters_from_url(url_filters, columns) do
    url_filters
    |> Enum.reduce(%{}, fn {key, value}, acc ->
      column = Enum.find(columns, &(&1.key == key))

      if column && column.filterable && value != "" do
        filter_type = column.filter_type

        decoded_value =
          case filter_type do
            :multi_select ->
              String.split(value, ",")

            :date_range ->
              case String.split(value, ",") do
                [from, to] -> %{from: from, to: to}
                [from] -> %{from: from, to: ""}
                _ -> %{from: "", to: ""}
              end

            :number_range ->
              case String.split(value, ",") do
                [min, max] -> %{min: min, max: max}
                [min] -> %{min: min, max: ""}
                _ -> %{min: "", max: ""}
              end

            :boolean ->
              value

            _ ->
              value
          end

        operator =
          case filter_type do
            :text -> :contains
            :select -> :equals
            :multi_select -> :in
            :boolean -> :equals
            :date_range -> :between
            :number_range -> :between
            _ -> :equals
          end

        Map.put(acc, key, %{
          type: filter_type,
          value: decoded_value,
          operator: operator
        })
      else
        acc
      end
    end)
  end

  # Ensure multi-select fields are included even when no checkboxes are selected
  defp ensure_multiselect_fields(filter_params, columns) do
    columns
    |> Enum.filter(&(&1.filterable and &1.filter_type == :multi_select))
    |> Enum.reduce(filter_params, fn column, acc ->
      # If multi-select field is missing (all checkboxes unchecked), add it as empty array
      if not Map.has_key?(acc, column.key) do
        Map.put(acc, column.key, [])
      else
        acc
      end
    end)
  end

  # Process filter params to handle special cases like ranges
  defp process_filter_params(filter_params, _columns) do
    filter_params
    |> Enum.reduce(%{}, fn {key, value}, acc ->
      cond do
        # Handle date range fields
        String.ends_with?(key, "_from") ->
          base_key = String.replace_suffix(key, "_from", "")
          to_key = base_key <> "_to"
          to_value = Map.get(filter_params, to_key, "")
          combined_value = if value != "" or to_value != "", do: "#{value},#{to_value}", else: ""
          Map.put(acc, base_key, combined_value)

        String.ends_with?(key, "_to") ->
          # Skip _to keys, they're handled with _from
          acc

        # Handle number range fields
        String.ends_with?(key, "_min") ->
          base_key = String.replace_suffix(key, "_min", "")
          max_key = base_key <> "_max"
          max_value = Map.get(filter_params, max_key, "")

          combined_value =
            if value != "" or max_value != "", do: "#{value},#{max_value}", else: ""

          Map.put(acc, base_key, combined_value)

        String.ends_with?(key, "_max") ->
          # Skip _max keys, they're handled with _min
          acc

        # Handle multi-select arrays
        is_list(value) ->
          combined_value = if Enum.empty?(value), do: "", else: Enum.join(value, ",")
          Map.put(acc, key, combined_value)

        # Regular fields
        true ->
          Map.put(acc, key, value)
      end
    end)
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

    # Convert filters to form values - ensure all form fields get their values
    filter_values =
      filterable_columns
      |> Enum.reduce(%{}, fn column, acc ->
        filter = Map.get(assigns.filters, column.key)

        case {column.filter_type, filter} do
          {:date_range, %{value: %{from: from, to: to}}} ->
            acc
            |> Map.put("#{column.key}_from", from || "")
            |> Map.put("#{column.key}_to", to || "")

          {:date_range, _} ->
            acc
            |> Map.put("#{column.key}_from", "")
            |> Map.put("#{column.key}_to", "")

          {:number_range, %{value: %{min: min, max: max}}} ->
            acc
            |> Map.put("#{column.key}_min", min || "")
            |> Map.put("#{column.key}_max", max || "")

          {:number_range, _} ->
            acc
            |> Map.put("#{column.key}_min", "")
            |> Map.put("#{column.key}_max", "")

          {:multi_select, %{value: values}} when is_list(values) ->
            Map.put(acc, column.key, if(Enum.empty?(values), do: "", else: values))

          {:boolean, %{value: value}} ->
            # Convert boolean back to string for form display
            string_value =
              case value do
                true -> "true"
                false -> "false"
                "true" -> "true"
                "false" -> "false"
                _ -> ""
              end

            Map.put(acc, column.key, string_value)

          {_, %{value: value}} ->
            Map.put(acc, column.key, value || "")

          {_, _} ->
            # No filter exists, set appropriate defaults
            case column.filter_type do
              :date_range ->
                acc
                |> Map.put("#{column.key}_from", "")
                |> Map.put("#{column.key}_to", "")

              :number_range ->
                acc
                |> Map.put("#{column.key}_min", "")
                |> Map.put("#{column.key}_max", "")

              _ ->
                Map.put(acc, column.key, "")
            end
        end
      end)

    assigns =
      assigns
      |> assign(:filterable_columns, filterable_columns)
      |> assign(:active_filters, active_filters)
      |> assign(:filter_values, filter_values)

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

      <form phx-change="filter_change" phx-target={@myself}>
        <div class={@theme.filter_inputs_class}>
          <div :for={column <- @filterable_columns} class={@theme.filter_input_wrapper_class}>
            <label class={@theme.filter_label_class}>{column.label}:</label>
            <.filter_input
              column={column}
              current_value={Map.get(@filter_values, column.key, "")}
              filter_values={@filter_values}
              theme={@theme}
              myself={@myself}
            />
          </div>
        </div>
      </form>
    </div>
    """
  end

  # Filter input component
  defp filter_input(assigns) do
    ~H"""
    <div class="flex items-center space-x-2">
      <div class="flex-1">
        <%= case @column.filter_type do %>
          <% :text -> %>
            <.text_filter_input
              column={@column}
              current_value={@current_value}
              theme={@theme}
            />
          <% :select -> %>
            <.select_filter_input
              column={@column}
              current_value={@current_value}
              theme={@theme}
            />
          <% :multi_select -> %>
            <.multi_select_filter_input
              column={@column}
              current_value={@current_value}
              theme={@theme}
            />
          <% :date_range -> %>
            <.date_range_filter_input
              column={@column}
              from_value={Map.get(@filter_values, "#{@column.key}_from", "")}
              to_value={Map.get(@filter_values, "#{@column.key}_to", "")}
              theme={@theme}
            />
          <% :number_range -> %>
            <.number_range_filter_input
              column={@column}
              min_value={Map.get(@filter_values, "#{@column.key}_min", "")}
              max_value={Map.get(@filter_values, "#{@column.key}_max", "")}
              theme={@theme}
            />
          <% :boolean -> %>
            <.boolean_filter_input
              column={@column}
              current_value={@current_value}
              theme={@theme}
            />
          <% _ -> %>
            <.text_filter_input
              column={@column}
              current_value={@current_value}
              theme={@theme}
            />
        <% end %>
      </div>

      <!-- Clear individual filter button -->
      <button
        :if={@current_value != "" and not is_nil(@current_value) and @current_value != []}
        type="button"
        phx-click="clear_filter"
        phx-value-key={@column.key}
        phx-target={@myself}
        class={@theme.filter_clear_button_class}
        title="Clear filter"
      >
        ×
      </button>
    </div>
    """
  end

  # Text filter input component
  defp text_filter_input(assigns) do
    placeholder =
      get_in(assigns.column.filter_options, [:placeholder]) || "Filter #{assigns.column.label}..."

    assigns = assign(assigns, :placeholder, placeholder)

    ~H"""
    <input
      type="text"
      name={"filters[#{@column.key}]"}
      value={@current_value}
      placeholder={@placeholder}
      phx-debounce="300"
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
      name={"filters[#{@column.key}]"}
      value={@current_value}
      class={@theme.filter_select_input_class}
    >
      <option value="">{@prompt}</option>
      <option
        :for={{label, value} <- @options}
        value={value}
        selected={@current_value == to_string(value)}
      >
        {label}
      </option>
    </select>
    """
  end

  # Multi-select filter input component
  defp multi_select_filter_input(assigns) do
    options = get_in(assigns.column.filter_options, [:options]) || []

    selected_values =
      case assigns.current_value do
        val when is_list(val) -> val
        val when is_binary(val) and val != "" -> String.split(val, ",")
        _ -> []
      end

    assigns = assign(assigns, :options, options)
    assigns = assign(assigns, :selected_values, selected_values)

    ~H"""
    <div class="space-y-2 max-h-32 overflow-y-auto border rounded p-2 bg-white">
      <div :for={{label, value} <- @options} class="flex items-center">
        <input
          type="checkbox"
          name={"filters[#{@column.key}][]"}
          value={value}
          checked={to_string(value) in Enum.map(@selected_values, &to_string/1)}
          class="mr-2"
        />
        <label class="text-sm">
          {label}
        </label>
      </div>
    </div>
    """
  end

  # Date range filter input component
  defp date_range_filter_input(assigns) do
    from_value = assigns.from_value || ""
    to_value = assigns.to_value || ""

    assigns =
      assigns
      |> assign(:from_value, from_value)
      |> assign(:to_value, to_value)

    ~H"""
    <div class="flex space-x-2">
      <div class="flex-1">
        <input
          type="date"
          name={"filters[#{@column.key}_from]"}
          value={@from_value}
          placeholder="From"
          class={@theme.filter_date_input_class}
        />
      </div>
      <div class="flex-1">
        <input
          type="date"
          name={"filters[#{@column.key}_to]"}
          value={@to_value}
          placeholder="To"
          class={@theme.filter_date_input_class}
        />
      </div>
    </div>
    """
  end

  # Number range filter input component
  defp number_range_filter_input(assigns) do
    min_value = assigns.min_value || ""
    max_value = assigns.max_value || ""

    assigns =
      assigns
      |> assign(:min_value, min_value)
      |> assign(:max_value, max_value)

    ~H"""
    <div class="flex space-x-2">
      <div class="flex-1">
        <input
          type="number"
          name={"filters[#{@column.key}_min]"}
          value={@min_value}
          placeholder="Min"
          phx-debounce="300"
          class={@theme.filter_number_input_class}
        />
      </div>
      <div class="flex-1">
        <input
          type="number"
          name={"filters[#{@column.key}_max]"}
          value={@max_value}
          placeholder="Max"
          phx-debounce="300"
          class={@theme.filter_number_input_class}
        />
      </div>
    </div>
    """
  end

  # Boolean filter input component
  defp boolean_filter_input(assigns) do
    current_value = assigns.current_value || ""
    options = get_in(assigns.column.filter_options, [:labels]) || %{}

    assigns = assign(assigns, :current_boolean_value, current_value)
    assigns = assign(assigns, :all_label, Map.get(options, :all, "All"))
    assigns = assign(assigns, :true_label, Map.get(options, true, "True"))
    assigns = assign(assigns, :false_label, Map.get(options, false, "False"))

    ~H"""
    <div class="flex space-x-4">
      <label class="flex items-center">
        <input
          type="radio"
          name={"filters[#{@column.key}]"}
          value=""
          checked={@current_boolean_value == "" || @current_boolean_value == "all"}
          class="mr-1"
        />
        <span class="text-sm">{@all_label}</span>
      </label>
      <label class="flex items-center">
        <input
          type="radio"
          name={"filters[#{@column.key}]"}
          value="true"
          checked={@current_boolean_value == "true"}
          class="mr-1"
        />
        <span class="text-sm">{@true_label}</span>
      </label>
      <label class="flex items-center">
        <input
          type="radio"
          name={"filters[#{@column.key}]"}
          value="false"
          checked={@current_boolean_value == "false"}
          class="mr-1"
        />
        <span class="text-sm">{@false_label}</span>
      </label>
    </div>
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

      # Execute the query to get paginated results
      case Ash.read(query, actor: current_user_var) do
        {:ok, results} when is_list(results) ->
          # Get total count for pagination info
          count_query =
            resource_var
            |> Ash.Query.for_read(:read, %{}, actor: current_user_var)
            |> apply_query_opts(query_opts_var)
            |> apply_filters(filters_var, columns_var)

          case Ash.count(count_query, actor: current_user_var) do
            {:ok, total_count} ->
              {results, current_page_var, page_size_var, total_count}

            {:error, _count_error} ->
              # Fall back to length-based calculation if count fails
              {results, current_page_var, page_size_var}
          end

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

  def handle_async(:load_data, {:ok, {results, current_page, page_size, total_count}}, socket) do
    socket =
      socket
      |> assign(:loading, false)
      |> assign(:data, results)
      |> assign(
        :page_info,
        build_page_info_with_total_count(results, current_page, page_size, total_count)
      )

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

      {:multi_select, :in} ->
        if String.contains?(key, ".") do
          query
        else
          field_ref = Ash.Expr.ref(String.to_atom(key))
          Ash.Query.filter(query, ^field_ref in ^value)
        end

      {:date_range, :between} ->
        if String.contains?(key, ".") do
          query
        else
          field_ref = Ash.Expr.ref(String.to_atom(key))
          %{from: from_date, to: to_date} = value

          cond do
            from_date != "" and to_date != "" ->
              Ash.Query.filter(query, ^field_ref >= ^from_date and ^field_ref <= ^to_date)

            from_date != "" ->
              Ash.Query.filter(query, ^field_ref >= ^from_date)

            to_date != "" ->
              Ash.Query.filter(query, ^field_ref <= ^to_date)

            true ->
              query
          end
        end

      {:number_range, :between} ->
        if String.contains?(key, ".") do
          query
        else
          field_ref = Ash.Expr.ref(String.to_atom(key))
          %{min: min_val, max: max_val} = value

          cond do
            min_val != "" and max_val != "" ->
              min_num = parse_number(min_val)
              max_num = parse_number(max_val)
              Ash.Query.filter(query, ^field_ref >= ^min_num and ^field_ref <= ^max_num)

            min_val != "" ->
              min_num = parse_number(min_val)
              Ash.Query.filter(query, ^field_ref >= ^min_num)

            max_val != "" ->
              max_num = parse_number(max_val)
              Ash.Query.filter(query, ^field_ref <= ^max_num)

            true ->
              query
          end
        end

      {:boolean, :equals} ->
        if String.contains?(key, ".") do
          query
        else
          field_ref = Ash.Expr.ref(String.to_atom(key))

          case value do
            "true" -> Ash.Query.filter(query, ^field_ref == true)
            "false" -> Ash.Query.filter(query, ^field_ref == false)
            # "all" or any other value means no filter
            _ -> query
          end
        end

      _ ->
        # Fallback for unsupported filter types
        query
    end
  end

  # Helper function for safe number parsing
  defp parse_number(str) do
    case Integer.parse(str) do
      {int, ""} ->
        int

      _ ->
        case Float.parse(str) do
          {float, ""} -> float
          _ -> 0
        end
    end
  end

  # Helper function to check if filter has a value

  defp apply_sorting(query, [], _columns), do: query

  defp apply_sorting(query, sort_by, columns) do
    # Check if any columns have custom sort functions
    has_custom_sorts =
      Enum.any?(sort_by, fn {key, _direction} ->
        column = Enum.find(columns, &(&1.key == key))
        column && column.sort_fn
      end)

    if has_custom_sorts do
      # Use custom logic when custom sort functions are present
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
    else
      # Use Ash sort input for standard sorting (more efficient)
      sort_string = encode_sort_for_url(sort_by)

      if sort_string != "" do
        Ash.Query.sort(query, sort_string)
      else
        query
      end
    end
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

  defp build_page_info_with_total_count(results, current_page, page_size, total_count) do
    total_pages = max(1, ceil(total_count / page_size))
    start_index = (current_page - 1) * page_size + 1
    actual_end_index = start_index + length(results) - 1

    %{
      current_page: current_page,
      total_pages: total_pages,
      total_count: total_count,
      has_next_page: current_page < total_pages,
      has_previous_page: current_page > 1,
      start_index: if(total_count > 0, do: start_index, else: 0),
      end_index: if(total_count > 0, do: max(actual_end_index, 0), else: 0)
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

  defp parse_column_definition(slot, resource) do
    # Infer filter type and options from Ash resource if not explicitly set
    inferred = infer_filter_config(slot.key, resource, slot)

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

  # Infer filter configuration from Ash resource attribute definitions
  defp infer_filter_config(key, resource, slot) do
    # Skip inference if filterable is false or if both filter_type and filter_options are explicitly set
    if not Map.get(slot, :filterable, false) or
         (Map.has_key?(slot, :filter_type) and Map.has_key?(slot, :filter_options)) do
      %{filter_type: :text, filter_options: []}
    else
      attribute = get_ash_attribute(resource, key)

      case attribute do
        nil ->
          # No attribute found, default to text
          %{filter_type: :text, filter_options: []}

        %{type: type, constraints: constraints} ->
          # Handle constraint-based enums (new Ash format)
          cond do
            is_map(constraints) and Map.has_key?(constraints, :one_of) ->
              values = Map.get(constraints, :one_of)

              %{
                filter_type: :select,
                filter_options: [
                  options: enum_to_options(values, type),
                  prompt: "All #{humanize_key(key)}"
                ]
              }

            # Handle Ash.Type.Enum and custom enum types - try to call values/0
            is_atom(type) ->
              case (try do
                      apply(type, :values, [])
                    rescue
                      _ -> nil
                    end) do
                values when is_list(values) ->
                  %{
                    filter_type: :select,
                    filter_options: [
                      options: enum_to_options(values, type),
                      prompt: "All #{humanize_key(key)}"
                    ]
                  }

                _ ->
                  # Not an enum type, check other conditions
                  cond do
                    type == Ash.Type.Boolean ->
                      %{filter_type: :boolean, filter_options: []}

                    type == Ash.Type.Date ->
                      %{filter_type: :date_range, filter_options: []}

                    type in [Ash.Type.Integer, Ash.Type.Decimal, Ash.Type.Float] ->
                      %{filter_type: :number_range, filter_options: []}

                    type == Ash.Type.String ->
                      %{
                        filter_type: :text,
                        filter_options: [
                          operator: :contains,
                          placeholder: "Search #{humanize_key(key)}...",
                          case_sensitive: false
                        ]
                      }

                    true ->
                      %{filter_type: :text, filter_options: []}
                  end
              end

            true ->
              %{filter_type: :text, filter_options: []}
          end

        %{type: {:array, _inner_type}} ->
          # Array types - simplified for now, just default to text
          %{filter_type: :text, filter_options: []}

        %{type: {:one_of, values}} when is_list(values) ->
          # Legacy enum format
          %{
            filter_type: :select,
            filter_options: [
              options: enum_to_options(values, nil),
              prompt: "All #{humanize_key(key)}"
            ]
          }

        %{type: type} when type in [:boolean, Ash.Type.Boolean] ->
          %{filter_type: :boolean, filter_options: []}

        %{type: type} when type in [:date, Ash.Type.Date] ->
          %{filter_type: :date_range, filter_options: []}

        %{type: type}
        when type in [
               :integer,
               :decimal,
               :float,
               Ash.Type.Integer,
               Ash.Type.Decimal,
               Ash.Type.Float
             ] ->
          %{filter_type: :number_range, filter_options: []}

        %{type: type} when type in [:string, Ash.Type.String] ->
          %{
            filter_type: :text,
            filter_options: [
              operator: :contains,
              placeholder: "Search #{humanize_key(key)}...",
              case_sensitive: false
            ]
          }

        _ ->
          %{filter_type: :text, filter_options: []}
      end
    end
  end

  # Get attribute definition from Ash resource
  defp get_ash_attribute(resource, key) do
    try do
      key_atom = if is_binary(key), do: String.to_atom(key), else: key

      # Check if this is actually an Ash resource using Ash.Resource.Info.resource?/1
      if Ash.Resource.Info.resource?(resource) do
        attributes = Ash.Resource.Info.attributes(resource)
        Enum.find(attributes, &(&1.name == key_atom))
      else
        nil
      end
    rescue
      _ -> nil
    catch
      _ -> nil
    end
  end

  # Convert enum values to select options
  defp enum_to_options(values, enum_module) do
    Enum.map(values, fn value ->
      case value do
        atom when is_atom(atom) ->
          label =
            if enum_module && function_exported?(enum_module, :description, 1) do
              apply(enum_module, :description, [atom])
            else
              humanize_atom(atom)
            end

          {label, atom}

        string when is_binary(string) ->
          {String.capitalize(string), string}

        {label, value} ->
          {to_string(label), value}

        other ->
          {to_string(other), other}
      end
    end)
  end

  # Convert atom to human readable string
  defp humanize_atom(atom) do
    atom
    |> to_string()
    |> String.replace("_", " ")
    |> String.split(" ")
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end

  # Convert key to human readable string
  defp humanize_key(key) do
    key
    |> to_string()
    |> String.replace("_", " ")
    |> String.split(" ")
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
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
      filter_clear_all_class:
        "cinder-filter-clear-all text-xs text-blue-600 hover:text-blue-800 underline",
      filter_inputs_class:
        "cinder-filter-inputs grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4",
      filter_input_wrapper_class: "cinder-filter-input-wrapper",
      filter_label_class: "cinder-filter-label block text-sm font-medium text-gray-700 mb-1",
      filter_placeholder_class:
        "cinder-filter-placeholder text-xs text-gray-400 italic p-2 border rounded",
      filter_text_input_class:
        "w-full px-3 py-2 border border-gray-300 rounded-md text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500",
      filter_date_input_class:
        "w-full px-3 py-2 border border-gray-300 rounded-md text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500",
      filter_number_input_class:
        "w-full px-3 py-2 border border-gray-300 rounded-md text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500",
      filter_select_input_class:
        "cinder-filter-select-input w-full px-3 py-2 border border-gray-300 rounded-md text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500",
      filter_clear_button_class:
        "cinder-filter-clear-button text-gray-400 hover:text-gray-600 text-sm font-medium px-2 py-1 rounded hover:bg-gray-100"
    }
  end
end
