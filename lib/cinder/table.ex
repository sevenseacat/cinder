defmodule Cinder.Table do
  require Logger

  @moduledoc """
  Simplified Cinder table component with intelligent defaults.

  This is the new, simplified API for Cinder tables that leverages automatic
  type inference and smart defaults while providing a clean, Phoenix LiveView-like interface.

  ## Basic Usage

  ### With Resource Parameter (Simple)

  ```heex
  <Cinder.Table.table resource={MyApp.User} actor={@current_user}>
    <:col :let={user} field="name" filter sort>{user.name}</:col>
    <:col :let={user} field="email" filter>{user.email}</:col>
    <:col :let={user} field="created_at" sort>{user.created_at}</:col>
  </Cinder.Table.table>
  ```

  ### With Query Parameter (Advanced)

  ```heex
  <!-- Using resource as query -->
  <Cinder.Table.table query={MyApp.User} actor={@current_user}>
    <:col :let={user} field="name" filter sort>{user.name}</:col>
    <:col :let={user} field="email" filter>{user.email}</:col>
    <:col :let={user} field="created_at" sort>{user.created_at}</:col>
  </Cinder.Table.table>

  <!-- Pre-configured query with custom read action -->
  <Cinder.Table.table query={Ash.Query.for_read(MyApp.User, :active_users)} actor={@current_user}>
    <:col :let={user} field="name" filter sort>{user.name}</:col>
    <:col :let={user} field="email" filter>{user.email}</:col>
    <:col :let={user} field="created_at" sort>{user.created_at}</:col>
  </Cinder.Table.table>

  <!-- Query with base filters -->
  <Cinder.Table.table query={MyApp.User |> Ash.Query.filter(department: "Engineering")} actor={@current_user}>
    <:col :let={user} field="name" filter sort>{user.name}</:col>
    <:col :let={user} field="email" filter>{user.email}</:col>
    <:col :let={user} field="department.name" filter>{user.department.name}</:col>
    <:col :let={user} field="profile__country" filter>{user.profile.country}</:col>
  </Cinder.Table.table>
  ```

  ## Field Types

  ### Relationship Fields

  Use dot notation to access related resource fields:

  ```heex
  <:col :let={user} field="department.name" filter sort>{user.department.name}</:col>
  <:col :let={user} field="manager.email" filter>{user.manager.email}</:col>
  <:col :let={user} field="office.building.address" filter>{user.office.building.address}</:col>
  ```

  ### Embedded Resource Fields

  Use double underscore notation for embedded resource fields:

  ```heex
  <:col :let={user} field="profile__bio" filter>{user.profile.bio}</:col>
  <:col :let={user} field="settings__country" filter>{user.settings.country}</:col>
  <:col :let={user} field="metadata__preferences__theme" filter>{user.metadata.preferences.theme}</:col>
  ```

  Embedded enum fields are automatically detected and rendered as select filters:

  ```heex
  <!-- If profile.country is an Ash.Type.Enum, this becomes a select filter -->
  <:col :let={user} field="profile__country" filter>{user.profile.country}</:col>
  ```

  ## Search Configuration

  Search is automatically enabled when columns have the `search` attribute:

  ```heex
  <Cinder.Table.table resource={MyApp.Album} actor={@current_user}>
    <:col :let={album} field="title" filter search>{album.title}</:col>
    <:col :let={album} field="artist.name" filter search>{album.artist.name}</:col>
    <:col :let={album} field="genre" filter>{album.genre}</:col>
  </Cinder.Table.table>
  ```

  Customize search label and placeholder:

  ```heex
  <Cinder.Table.table
    resource={MyApp.Album}
    actor={@current_user}
    search={[label: "Find Albums", placeholder: "Search by title or artist..."]}
  >
    <:col :let={album} field="title" search>{album.title}</:col>
    <:col :let={album} field="artist.name" search>{album.artist.name}</:col>
  </Cinder.Table.table>
  ```

  Explicitly disable search even with searchable columns:

  ```heex
  <Cinder.Table.table resource={MyApp.Album} search={false}>
    <:col :let={album} field="title" search>{album.title}</:col>
  </Cinder.Table.table>
  ```

  ## Advanced Configuration

  ```heex
  <Cinder.Table.table
    resource={MyApp.Album}
    actor={@current_user}
    url_state={@url_state}
    page_size={50}
    theme="modern"
  >
    <:col :let={album} field="title" filter sort class="w-1/2">
      {album.title}
    </:col>
    <:col :let={album} field="artist.name" filter sort>
      {album.artist.name}
    </:col>
    <:col :let={album} field="genre" filter={:select}>
      {album.genre}
    </:col>
  </Cinder.Table.table>
  ```

  ## Configurable Page Sizes

  Allow users to select their preferred page size:

  ```heex
  <Cinder.Table.table
    resource={MyApp.User}
    actor={@current_user}
    page_size={[default: 25, options: [10, 25, 50, 100]]}
  >
    <:col :let={user} field="name" filter sort>{user.name}</:col>
    <:col :let={user} field="email" filter>{user.email}</:col>
    <:col :let={user} field="department.name" filter sort>{user.department.name}</:col>
  </Cinder.Table.table>
  ```

  The page size selector appears automatically when multiple options are provided.
  For fixed page sizes, use: `page_size={25}`

  ## Complex Query Examples

  ```heex
  <!-- Admin interface with authorization and tenant -->
  <Cinder.Table.table
    query={MyApp.User
      |> Ash.Query.for_read(:admin_read, %{}, actor: @actor, authorize?: @authorizing)
      |> Ash.Query.set_tenant(@tenant)
      |> Ash.Query.filter(active: true)}
    actor={@actor}>
    <:col :let={user} field="name" filter sort>{user.name}</:col>
    <:col :let={user} field="email" filter>{user.email}</:col>
    <:col :let={user} field="last_login" sort>{user.last_login}</:col>
    <:col :let={user} field="role" filter={:select}>{user.role}</:col>
  </Cinder.Table.table>
  ```

  ## Multi-Tenant Examples

  ```heex
  <!-- Simple tenant support -->
  <Cinder.Table.table
    resource={MyApp.User}
    actor={@current_user}
    tenant={@tenant}>
    <:col :let={user} field="name" filter sort>{user.name}</:col>
    <:col :let={user} field="email" filter>{user.email}</:col>
  </Cinder.Table.table>

  <!-- Using Ash scope (only actor and tenant are extracted) -->
  <Cinder.Table.table
    resource={MyApp.User}
    scope={%{actor: @current_user, tenant: @tenant}}>
    <:col :let={user} field="name" filter sort>{user.name}</:col>
    <:col :let={user} field="email" filter>{user.email}</:col>
  </Cinder.Table.table>

  <!-- Custom scope struct -->
  <Cinder.Table.table
    resource={MyApp.User}
    scope={@my_scope}>
    <:col :let={user} field="name" filter sort>{user.name}</:col>
    <:col :let={user} field="email" filter>{user.email}</:col>
  </Cinder.Table.table>

  <!-- Mixed usage (explicit overrides scope) -->
  <Cinder.Table.table
    resource={MyApp.User}
    scope={@scope}
    actor={@different_actor}>
    <:col :let={user} field="name" filter sort>{user.name}</:col>
    <:col :let={user} field="email" filter>{user.email}</:col>
  </Cinder.Table.table>
  ```

  ## Features

  - **Automatic type inference** from Ash resources
  - **Intelligent filtering** with automatic filter type detection
  - **URL state management** with browser back/forward support
  - **Relationship support** using dot notation (e.g., `artist.name`)
  - **Flexible theming** with built-in presets
  """

  use Phoenix.LiveComponent

  @doc ~S"""
  Renders a data table with intelligent defaults.

  ## Attributes

  ### Resource/Query (Choose One)
  - `resource` - Ash resource module to query (use either resource or query, not both)
  - `query` - Ash query to execute (use either resource or query, not both)

  ### Required
  - `actor` - Actor for authorization (can be nil)

  ### Authorization & Tenancy
  - `tenant` - Tenant for multi-tenant resources (default: nil)
  - `scope` - Ash scope containing actor and tenant (default: nil)

  ### Optional Configuration
  - `id` - Component ID (defaults to "cinder-table")
  - `page_size` - Number of items per page (default: 25)
  - `theme` - Theme preset or custom theme map (default: "default")
  - `url_state` - URL state object from UrlSync.handle_params, or false to disable URL synchronization
  - `query_opts` - Additional query options for Ash (default: [])
  - `on_state_change` - Callback for state changes
  - `show_filters` - Show filter controls (default: auto-detect from columns)
  - `show_pagination` - Show pagination controls (default: true)
  - `loading_message` - Custom loading message
  - `filters_label` - Custom label for filtering (default: "🔍 Filters")
  - `empty_message` - Custom empty state message
  - `class` - Additional CSS classes

  ## When to Use Resource vs Query

  **Use `resource` for:**
  - Simple tables with default read actions
  - Getting started quickly
  - Standard use cases without custom requirements

  **Use `query` for:**
  - Custom read actions (e.g., `:active_users`, `:admin_only`)
  - Pre-filtering data with base filters
  - Custom authorization settings
  - Tenant-specific queries
  - Admin interfaces with complex requirements
  - Integration with existing Ash query pipelines

  ## Column Slot

  The `:col` slot supports these attributes:

  - `field` (required) - Field name or relationship path (e.g., "user.name")
  - `filter` - Enable filtering (boolean or filter type atom)
  - `sort` - Enable sorting (boolean)
  - `class` - CSS classes for this column
  - `label` - Column header label (auto-generated from field name if not provided)

  Filter types: `:text`, `:select`, `:multi_select`, `:multi_checkboxes`, `:boolean`, `:checkbox`, `:date_range`, `:number_range`

  **Filter Type Selection:**
  - `:multi_select` - Modern tag-based interface with dropdown (default for array types)
    - Supports `match_mode: :any` (default) for OR logic or `match_mode: :all` for AND logic
  - `:multi_checkboxes` - Traditional checkbox interface for multiple selection
    - Supports `match_mode: :any` (default) for OR logic or `match_mode: :all` for AND logic
  - `:boolean` - Radio buttons for true/false selection (default for boolean fields)
  - `:checkbox` - Single checkbox for "show only X" filtering
    - For boolean fields: defaults to filtering for `true` when checked
    - For non-boolean fields: requires explicit `value` option

  ## Filter Slot

  The `:filter` slot allows filtering on fields that are not displayed in the table:

  ```heex
  <:filter field="created_at" type="date_range" label="Creation Date" />
  <:filter field="department" type="select" options={["Sales", "Marketing"]} />
  ```

  The `:filter` slot supports these attributes:

  **Universal attributes (all filter types):**
  - `field` (required) - Field name or relationship path (e.g., "user.name")
  - `type` - Filter type (e.g., `:select`, `:text`, `:date_range`) - auto-detected if not provided
  - `label` - Filter label (auto-generated from field name if not provided)
  - `fn` - Custom filter function

  **Filter type specific attributes:**

  **Text filters (`:text`):**
  - `operator` - Operator (`:contains`, `:starts_with`, `:ends_with`, `:equals`)
  - `case_sensitive` - Whether filter should be case sensitive
  - `placeholder` - Placeholder text for input

  **Select filters (`:select`):**
  - `options` - Options list (e.g., `[{"Label", "value"}]`)
  - `prompt` - Prompt text ("Choose..." style text)

  **Multi-select filters (`:multi_select`, `:multi_checkboxes`):**
  - `options` - Options list (e.g., `[{"Label", "value"}]`)
  - `match_mode` - Match mode (`:any` for OR logic, `:all` for AND logic)
  - `prompt` - Prompt text (`:multi_select` only)

  **Boolean filters (`:boolean`):**
  - `labels` - Custom labels (map with `:true`, `:false` keys)

  **Checkbox filters (`:checkbox`):**
  - `value` - Filter value when checked
  - `label` - Display text (required for checkbox)

  **Date range filters (`:date_range`):**
  - `format` - Format (`:date` or `:datetime`)
  - `include_time` - Whether to include time selection

  **Number range filters (`:number_range`):**
  - `step` - Step value for inputs
  - `min` - Minimum allowed value
  - `max` - Maximum allowed value

  Filter-only slots use the same filter types and options as column filters, but are purely for filtering without displaying the field in the table.

  ## Column Labels

  Column labels are automatically generated from field names using intelligent humanization:
  - `name` → "Name"
  - `email_address` → "Email Address"
  - `user.name` → "User Name"
  - `created_at` → "Created At"

  You can override the auto-generated label by providing a `label` attribute.

  ## Row Click Functionality

  Tables can be made interactive by providing a `row_click` function that will be
  executed when a row is clicked:

  ```heex
  <Cinder.Table.table
    resource={MyApp.Item}
    actor={@current_user}
    row_click={fn item -> JS.navigate(~p"/items/#{item.id}") end}
  >
    <:col :let={item} field="name" filter sort>{item.name}</:col>
    <:col :let={item} field="description">{item.description}</:col>
  </Cinder.Table.table>
  ```

  The `row_click` function receives the row item as its argument and should return
  a Phoenix.LiveView.JS command or similar action. When provided, rows will be
  styled to indicate they are clickable with hover effects and cursor changes.
  """

  use Phoenix.Component

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
  attr(:id, :string, default: "cinder-table", doc: "Unique identifier for the table")

  attr(:page_size, :any,
    default: 25,
    doc: "Number of items per page or [default: 25, options: [10, 25, 50]]"
  )

  attr(:theme, :any, default: "default", doc: "Theme name or theme map")

  attr(:url_state, :any,
    default: false,
    doc: "URL state object from UrlSync.handle_params, or false to disable"
  )

  attr(:query_opts, :list, default: [], doc: "Additional query options (load, select, etc.)")
  attr(:on_state_change, :any, default: nil, doc: "Custom state change handler")
  attr(:show_pagination, :boolean, default: true, doc: "Whether to show pagination controls")

  attr(:show_filters, :boolean,
    default: nil,
    doc: "Whether to show filter controls (auto-detected if nil)"
  )

  attr(:loading_message, :string, default: "Loading...", doc: "Message to show while loading")

  attr(:filters_label, :string,
    default: "🔍 Filters",
    doc: "Label for the filters component"
  )

  attr(:search, :any,
    default: nil,
    doc:
      "Search configuration. Auto-enables when searchable columns exist. Use [label: \"Custom\", placeholder: \"Custom...\"] to customize, [fn: my_search_fn] for custom search function, or false to disable."
  )

  attr(:empty_message, :string,
    default: "No results found",
    doc: "Message to show when no results"
  )

  attr(:class, :string, default: "", doc: "Additional CSS classes")

  attr(:row_click, :any,
    default: nil,
    doc: "Function to call when a row is clicked. Receives the row item as argument."
  )

  slot :col, required: true do
    attr(:field, :string,
      required: false,
      doc:
        "Field name (supports dot notation for relationships or `__` for embedded attributes). Required when filter or sort is enabled."
    )

    attr(:filter, :any,
      doc:
        "Enable filtering (true, false, filter type atom, or unified config [type: :select, options: [...], fn: &custom_filter/2])"
    )

    attr(:filter_options, :list,
      doc:
        "Custom filter options (e.g., [options: [{\"Label\", \"value\"}]]) - DEPRECATED: Use filter={[type: :select, options: [...]]} instead"
    )

    attr(:sort, :any,
      doc: "Enable sorting (true, false, or unified config [cycle: [nil, :asc, :desc]])"
    )

    attr(:search, :boolean,
      doc: "Enable global search on this column (makes column searchable in global search input)"
    )

    attr(:label, :string, doc: "Custom column label (auto-generated if not provided)")
    attr(:class, :string, doc: "CSS classes for this column")
  end

  slot :filter do
    attr(:field, :string,
      required: true,
      doc: "Field name (supports dot notation for relationships or `__` for embedded attributes)"
    )

    attr(:type, :any,
      required: false,
      doc: "Filter type as atom or string (e.g., :select, \"select\", :text, \"text\", etc.) - auto-detected if not provided"
    )

    attr(:options, :list,
      doc: "Filter options for select/multi-select filters"
    )

    attr(:value, :any,
      doc: "Filter value for checkbox filters"
    )

    attr(:operator, :atom,
      doc: "Text filter operator (:contains, :starts_with, :ends_with, :equals)"
    )

    attr(:case_sensitive, :boolean,
      doc: "Whether text filter should be case sensitive"
    )

    attr(:placeholder, :string,
      doc: "Placeholder text for input filters"
    )

    attr(:labels, :map,
      doc: "Custom labels for boolean filter (map with :true, :false keys)"
    )

    attr(:prompt, :string,
      doc: "Prompt text for select filters ('Choose...' style text)"
    )

    attr(:match_mode, :atom,
      doc: "Multi-select match mode (:any for OR logic, :all for AND logic)"
    )

    attr(:format, :atom,
      doc: "Date range format (:date or :datetime)"
    )

    attr(:include_time, :boolean,
      doc: "Whether date range should include time selection"
    )

    attr(:step, :any,
      doc: "Step value for number range filters"
    )

    attr(:min, :any,
      doc: "Minimum value for number range filters"
    )

    attr(:max, :any,
      doc: "Maximum value for number range filters"
    )

    attr(:fn, :any,
      doc: "Custom filter function"
    )

    attr(:label, :string, doc: "Custom filter label (auto-generated if not provided)")
  end

  def table(assigns) do
    # Set intelligent defaults
    assigns =
      assigns
      |> assign_new(:id, fn -> "cinder-table" end)
      |> assign_new(:page_size, fn -> 25 end)
      |> assign_new(:theme, fn -> "default" end)
      |> assign_new(:url_state, fn -> false end)
      |> assign_new(:query_opts, fn -> [] end)
      |> assign_new(:on_state_change, fn -> nil end)
      |> assign_new(:show_pagination, fn -> true end)
      |> assign_new(:loading_message, fn -> "Loading..." end)
      |> assign_new(:filters_label, fn -> "🔍 Filters" end)
      |> assign_new(:empty_message, fn -> "No results found" end)
      |> assign_new(:class, fn -> "" end)
      |> assign_new(:tenant, fn -> nil end)
      |> assign_new(:scope, fn -> nil end)
      |> assign_new(:search, fn -> nil end)

    # Resolve actor and tenant from scope and explicit attributes
    resolved_options = resolve_actor_and_tenant(assigns)

    # Validate and normalize query/resource parameters
    normalized_query = normalize_query_params(assigns.resource, assigns.query)
    resource = extract_resource_from_query(normalized_query)

    # Process columns and filter slots
    processed_columns = process_columns(assigns.col, resource)
    processed_filter_slots = process_filter_slots(Map.get(assigns, :filter, []), resource)

    # Merge columns and filter slots, checking for field conflicts
    all_filter_configs = merge_filter_configurations(processed_columns, processed_filter_slots)

    # Determine if filters should be shown
    show_filters = determine_show_filters(assigns, all_filter_configs)

    # Process unified search configuration after columns are processed
    {search_label, search_placeholder, search_enabled, search_fn} =
      process_search_config(assigns.search, processed_columns)

    # Parse page_size configuration
    page_size_config = parse_page_size_config(assigns.page_size)

    assigns =
      assigns
      |> assign(:normalized_query, normalized_query)
      |> assign(:processed_columns, processed_columns)
      |> assign(:all_filter_configs, all_filter_configs)
      |> assign(:resolved_options, resolved_options)
      |> assign(:page_size_config, page_size_config)
      |> assign(:search_label, search_label)
      |> assign(:search_placeholder, search_placeholder)
      |> assign(:search_enabled, search_enabled)
      |> assign(:search_fn, search_fn)
      |> assign(:show_filters, show_filters)

    ~H"""
    <div class={["cinder-table", @class]}>
      <.live_component
        module={Cinder.Table.LiveComponent}
        id={@id}
        query={@normalized_query}
        actor={@resolved_options.actor}
        tenant={@resolved_options.tenant}
        page_size_config={@page_size_config}
        theme={resolve_theme(@theme)}
        url_filters={get_url_filters(@url_state)}
        url_page={get_url_page(@url_state)}
        url_sort={get_url_sort(@url_state)}
        url_raw_params={get_raw_url_params(@url_state)}
        query_opts={@query_opts}
        on_state_change={get_state_change_handler(@url_state, @on_state_change, @id)}
        show_filters={@show_filters}
        show_pagination={@show_pagination}
        loading_message={@loading_message}
        filters_label={@filters_label}
        empty_message={@empty_message}
        col={@processed_columns}
        filter_configs={@all_filter_configs}
        row_click={@row_click}
        search_enabled={@search_enabled}
        search_label={@search_label}
        search_placeholder={@search_placeholder}
        search_fn={@search_fn}
      />
    </div>
    """
  end

  # Process column definitions into the format expected by the underlying component
  def process_columns(col_slots, resource) do
    Enum.map(col_slots, fn slot ->
      # Convert column slot to internal format using Column module
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
            # Let Column module infer the type from resource
            Map.put(column_config, :filter_options, merged_filter_options)

          explicit_type ->
            # Use the explicitly specified filter type
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
      %{
        field: field,
        label: Map.get(slot, :label, parsed_column.label),
        filterable: parsed_column.filterable,
        filter_type: parsed_column.filter_type,
        filter_options: parsed_column.filter_options,
        sortable: parsed_column.sortable,
        class: Map.get(slot, :class, ""),
        inner_block: slot[:inner_block] || default_inner_block(field),
        filter_fn: parsed_column.filter_fn,
        searchable: parsed_column.searchable,
        sort_cycle: sort_config.cycle || [nil, :asc, :desc],
        __slot__: :col
      }
    end)
  end

  # Process filter-only slot definitions into the format expected by the filter system
  @doc false
  def process_filter_slots(filter_slots, resource) do
    Enum.map(filter_slots, fn slot ->
      field = Map.get(slot, :field)
      filter_type = Map.get(slot, :type)
      filter_options = Map.get(slot, :options, [])
      filter_value = Map.get(slot, :value)
      label = Map.get(slot, :label)

      # Extract all filter-specific options
      extra_options = [
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

      filter_config = if filter_type do
        # Explicit type provided - build unified config with options
        [type: filter_type] ++ all_options
      else
        # No type specified - use auto-detection
        true
      end

      # Let Column module infer filter type if needed, otherwise use explicit type
      {determined_filter_type, filter_options_from_type} =
        determine_filter_type(filter_config, field, resource)

      # Merge options: type-inferred options as base, with any additional options
      # Handle both keyword lists and regular lists (like options tuples)
      merged_filter_options =
        if Keyword.keyword?(filter_options_from_type) do
          Keyword.merge(filter_options_from_type, all_options)
        else
          # If filter_options_from_type is not a keyword list (e.g. options list),
          # combine them as a regular list with our keyword options
          filter_options_from_type ++ all_options
        end

      # Build column config for filter processing
      column_config = %{
        field: field,
        filterable: true,
        sortable: false,
        class: "",
        filter_fn: nil,
        search: false
      }

      column_config =
        case determined_filter_type do
          :auto ->
            # Let Column module infer the type from resource
            Map.put(column_config, :filter_options, merged_filter_options)

          explicit_type ->
            # Use the explicitly specified filter type
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
        inner_block: nil,  # Filter slots don't render content
        filter_fn: parsed_column.filter_fn,
        searchable: false,
        sort_cycle: [nil, :asc, :desc],
        __slot__: :filter
      }
    end)
  end

  # Merge column filters and filter-only slots, checking for field conflicts
  @doc false
  def merge_filter_configurations(processed_columns, processed_filter_slots) do
    # Extract fields from columns that have filtering enabled
    column_fields =
      processed_columns
      |> Enum.filter(& &1.filterable)
      |> Enum.map(& &1.field)
      |> MapSet.new()

    # Extract fields from filter slots
    filter_slot_fields =
      processed_filter_slots
      |> Enum.map(& &1.field)
      |> MapSet.new()

    # Check for conflicts
    conflicts = MapSet.intersection(column_fields, filter_slot_fields)

    if MapSet.size(conflicts) > 0 do
      conflict_list = MapSet.to_list(conflicts)
      raise ArgumentError,
        "Field conflict detected: #{inspect(conflict_list)}. " <>
        "Fields cannot be defined in both :col (with filter enabled) and :filter slots. " <>
        "Use either column filtering or filter-only slots, not both for the same field."
    end

    # Merge all filterable configurations
    column_filters = Enum.filter(processed_columns, & &1.filterable)
    column_filters ++ processed_filter_slots
  end

  # Extract custom functions from unified sort configuration
  defp extract_sort_config(sort_attr) do
    case sort_attr do
      # Boolean values - standard behavior
      true ->
        %{enabled: true, cycle: nil}

      false ->
        %{enabled: false, cycle: nil}

      # Unified configuration: sort={[cycle: [...]]}
      config when is_list(config) ->
        %{
          enabled: Keyword.get(config, :enabled, true),
          cycle: Keyword.get(config, :cycle)
        }

      _ ->
        %{enabled: false, cycle: nil}
    end
  end

  defp determine_filter_type(filter_attr, _field, _resource) do
    case filter_attr do
      false ->
        {:text, []}

      # Let Column module infer the type
      true ->
        {:auto, []}

      filter_type when is_atom(filter_type) ->
        {filter_type, []}

      filter_type when is_binary(filter_type) ->
        # Convert string to atom - validation happens later in Column.validate/1
        {String.to_atom(filter_type), []}

      # New unified format: [type: :select, options: [...]]
      filter_config when is_list(filter_config) ->
        type = Keyword.get(filter_config, :type, :auto)
        # Convert string type to atom if needed
        normalized_type = if is_binary(type), do: String.to_atom(type), else: type
        # Extract all options except :type
        options = Keyword.delete(filter_config, :type)
        {normalized_type, options}

      _ ->
        {:text, []}
    end
  end

  # Validates that field is provided when filter or sort is enabled
  defp validate_field_requirement!(_slot, field, filter_attr, sort_attr) do
    field_required = filter_attr != false or sort_attr == true

    if field_required and (is_nil(field) or field == "") do
      filter_msg = if filter_attr != false, do: " filter", else: ""
      sort_msg = if sort_attr == true, do: " sort", else: ""

      raise ArgumentError, """
      Cinder table column with#{filter_msg}#{sort_msg} attribute(s) requires a 'field' attribute.

      Either:
      - Add a field: <:col field="field_name"#{filter_msg}#{sort_msg}>
      - Remove#{filter_msg}#{sort_msg} attribute(s) for action columns: <:col>
      """
    end
  end

  # Default inner block that renders the field value
  defp default_inner_block(field) do
    if field do
      fn item ->
        get_field_value(item, field)
      end
    else
      # For action columns without fields, return empty function
      fn _item -> nil end
    end
  end

  # Get field value with support for dot notation (relationships)
  defp get_field_value(item, field) when is_binary(field) do
    case String.split(field, ".", parts: 2) do
      [single_field] ->
        # Simple field access
        get_in(item, [Access.key(String.to_atom(single_field))])

      [relationship, nested_field] ->
        # Relationship field access
        case get_in(item, [Access.key(String.to_atom(relationship))]) do
          nil -> nil
          related_item -> get_field_value(related_item, nested_field)
        end
    end
  end

  defp get_field_value(item, field), do: get_in(item, [Access.key(field)])

  # Determine if filters should be shown automatically
  defp determine_show_filters(assigns, processed_columns) do
    case Map.get(assigns, :show_filters) do
      nil ->
        # Auto-detect: show filters if any column is filterable
        Enum.any?(processed_columns, & &1.filterable)

      show_filters ->
        show_filters
    end
  end

  # Resolve theme configuration
  defp resolve_theme("default") do
    # Use configured default theme when theme is "default"
    default_theme = Cinder.Theme.get_default_theme()
    Cinder.Theme.merge(default_theme)
  end

  defp resolve_theme(theme) when is_binary(theme) do
    Cinder.Theme.merge(theme)
  end

  defp resolve_theme(theme) when is_atom(theme) and not is_nil(theme) do
    Cinder.Theme.merge(theme)
  end

  defp resolve_theme(nil) do
    # Use configured default theme when no explicit theme provided
    default_theme = Cinder.Theme.get_default_theme()
    Cinder.Theme.merge(default_theme)
  end

  defp resolve_theme(_), do: Cinder.Theme.merge("default")

  # URL state helpers - extract state from URL state object
  defp get_url_filters(url_state) when is_map(url_state) do
    Map.get(url_state, :filters, %{})
  end

  defp get_url_filters(_url_state), do: %{}

  defp get_url_page(url_state) when is_map(url_state) do
    Map.get(url_state, :current_page, nil)
  end

  defp get_url_page(_url_state), do: nil

  defp get_url_sort(url_state) when is_map(url_state) do
    sort = Map.get(url_state, :sort_by, [])

    case sort do
      [] -> nil
      sort -> sort
    end
  end

  defp get_url_sort(_url_state), do: nil

  defp get_raw_url_params(url_state) when is_map(url_state) do
    Map.get(url_state, :filters, %{})
  end

  defp get_raw_url_params(_url_state), do: %{}

  defp get_state_change_handler(url_state, custom_handler, _table_id) when is_map(url_state) do
    # Return the callback atom that UrlManager expects
    # UrlManager will send {:table_state_change, table_id, encoded_state}
    if custom_handler do
      custom_handler
    else
      :table_state_change
    end
  end

  defp get_state_change_handler(_url_state, custom_handler, _table_id) do
    custom_handler
  end

  # Query normalization and validation helpers
  defp normalize_query_params(resource, query) do
    case {resource, query} do
      {nil, nil} ->
        raise ArgumentError, "Either :resource or :query must be provided to Cinder.Table.table"

      {resource, nil} when not is_nil(resource) ->
        # Convert resource to query
        Ash.Query.new(resource)

      {nil, query} when not is_nil(query) ->
        # Use provided query directly
        query

      {resource, query} when not is_nil(resource) and not is_nil(query) ->
        raise ArgumentError,
              "Cannot provide both :resource and :query to Cinder.Table.table. Use one or the other."
    end
  end

  defp extract_resource_from_query(%Ash.Query{resource: resource}), do: resource
  defp extract_resource_from_query(resource) when is_atom(resource), do: resource
  defp extract_resource_from_query(_), do: nil

  # Resolve actor and tenant from scope and explicit attributes
  # Following Ash's precedence: explicit attributes override scope values
  defp resolve_actor_and_tenant(assigns) do
    scope_options = extract_scope_options(assigns.scope)

    %{
      actor: assigns.actor || Map.get(scope_options, :actor),
      tenant: assigns.tenant || Map.get(scope_options, :tenant)
    }
  end

  # Extract options from scope using Ash.Scope.to_opts if scope is provided
  defp extract_scope_options(nil), do: %{}

  defp extract_scope_options(scope) do
    try do
      scope
      |> Ash.Scope.to_opts()
      |> Map.new()
    rescue
      _ ->
        # If scope doesn't implement the protocol, treat as empty
        %{}
    end
  end

  # Parse page_size configuration from integer or keyword list format
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

    # Ensure default is included in options
    normalized_options =
      if Enum.empty?(options) do
        []
      else
        options = if default in options, do: options, else: [default | options]
        Enum.sort(options)
      end

    %{
      selected_page_size: default,
      page_size_options: normalized_options,
      default_page_size: default,
      configurable: length(normalized_options) > 1
    }
  end

  defp parse_page_size_config(_invalid) do
    # Fallback to default for invalid configurations
    parse_page_size_config(25)
  end

  # Process unified search configuration into individual components
  def process_search_config(search_config, columns) do
    # Check if any columns are searchable
    has_searchable_columns = Enum.any?(columns, & &1.searchable)

    case search_config do
      nil ->
        # Auto-enable if searchable columns exist
        if has_searchable_columns do
          {"Search", "Search...", true, nil}
        else
          {nil, nil, false, nil}
        end

      false ->
        # Explicitly disabled
        {nil, nil, false, nil}

      config when is_list(config) ->
        # Custom configuration
        label = Keyword.get(config, :label, "Search")
        placeholder = Keyword.get(config, :placeholder, "Search...")
        search_fn = Keyword.get(config, :fn)
        {label, placeholder, true, search_fn}

      _invalid ->
        # Invalid config - auto-detect
        if has_searchable_columns do
          {"Search", "Search...", true, nil}
        else
          {nil, nil, false, nil}
        end
    end
  end
end
