defmodule Cinder.Table do
  @moduledoc """
  Simplified Cinder table component with intelligent defaults.

  This is the new, simplified API for Cinder tables that leverages automatic
  type inference and smart defaults while providing a clean, Phoenix LiveView-like interface.

  ## Basic Usage

  ### With Resource Parameter (Simple)

      <Cinder.Table.table resource={MyApp.User} actor={@current_user}>
        <:col field="name" filter sort>Name</:col>
        <:col field="email" filter>Email</:col>
        <:col field="created_at" sort>Created</:col>
      </Cinder.Table.table>

  ### With Query Parameter (Advanced)

      <!-- Using resource as query -->
      <Cinder.Table.table query={MyApp.User} actor={@current_user}>
        <:col field="name" filter sort>Name</:col>
        <:col field="email" filter>Email</:col>
        <:col field="created_at" sort>Created</:col>
      </Cinder.Table.table>

      <!-- Pre-configured query with custom read action -->
      <Cinder.Table.table query={Ash.Query.for_read(MyApp.User, :active_users)} actor={@current_user}>
        <:col field="name" filter sort>Name</:col>
        <:col field="email" filter>Email</:col>
        <:col field="created_at" sort>Created</:col>
      </Cinder.Table.table>

      <!-- Query with base filters -->
      <Cinder.Table.table query={MyApp.User |> Ash.Query.filter(department: "Engineering")} actor={@current_user}>
        <:col field="name" filter sort>Name</:col>
        <:col field="email" filter>Email</:col>
        <:col field="department.name" filter>Department</:col>
        <:col field="profile__country" filter>Country</:col>
      </Cinder.Table.table>

  ## Field Types

  ### Relationship Fields

  Use dot notation to access related resource fields:

      <:col field="department.name" filter sort>Department</:col>
      <:col field="manager.email" filter>Manager Email</:col>
      <:col field="office.building.address" filter>Office Address</:col>

  ### Embedded Resource Fields

  Use double underscore notation for embedded resource fields:

      <:col field="profile__bio" filter>Bio</:col>
      <:col field="settings__country" filter>Country</:col>
      <:col field="metadata__preferences__theme" filter>Theme</:col>

  Embedded enum fields are automatically detected and rendered as select filters:

      <!-- If profile.country is an Ash.Type.Enum, this becomes a select filter -->
      <:col field="profile__country" filter>Country</:col>

  ## Advanced Configuration

      <Cinder.Table.table
        resource={MyApp.Album}
        actor={@current_user}
        url_state={@url_state}
        page_size={50}
        theme="modern"
      >
        <:col field="title" filter sort class="w-1/2">
          Title
        </:col>
        <:col field="artist.name" filter sort>
          Artist
        </:col>
        <:col field="genre" filter={:select}>
          Genre
        </:col>
      </Cinder.Table.table>

  ## Complex Query Examples

      <!-- Admin interface with authorization and tenant -->
      <Cinder.Table.table
        query={MyApp.User
          |> Ash.Query.for_read(:admin_read, %{}, actor: @actor, authorize?: @authorizing)
          |> Ash.Query.set_tenant(@tenant)
          |> Ash.Query.filter(active: true)}
        actor={@actor}>
        <:col field="name" filter sort>Name</:col>
        <:col field="email" filter>Email</:col>
        <:col field="last_login" sort>Last Login</:col>
        <:col field="role" filter={:select}>Role</:col>
      </Cinder.Table.table>

  ## Multi-Tenant Examples

      <!-- Simple tenant support -->
      <Cinder.Table.table
        resource={MyApp.User}
        actor={@current_user}
        tenant={@tenant}>
        <:col field="name" filter sort>Name</:col>
        <:col field="email" filter>Email</:col>
      </Cinder.Table.table>

      <!-- Using Ash scope (only actor and tenant are extracted) -->
      <Cinder.Table.table
        resource={MyApp.User}
        scope={%{actor: @current_user, tenant: @tenant}}>
        <:col field="name" filter sort>Name</:col>
        <:col field="email" filter>Email</:col>
      </Cinder.Table.table>

      <!-- Custom scope struct -->
      <Cinder.Table.table
        resource={MyApp.User}
        scope={@my_scope}>
        <:col field="name" filter sort>Name</:col>
        <:col field="email" filter>Email</:col>
      </Cinder.Table.table>

      <!-- Mixed usage (explicit overrides scope) -->
      <Cinder.Table.table
        resource={MyApp.User}
        scope={@scope}
        actor={@different_actor}>
        <:col field="name" filter sort>Name</:col>
        <:col field="email" filter>Email</:col>
      </Cinder.Table.table>

  ## Features

  - **Automatic type inference** from Ash resources
  - **Intelligent filtering** with automatic filter type detection
  - **URL state management** with browser back/forward support
  - **Relationship support** using dot notation (e.g., `artist.name`)
  - **Flexible theming** with built-in presets
  """

  use Phoenix.LiveComponent

  @doc """
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

  Filter types: `:text`, `:select`, `:multi_select`, `:multi_checkboxes`, `:boolean`, `:date_range`, `:number_range`

  **Filter Type Selection:**
  - `:multi_select` - Modern tag-based interface with dropdown (default for array types)
  - `:multi_checkboxes` - Traditional checkbox interface for multiple selection

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

      <Cinder.Table.table
        resource={MyApp.Item}
        actor={@current_user}
        row_click={fn item -> JS.navigate(~p"/items/\#{item.id}") end}
      >
        <:col field="name" filter sort>Name</:col>
        <:col field="description">Description</:col>
      </Cinder.Table.table>

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
  attr(:page_size, :integer, default: 25, doc: "Number of items per page")
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
      required: true,
      doc: "Field name (supports dot notation for relationships)"
    )

    attr(:filter, :any, doc: "Enable filtering (true, false, or filter type atom)")

    attr(:filter_options, :list,
      doc: "Custom filter options (e.g., [options: [{\"Label\", \"value\"}]])"
    )

    attr(:sort, :boolean, doc: "Enable sorting")
    attr(:label, :string, doc: "Custom column label (auto-generated if not provided)")
    attr(:class, :string, doc: "CSS classes for this column")
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
      |> assign_new(:empty_message, fn -> "No results found" end)
      |> assign_new(:class, fn -> "" end)
      |> assign_new(:tenant, fn -> nil end)
      |> assign_new(:scope, fn -> nil end)

    # Resolve actor and tenant from scope and explicit attributes
    resolved_options = resolve_actor_and_tenant(assigns)

    # Validate and normalize query/resource parameters
    normalized_query = normalize_query_params(assigns.resource, assigns.query)
    resource = extract_resource_from_query(normalized_query)

    # Process columns and determine if filters should be shown
    processed_columns = process_columns(assigns.col, resource)
    show_filters = determine_show_filters(assigns, processed_columns)

    assigns =
      assigns
      |> assign(:normalized_query, normalized_query)
      |> assign(:processed_columns, processed_columns)
      |> assign(:resolved_options, resolved_options)
      |> assign_new(:show_filters, fn -> show_filters end)

    ~H"""
    <div class={["cinder-table", @class]}>
      <.live_component
        module={Cinder.Table.LiveComponent}
        id={@id}
        query={@normalized_query}
        actor={@resolved_options.actor}
        tenant={@resolved_options.tenant}
        page_size={@page_size}
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
        empty_message={@empty_message}
        col={@processed_columns}
        row_click={@row_click}
      />
    </div>
    """
  end

  # Process column definitions into the format expected by the underlying component
  defp process_columns(col_slots, resource) do
    Enum.map(col_slots, fn slot ->
      # Convert column slot to internal format using Column module
      field = Map.get(slot, :field)
      filter_attr = Map.get(slot, :filter, false)
      sort_attr = Map.get(slot, :sort, false)

      # Use Column module to parse the column configuration
      column_config = %{
        field: field,
        sortable: sort_attr,
        filterable: filter_attr != false,
        class: Map.get(slot, :class, ""),
        filter_options: Map.get(slot, :filter_options, [])
      }

      # Let Column module infer filter type if needed, otherwise use explicit type
      column_config =
        case determine_filter_type(filter_attr, field, resource) do
          :auto ->
            # Let Column module infer the type from resource
            column_config

          explicit_type ->
            # Use the explicitly specified filter type
            Map.put(column_config, :filter_type, explicit_type)
        end

      # Parse through Column module for intelligent defaults
      parsed_column = Cinder.Column.parse_column(column_config, resource)

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
        __slot__: :col
      }
    end)
  end

  # Determine filter type from the simplified API
  defp determine_filter_type(filter_attr, _field, _resource) do
    case filter_attr do
      false ->
        :text

      # Let Column module infer the type
      true ->
        :auto

      filter_type when is_atom(filter_type) ->
        filter_type

      filter_config when is_list(filter_config) ->
        Keyword.get(filter_config, :type, :text)

      _ ->
        :text
    end
  end

  # Default inner block that renders the field value
  defp default_inner_block(field) do
    fn item ->
      get_field_value(item, field)
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
end
