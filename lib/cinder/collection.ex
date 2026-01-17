defmodule Cinder.Collection do
  @moduledoc """
  Unified collection component for displaying data in table, list, or grid layouts.

  This component provides a single API for all collection displays, with the `layout`
  attribute selecting how items are rendered. All layouts share the same filtering,
  sorting, pagination, and URL sync capabilities.

  ## Layouts

  - `:table` (default) - Traditional HTML table with sortable headers
  - `:list` - Vertical list with sort button group
  - `:grid` - Responsive card grid with sort button group

  ## Basic Usage

  ### Table Layout (default)

  ```heex
  <Cinder.collection resource={MyApp.User} actor={@current_user}>
    <:col :let={user} field="name" filter sort>{user.name}</:col>
    <:col :let={user} field="email" filter>{user.email}</:col>
  </Cinder.collection>
  ```

  ### List Layout

  ```heex
  <Cinder.collection resource={MyApp.User} actor={@current_user} layout={:list}>
    <:col field="name" filter sort />
    <:col field="status" filter={:select} />

    <:item :let={user}>
      <div class="flex justify-between">
        <span class="font-bold">{user.name}</span>
        <span>{user.status}</span>
      </div>
    </:item>
  </Cinder.collection>
  ```

  ### Grid Layout

  ```heex
  <Cinder.collection resource={MyApp.Product} actor={@current_user} layout={:grid}>
    <:col field="name" filter sort search />
    <:col field="category" filter={:select} />

    <:item :let={product}>
      <h3 class="font-bold">{product.name}</h3>
      <p class="text-gray-600">{product.category}</p>
      <p class="text-lg font-semibold">${product.price}</p>
    </:item>
  </Cinder.collection>
  ```

  ## Grid Columns

  Control the number of grid columns with the `grid_columns` attribute:

  ```heex
  <!-- Fixed 4 columns -->
  <Cinder.collection resource={MyApp.Product} layout={:grid} grid_columns={4}>
    ...
  </Cinder.collection>

  <!-- Responsive columns -->
  <Cinder.collection resource={MyApp.Product} layout={:grid} grid_columns={[xs: 1, md: 2, lg: 3, xl: 4]}>
    ...
  </Cinder.collection>
  ```

  ## Layout-Specific Attributes

  | Attribute | Table | List | Grid | Description |
  |-----------|-------|------|------|-------------|
  | `<:col>` content | ✅ Rendered | ❌ Ignored | ❌ Ignored | Cell content for table rows |
  | `<:item>` slot | ❌ Ignored | ✅ Required | ✅ Required | Template for each item |
  | `sort_label` | ❌ N/A | ✅ Button label | ✅ Button label | Label for sort button group |
  | `container_class` | ❌ N/A | ✅ Override | ✅ Override | Custom container CSS |
  | `grid_columns` | ❌ N/A | ❌ N/A | ✅ Column count | Number of grid columns |
  | `click` | ✅ Row click | ✅ Item click | ✅ Item click | Click handler |
  """

  use Phoenix.Component
  require Logger

  # Shared attributes for all layouts
  attr(:resource, :atom,
    default: nil,
    doc: "The Ash resource to query (use either resource or query, not both)"
  )

  attr(:query, :any,
    default: nil,
    doc: "The Ash query to execute (use either resource or query, not both)"
  )

  attr(:actor, :any, default: nil, doc: "Actor for authorization")
  attr(:tenant, :any, default: nil, doc: "Tenant for multi-tenant resources")
  attr(:scope, :any, default: nil, doc: "Ash scope containing actor and tenant")

  attr(:layout, :any,
    default: :table,
    doc: "Layout type: :table, :list, or :grid (also accepts strings)"
  )

  attr(:id, :string, default: "cinder-collection", doc: "Unique identifier for the collection")

  attr(:page_size, :any,
    default: 25,
    doc: "Number of items per page or [default: 25, options: [10, 25, 50]]"
  )

  attr(:theme, :any, default: "default", doc: "Theme name or theme map")

  attr(:url_state, :any,
    default: false,
    doc: "URL state object from UrlSync.handle_params, or false to disable"
  )

  attr(:query_opts, :list,
    default: [],
    doc: "Additional Ash query options"
  )

  attr(:on_state_change, :any, default: nil, doc: "Custom state change handler")
  attr(:show_pagination, :boolean, default: true, doc: "Whether to show pagination controls")

  attr(:pagination, :any,
    default: :offset,
    doc:
      "Pagination mode: :offset (default) or :keyset. Keyset pagination is faster for large datasets but only supports prev/next navigation."
  )

  attr(:show_filters, :boolean,
    default: nil,
    doc: "Whether to show filter controls (auto-detected if nil)"
  )

  attr(:show_sort, :boolean,
    default: nil,
    doc: "Whether to show sort controls (auto-detected if nil, list/grid only)"
  )

  attr(:loading_message, :string, default: "Loading...", doc: "Message to show while loading")

  attr(:filters_label, :string,
    default: "🔍 Filters",
    doc: "Label for the filters component"
  )

  attr(:sort_label, :string,
    default: "Sort by:",
    doc: "Label for sort button group (list/grid only)"
  )

  attr(:search, :any,
    default: nil,
    doc: "Search configuration. Auto-enables when searchable columns exist."
  )

  attr(:empty_message, :string,
    default: "No results found",
    doc: "Message to show when no results"
  )

  attr(:class, :string, default: "", doc: "Additional CSS classes for the outer container")

  attr(:container_class, :string,
    default: nil,
    doc: "Override the item container CSS class (list/grid only)"
  )

  attr(:grid_columns, :any,
    default: [xs: 1, md: 2, lg: 3],
    doc: "Number of grid columns. Integer (e.g., 4) or keyword list (e.g., [xs: 1, md: 2, lg: 3])"
  )

  attr(:click, :any,
    default: nil,
    doc: "Function to call when a row/item is clicked. Receives the item as argument."
  )

  attr(:id_field, :atom,
    default: :id,
    doc: "Field to use as ID for update_if_visible operations (defaults to :id)"
  )

  slot :col do
    attr(:field, :string,
      required: false,
      doc: "Field name (supports dot notation for relationships or `__` for embedded attributes)"
    )

    attr(:filter, :any,
      doc: "Enable filtering (true, false, filter type atom, or unified config)"
    )

    attr(:filter_options, :list,
      doc:
        "Custom filter options - DEPRECATED: Use filter={[type: :select, options: [...]]} instead"
    )

    attr(:sort, :any,
      doc: "Enable sorting (true, false, or unified config [cycle: [nil, :asc, :desc]])"
    )

    attr(:search, :boolean, doc: "Enable global search on this column")
    attr(:label, :string, doc: "Custom column label (auto-generated if not provided)")
    attr(:class, :string, doc: "CSS classes for table column (table layout only)")
  end

  slot(:item,
    required: false,
    doc: "Template for rendering each item (required for list/grid layouts)"
  )

  slot(:filter,
    required: false,
    doc: "Filter-only slots for filtering without display columns"
  ) do
    attr(:field, :string,
      required: true,
      doc: "Field name to filter on"
    )

    attr(:type, :atom, doc: "Filter type (:text, :select, :boolean, :date_range, etc.)")
    attr(:label, :string, doc: "Custom filter label")
    attr(:options, :list, doc: "Options for select/multi_select filters")
    attr(:value, :any, doc: "Default or fixed value for checkbox filters")
    attr(:operator, :atom, doc: "Filter operator (:eq, :contains, :gt, etc.)")
    attr(:case_sensitive, :boolean, doc: "Whether text filtering is case-sensitive")
    attr(:placeholder, :string, doc: "Placeholder text for filter input")
    attr(:labels, :map, doc: "Custom labels for boolean filter options")
    attr(:prompt, :string, doc: "Prompt text for select filters")
    attr(:match_mode, :atom, doc: "Match mode for multi-value filters (:any or :all)")
    attr(:format, :string, doc: "Date format for date filters")
    attr(:include_time, :boolean, doc: "Whether to include time in date filters")
    attr(:step, :any, doc: "Step value for number range filters")
    attr(:min, :any, doc: "Minimum value for range filters")
    attr(:max, :any, doc: "Maximum value for range filters")
    attr(:fn, :fun, doc: "Custom filter function (fn query, filter_config -> query)")
  end

  def collection(assigns) do
    assigns =
      assigns
      |> assign_new(:id, fn -> "cinder-collection" end)
      |> assign_new(:layout, fn -> :table end)
      |> assign_new(:page_size, fn -> 25 end)
      |> assign_new(:theme, fn -> "default" end)
      |> assign_new(:url_state, fn -> false end)
      |> assign_new(:query_opts, fn -> [] end)
      |> assign_new(:on_state_change, fn -> nil end)
      |> assign_new(:show_pagination, fn -> true end)
      |> assign_new(:loading_message, fn -> "Loading..." end)
      |> assign_new(:filters_label, fn -> "🔍 Filters" end)
      |> assign_new(:sort_label, fn -> "Sort by:" end)
      |> assign_new(:empty_message, fn -> "No results found" end)
      |> assign_new(:class, fn -> "" end)
      |> assign_new(:container_class, fn -> nil end)
      |> assign_new(:tenant, fn -> nil end)
      |> assign_new(:scope, fn -> nil end)
      |> assign_new(:search, fn -> nil end)
      |> assign_new(:grid_columns, fn -> nil end)
      |> assign_new(:pagination, fn -> :offset end)

    # Validate and normalize query/resource parameters
    normalized_query = normalize_query_params(assigns[:resource], assigns[:query])
    resource = extract_resource_from_query(normalized_query)

    # Process columns
    processed_columns = process_columns(assigns.col, resource)

    # Process filter slots if present
    processed_filter_slots = process_filter_slots(Map.get(assigns, :filter, []), resource)

    # Build query columns (columns used for filtering and searching)
    query_columns = build_query_columns(processed_columns, processed_filter_slots)

    # Process unified search configuration
    {search_label, search_placeholder, search_enabled, search_fn} =
      process_search_config(assigns.search, processed_columns)

    # Determine if filters should be shown
    show_filters = determine_show_filters(assigns, query_columns, search_enabled)

    # Determine if sort controls should be shown (for list/grid layouts)
    show_sort = determine_show_sort(assigns, processed_columns)

    # Parse page_size configuration
    page_size_config = parse_page_size_config(assigns.page_size)

    # Parse pagination mode
    pagination_mode = parse_pagination_mode(assigns.pagination)

    # Select renderer based on layout (support both atoms and strings)
    layout = normalize_layout(assigns.layout)
    renderer = get_renderer(layout)

    # Get the item slot for list/grid layouts
    item_slot = Map.get(assigns, :item, [])

    # Resolve theme
    resolved_theme = resolve_theme(assigns.theme)

    # Map click to layout-specific attributes
    {row_click, item_click} = map_click_to_layout(assigns.click, layout)

    # Build final assigns for template
    assigns =
      assigns
      |> assign(:normalized_query, normalized_query)
      |> assign(:processed_columns, processed_columns)
      |> assign(:query_columns, query_columns)
      |> assign(:page_size_config, page_size_config)
      |> assign(:search_label, search_label)
      |> assign(:search_placeholder, search_placeholder)
      |> assign(:search_enabled, search_enabled)
      |> assign(:search_fn, search_fn)
      |> assign(:show_filters, show_filters)
      |> assign(:show_sort, show_sort)
      |> assign(:pagination_mode, pagination_mode)
      |> assign(:renderer, renderer)
      |> assign(:item_slot, item_slot)
      |> assign(:row_click, row_click)
      |> assign(:item_click, item_click)
      |> assign(:resolved_theme, resolved_theme)
      |> assign(:layout, layout)

    ~H"""
    <div class={[layout_class(@layout), @class]}>
      <.live_component
        module={Cinder.LiveComponent}
        id={@id}
        renderer={@renderer}
        query={@normalized_query}
        actor={@actor}
        tenant={@tenant}
        scope={@scope}
        page_size_config={@page_size_config}
        theme={@resolved_theme}
        url_filters={get_url_filters(@url_state)}
        url_page={get_url_page(@url_state)}
        url_sort={get_url_sort(@url_state)}
        url_raw_params={get_raw_url_params(@url_state)}
        query_opts={@query_opts}
        on_state_change={get_state_change_handler(@url_state, @on_state_change, @id)}
        show_filters={@show_filters}
        show_sort={@show_sort}
        show_pagination={@show_pagination}
        loading_message={@loading_message}
        filters_label={@filters_label}
        sort_label={@sort_label}
        empty_message={@empty_message}
        col={@processed_columns}
        query_columns={@query_columns}
        row_click={@row_click}
        item_click={@item_click}
        item_slot={@item_slot}
        container_class={@container_class}
        grid_columns={@grid_columns}
        search_enabled={@search_enabled}
        search_label={@search_label}
        search_placeholder={@search_placeholder}
        search_fn={@search_fn}
        pagination_mode={@pagination_mode}
        id_field={@id_field}
      />
    </div>
    """
  end

  # ============================================================================
  # PUBLIC PROCESSING FUNCTIONS
  # These are used by Table for backward compatibility
  # ============================================================================

  @doc """
  Process column definitions into the format expected by the underlying component.
  """
  def process_columns(col_slots, resource) do
    Enum.map(col_slots, fn slot ->
      field = Map.get(slot, :field)
      filter_attr = Map.get(slot, :filter, false)
      sort_attr = Map.get(slot, :sort, false)

      # Validate field requirement for filtering/sorting
      validate_field_requirement!(slot, field, filter_attr, sort_attr)

      # Extract custom functions from unified configurations
      sort_config = extract_sort_config(sort_attr)
      filter_fn = if is_list(filter_attr), do: Keyword.get(filter_attr, :fn), else: nil

      # Use Column module to parse the column configuration
      column_config = %{
        field: field,
        sortable: sort_config.enabled,
        filterable: filter_attr != false,
        class: Map.get(slot, :class, ""),
        filter_fn: filter_fn,
        search: Map.get(slot, :search, false)
      }

      # Let Column module infer filter type if needed, otherwise use explicit type
      {filter_type, filter_options_from_unified} =
        determine_filter_type(filter_attr, field, resource)

      # Check for deprecated filter_options usage
      legacy_filter_options = Map.get(slot, :filter_options, [])

      if legacy_filter_options != [] do
        field_name = field || "unknown"

        Logger.warning(
          "[DEPRECATED] Field '#{field_name}' uses deprecated filter_options attribute. Use `filter={[type: #{inspect(filter_type)}, ...]}` instead."
        )
      end

      # Merge options: unified format takes precedence over legacy filter_options
      merged_filter_options = Keyword.merge(legacy_filter_options, filter_options_from_unified)

      column_config =
        case filter_type do
          :auto ->
            Map.put(column_config, :filter_options, merged_filter_options)

          explicit_type ->
            column_config
            |> Map.put(:filter_type, explicit_type)
            |> Map.put(:filter_options, merged_filter_options)
        end

      # Parse through Column module for intelligent defaults (only if field exists)
      parsed_column =
        if field do
          Cinder.Column.parse_column(column_config, resource)
        else
          # For action columns without fields, provide sensible defaults
          %{
            label: Map.get(slot, :label, ""),
            filterable: false,
            filter_type: :text,
            filter_options: [],
            sortable: false,
            filter_fn: nil,
            searchable: false,
            sort_cycle: [nil, :asc, :desc]
          }
        end

      # Create slot in internal format with proper label handling
      # Note: We store the original slot for render_slot compatibility in renderers.
      # Phoenix's render_slot expects the full slot structure, not just inner_block.
      %{
        field: field,
        label: Map.get(slot, :label, parsed_column.label),
        filterable: parsed_column.filterable,
        filter_type: parsed_column.filter_type,
        filter_options: parsed_column.filter_options,
        sortable: parsed_column.sortable,
        class: Map.get(slot, :class, ""),
        inner_block: slot[:inner_block] || default_inner_block(field),
        slot: slot,
        filter_fn: parsed_column.filter_fn,
        searchable: parsed_column.searchable,
        sort_cycle: sort_config.cycle || [nil, :asc, :desc],
        __slot__: :col
      }
    end)
  end

  @doc """
  Process filter-only slot definitions into the format expected by the filter system.
  """
  def process_filter_slots(filter_slots, resource) do
    Enum.map(filter_slots, fn slot ->
      field = Map.get(slot, :field)
      filter_type = Map.get(slot, :type)
      filter_options = Map.get(slot, :options, [])
      filter_value = Map.get(slot, :value)
      label = Map.get(slot, :label)
      # Extract custom filter function from slot (like process_columns does)
      filter_fn = Map.get(slot, :fn)

      # Extract all filter-specific options
      extra_options =
        [
          operator: Map.get(slot, :operator),
          case_sensitive: Map.get(slot, :case_sensitive),
          placeholder: Map.get(slot, :placeholder),
          labels: Map.get(slot, :labels),
          prompt: Map.get(slot, :prompt),
          match_mode: Map.get(slot, :match_mode),
          format: Map.get(slot, :format),
          include_time: Map.get(slot, :include_time),
          step: Map.get(slot, :step),
          min: Map.get(slot, :min),
          max: Map.get(slot, :max),
          options: filter_options,
          fn: Map.get(slot, :fn)
        ]
        |> Enum.filter(fn {_key, value} -> value != nil end)

      # Validate required attributes
      if is_nil(field) or field == "" do
        raise ArgumentError, "Filter slot missing required :field attribute"
      end

      # Build filter configuration in unified format for determine_filter_type
      base_options = if filter_value, do: [value: filter_value], else: []
      all_options = base_options ++ extra_options ++ (filter_options || [])

      filter_config =
        if filter_type do
          [type: filter_type] ++ all_options
        else
          true
        end

      # Let Column module infer filter type if needed, otherwise use explicit type
      {determined_filter_type, filter_options_from_type} =
        determine_filter_type(filter_config, field, resource)

      # Merge options
      merged_filter_options =
        if Keyword.keyword?(filter_options_from_type) do
          Keyword.merge(filter_options_from_type, all_options)
        else
          filter_options_from_type ++ all_options
        end

      # Build column config for filter processing
      column_config = %{
        field: field,
        filterable: true,
        sortable: false,
        class: "",
        filter_fn: filter_fn,
        search: false
      }

      column_config =
        case determined_filter_type do
          :auto ->
            Map.put(column_config, :filter_options, merged_filter_options)

          explicit_type ->
            column_config
            |> Map.put(:filter_type, explicit_type)
            |> Map.put(:filter_options, merged_filter_options)
        end

      # Parse through Column module for validation and intelligent defaults
      parsed_column = Cinder.Column.parse_column(column_config, resource)

      # Create filter slot in internal format
      %{
        field: field,
        label: label || parsed_column.label,
        filterable: true,
        filter_type: parsed_column.filter_type,
        filter_options: parsed_column.filter_options,
        sortable: false,
        class: "",
        inner_block: nil,
        filter_fn: parsed_column.filter_fn,
        searchable: false,
        sort_cycle: [nil, :asc, :desc],
        __slot__: :filter
      }
    end)
  end

  @doc """
  Builds the list of columns used for query operations (filtering AND searching).

  This function combines:
  - **Filterable columns**: needed for filter application
  - **Searchable columns**: needed for search even if not filterable
  - **Filter-only slots**: dedicated filter controls not tied to display columns

  NOTE: Sortable-only columns are NOT included here - sorting uses display_columns
  because sort controls are tied to column headers.

  Raises `ArgumentError` if the same field is defined in both a filterable column
  and a filter-only slot.
  """
  def build_query_columns(processed_columns, processed_filter_slots) do
    validate_no_field_conflicts!(processed_columns, processed_filter_slots)

    # Include columns that participate in query operations (filter OR search)
    query_relevant_columns =
      Enum.filter(processed_columns, fn col ->
        col.filterable or Map.get(col, :searchable, false)
      end)

    query_relevant_columns ++ processed_filter_slots
  end

  # Kept for backward compatibility - delegates to build_query_columns
  @doc false
  def merge_filter_configurations(processed_columns, processed_filter_slots) do
    build_query_columns(processed_columns, processed_filter_slots)
  end

  defp validate_no_field_conflicts!(processed_columns, processed_filter_slots) do
    column_fields =
      processed_columns
      |> Enum.filter(& &1.filterable)
      |> Enum.map(& &1.field)
      |> MapSet.new()

    filter_slot_fields =
      processed_filter_slots
      |> Enum.map(& &1.field)
      |> MapSet.new()

    conflicts = MapSet.intersection(column_fields, filter_slot_fields)

    if MapSet.size(conflicts) > 0 do
      conflict_list = MapSet.to_list(conflicts)

      raise ArgumentError,
            "Field conflict detected: #{inspect(conflict_list)}. " <>
              "Fields cannot be defined in both :col (with filter enabled) and :filter slots. " <>
              "Use either column filtering or filter-only slots, not both for the same field."
    end

    :ok
  end

  @doc """
  Process unified search configuration into individual components.
  Returns {label, placeholder, enabled, search_fn}.
  """
  def process_search_config(search_config, columns) do
    has_searchable_columns = Enum.any?(columns, & &1.searchable)

    case search_config do
      nil ->
        if has_searchable_columns do
          {"Search", "Search...", true, nil}
        else
          {nil, nil, false, nil}
        end

      false ->
        {nil, nil, false, nil}

      config when is_list(config) ->
        label = Keyword.get(config, :label, "Search")
        placeholder = Keyword.get(config, :placeholder, "Search...")
        search_fn = Keyword.get(config, :fn)
        {label, placeholder, true, search_fn}

      _invalid ->
        if has_searchable_columns do
          {"Search", "Search...", true, nil}
        else
          {nil, nil, false, nil}
        end
    end
  end

  # ============================================================================
  # PRIVATE HELPERS - Renderers and Layout
  # ============================================================================

  defp get_renderer(:table), do: Cinder.Renderers.Table
  defp get_renderer(:list), do: Cinder.Renderers.List
  defp get_renderer(:grid), do: Cinder.Renderers.Grid

  defp get_renderer(layout) do
    Logger.warning("Unknown layout #{inspect(layout)}, falling back to :table")
    Cinder.Renderers.Table
  end

  defp normalize_layout("table"), do: :table
  defp normalize_layout("list"), do: :list
  defp normalize_layout("grid"), do: :grid
  defp normalize_layout(layout) when is_atom(layout), do: layout
  defp normalize_layout(_), do: :table

  defp layout_class(:table), do: "cinder-table"
  defp layout_class(:list), do: "cinder-list"
  defp layout_class(:grid), do: "cinder-grid"
  defp layout_class(_), do: "cinder-collection"

  defp map_click_to_layout(click, :table), do: {click, nil}
  defp map_click_to_layout(click, :list), do: {nil, click}
  defp map_click_to_layout(click, :grid), do: {nil, click}
  defp map_click_to_layout(click, _), do: {click, nil}

  # ============================================================================
  # PRIVATE HELPERS - Query and Resource
  # ============================================================================

  defp normalize_query_params(nil, nil) do
    raise ArgumentError, "Either :resource or :query must be provided"
  end

  defp normalize_query_params(resource, nil) when not is_nil(resource), do: resource
  defp normalize_query_params(nil, query) when not is_nil(query), do: query

  defp normalize_query_params(resource, query) when not is_nil(resource) and not is_nil(query) do
    Logger.warning(
      "Both :resource and :query provided to Cinder.collection. Using :query and ignoring :resource."
    )

    query
  end

  defp extract_resource_from_query(%Ash.Query{resource: resource}), do: resource
  defp extract_resource_from_query(resource) when is_atom(resource), do: resource
  defp extract_resource_from_query(_), do: nil

  # ============================================================================
  # PRIVATE HELPERS - Show/Hide Logic
  # ============================================================================

  defp determine_show_filters(%{show_filters: explicit}, _columns, _search_enabled)
       when is_boolean(explicit) do
    explicit
  end

  defp determine_show_filters(_assigns, columns, search_enabled) do
    has_filterable = Enum.any?(columns, & &1.filterable)
    has_filterable or search_enabled
  end

  defp determine_show_sort(%{show_sort: explicit}, _columns) when is_boolean(explicit) do
    explicit
  end

  defp determine_show_sort(_assigns, columns) do
    Enum.any?(columns, & &1.sortable)
  end

  # ============================================================================
  # PRIVATE HELPERS - Page Size
  # ============================================================================

  defp parse_page_size_config(page_size) when is_integer(page_size) do
    %{
      selected_page_size: page_size,
      page_size_options: [],
      default_page_size: page_size,
      configurable: false
    }
  end

  defp parse_page_size_config(config) when is_list(config) do
    default = Keyword.get(config, :default, 25)
    options = Keyword.get(config, :options, [])

    valid_options =
      if is_list(options) and Enum.all?(options, &is_integer/1) do
        options
      else
        []
      end

    configurable = length(valid_options) > 1

    %{
      selected_page_size: default,
      page_size_options: valid_options,
      default_page_size: default,
      configurable: configurable
    }
  end

  defp parse_page_size_config(_invalid), do: parse_page_size_config(25)

  # ============================================================================
  # PRIVATE HELPERS - Pagination Mode
  # ============================================================================

  defp parse_pagination_mode(:offset), do: :offset
  defp parse_pagination_mode(:keyset), do: :keyset
  defp parse_pagination_mode("offset"), do: :offset
  defp parse_pagination_mode("keyset"), do: :keyset
  defp parse_pagination_mode(_invalid), do: :offset

  # ============================================================================
  # PRIVATE HELPERS - Theme
  # ============================================================================

  defp resolve_theme("default") do
    default_theme = Cinder.Theme.get_default_theme()
    Cinder.Theme.merge(default_theme)
  end

  defp resolve_theme(theme) when is_binary(theme), do: Cinder.Theme.merge(theme)

  defp resolve_theme(theme) when is_atom(theme) and not is_nil(theme) do
    Cinder.Theme.merge(theme)
  end

  defp resolve_theme(nil) do
    default_theme = Cinder.Theme.get_default_theme()
    Cinder.Theme.merge(default_theme)
  end

  defp resolve_theme(_), do: Cinder.Theme.merge("default")

  # ============================================================================
  # PRIVATE HELPERS - URL State
  # ============================================================================

  defp get_url_filters(url_state) when is_map(url_state), do: Map.get(url_state, :filters, %{})
  defp get_url_filters(_), do: %{}

  defp get_url_page(url_state) when is_map(url_state), do: Map.get(url_state, :current_page, nil)
  defp get_url_page(_), do: nil

  defp get_url_sort(url_state) when is_map(url_state) do
    case Map.get(url_state, :sort_by, []) do
      [] -> nil
      sort -> sort
    end
  end

  defp get_url_sort(_), do: nil

  defp get_raw_url_params(url_state) when is_map(url_state) do
    Map.get(url_state, :filters, %{})
  end

  defp get_raw_url_params(_), do: %{}

  defp get_state_change_handler(url_state, custom_handler, _component_id)
       when is_map(url_state) do
    custom_handler || :table_state_change
  end

  defp get_state_change_handler(_url_state, custom_handler, _component_id), do: custom_handler

  # ============================================================================
  # PRIVATE HELPERS - Column Processing
  # ============================================================================

  defp extract_sort_config(sort_attr) do
    case sort_attr do
      true ->
        %{enabled: true, cycle: nil}

      false ->
        %{enabled: false, cycle: nil}

      config when is_list(config) ->
        %{
          enabled: Keyword.get(config, :enabled, true),
          cycle: Keyword.get(config, :cycle)
        }

      _ ->
        %{enabled: false, cycle: nil}
    end
  end

  defp determine_filter_type(filter_attr, field, _resource) do
    case filter_attr do
      false ->
        {:text, []}

      true ->
        {:auto, []}

      filter_type when is_atom(filter_type) ->
        validate_filter_type!(filter_type, field)
        {filter_type, []}

      filter_type when is_binary(filter_type) ->
        normalized_type = String.to_atom(filter_type)
        validate_filter_type!(normalized_type, field)
        {normalized_type, []}

      filter_config when is_list(filter_config) ->
        type = Keyword.get(filter_config, :type, :auto)
        normalized_type = if is_binary(type), do: String.to_atom(type), else: type
        validate_filter_type!(normalized_type, field)
        options = Keyword.delete(filter_config, :type)
        {normalized_type, options}

      _ ->
        {:text, []}
    end
  end

  defp validate_filter_type!(:auto, _field), do: :ok

  defp validate_filter_type!(filter_type, field) do
    unless Cinder.Filters.Registry.registered?(filter_type) do
      available = Cinder.Filters.Registry.all_filters_with_custom() |> Map.keys() |> Enum.sort()

      raise ArgumentError,
            "Invalid filter type #{inspect(filter_type)} for field #{inspect(field)}. " <>
              "Available types: #{Enum.map_join(available, ", ", &inspect/1)}"
    end
  end

  defp validate_field_requirement!(_slot, field, filter_attr, sort_attr) do
    field_required = filter_attr != false or sort_attr == true

    if field_required and (is_nil(field) or field == "") do
      filter_msg = if filter_attr != false, do: " filter", else: ""
      sort_msg = if sort_attr == true, do: " sort", else: ""

      raise ArgumentError, """
      Cinder collection column with#{filter_msg}#{sort_msg} attribute(s) requires a 'field' attribute.

      Either:
      - Add a field: <:col field="field_name"#{filter_msg}#{sort_msg}>
      - Remove#{filter_msg}#{sort_msg} attribute(s) for action columns: <:col>
      """
    end
  end

  defp default_inner_block(field) do
    if field do
      fn item -> get_field_value(item, field) end
    else
      fn _item -> nil end
    end
  end

  defp get_field_value(item, field) when is_binary(field) do
    case String.split(field, ".", parts: 2) do
      [single_field] ->
        get_in(item, [Access.key(String.to_atom(single_field))])

      [relationship, nested_field] ->
        case get_in(item, [Access.key(String.to_atom(relationship))]) do
          nil -> nil
          related_item -> get_field_value(related_item, nested_field)
        end
    end
  end

  defp get_field_value(item, field), do: get_in(item, [Access.key(field)])
end
