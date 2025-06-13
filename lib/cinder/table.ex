defmodule Cinder.Table do
  @moduledoc """
  Simplified Cinder table component with intelligent defaults.

  This is the new, simplified API for Cinder tables that leverages automatic
  type inference and smart defaults while providing a clean, Phoenix LiveView-like interface.

  ## Basic Usage

      <Cinder.Table.table resource={MyApp.User} current_user={@current_user}>
        <:col field="name" filter sort>Name</:col>
        <:col field="email" filter>Email</:col>
        <:col field="created_at" sort>Created</:col>
      </Cinder.Table.table>

  ## Advanced Usage

      <Cinder.Table.table
        resource={MyApp.Album}
        current_user={@current_user}
        url_sync
        page_size={50}
        theme="modern"
      >
        <:col field="title" filter sort class="w-1/2">
          Title
        </:col>
        <:col field="artist.name" filter sort>
          Artist
        </:col>
        <:col field="release_date" filter={:date_range} sort>
          Released
        </:col>
        <:col field="status" filter={:select} sort>
          Status
        </:col>
        <:col field="actions" class="text-center">
          <.link navigate={~p"/albums/\#{album.id}"}>View</.link>
        </:col>
      </Cinder.Table.table>

  ## Features

  - **Automatic type inference** from Ash resources
  - **Intelligent filtering** with automatic filter type detection
  - **URL state management** with browser back/forward support
  - **Relationship support** using dot notation (e.g., `artist.name`)
  - **Flexible theming** with built-in presets
  - **Responsive design** with configurable CSS classes
  """

  use Phoenix.LiveComponent

  @doc """
  Renders a data table with intelligent defaults.

  ## Attributes

  - `resource` (required) - Ash resource module to query
  - `current_user` (required) - Current user for authorization
  - `id` - Component ID (defaults to "cinder-table")
  - `page_size` - Number of items per page (default: 25)
  - `theme` - Theme preset or custom theme map (default: "default")
  - `url_sync` - Enable URL state synchronization (default: false) - requires parent LiveView to handle `:table_state_change` messages
  - `query_opts` - Additional query options for Ash (default: [])
  - `on_state_change` - Callback for state changes
  - `show_filters` - Show filter controls (default: auto-detect from columns)
  - `show_pagination` - Show pagination controls (default: true)
  - `loading_message` - Custom loading message
  - `empty_message` - Custom empty state message
  - `class` - Additional CSS classes for container

  ## Column Slot

  The `:col` slot supports these attributes:

  - `field` (required) - Field name or relationship path (e.g., "user.name")
  - `filter` - Enable filtering (boolean or filter type atom)
  - `sort` - Enable sorting (boolean)
  - `class` - CSS classes for this column
  - `label` - Column header label (auto-generated from field name if not provided)

  Filter types: `:text`, `:select`, `:multi_select`, `:boolean`, `:date_range`, `:number_range`

  ## Column Labels

  Column labels are automatically generated from field names using intelligent humanization:
  - `name` → "Name"
  - `email_address` → "Email Address"
  - `user.name` → "User Name"
  - `created_at` → "Created At"

  You can override the auto-generated label by providing a `label` attribute.
  """
  def table(assigns) do
    # Set intelligent defaults
    assigns =
      assigns
      |> assign_new(:id, fn -> "cinder-table" end)
      |> assign_new(:page_size, fn -> 25 end)
      |> assign_new(:theme, fn -> "default" end)
      |> assign_new(:url_sync, fn -> false end)
      |> assign_new(:query_opts, fn -> [] end)
      |> assign_new(:on_state_change, fn -> nil end)
      |> assign_new(:show_pagination, fn -> true end)
      |> assign_new(:loading_message, fn -> "Loading..." end)
      |> assign_new(:empty_message, fn -> "No results found" end)
      |> assign_new(:class, fn -> "" end)

    # Process columns and determine if filters should be shown
    processed_columns = process_columns(assigns.col, assigns.resource)
    show_filters = determine_show_filters(assigns, processed_columns)

    assigns =
      assigns
      |> assign(:processed_columns, processed_columns)
      |> assign_new(:show_filters, fn -> show_filters end)

    ~H"""
    <div class={["cinder-table", @class]}>
      <.live_component
        module={Cinder.Table.LiveComponent}
        id={@id}
        query={@resource}
        current_user={@current_user}
        page_size={@page_size}
        theme={resolve_theme(@theme)}
        url_filters={get_url_filters(@url_sync, assigns)}
        url_page={get_url_page(@url_sync, assigns)}
        url_sort={get_url_sort(@url_sync, assigns)}
        query_opts={@query_opts}
        on_state_change={get_state_change_handler(@url_sync, @on_state_change, @id)}
        show_filters={@show_filters}
        show_pagination={@show_pagination}
        loading_message={@loading_message}
        empty_message={@empty_message}
        col={@processed_columns}
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
        key: field,
        sortable: sort_attr,
        filterable: filter_attr != false,
        class: Map.get(slot, :class, "")
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
        key: field,
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
  defp resolve_theme(theme) when is_binary(theme) do
    Cinder.Theme.merge(theme)
  end

  defp resolve_theme(theme) when is_map(theme) do
    Cinder.Theme.merge(theme)
  end

  defp resolve_theme(_), do: Cinder.Theme.merge("default")

  # URL sync helpers - read from socket assigns when url_sync is enabled
  defp get_url_filters(true, assigns) do
    Map.get(assigns, :table_url_filters, %{})
  end

  defp get_url_filters(_url_sync, _assigns), do: %{}

  defp get_url_page(true, assigns) do
    Map.get(assigns, :table_url_page, nil)
  end

  defp get_url_page(_url_sync, _assigns), do: nil

  defp get_url_sort(true, assigns) do
    case Map.get(assigns, :table_url_sort, []) do
      [] -> nil
      sort -> sort
    end
  end

  defp get_url_sort(_url_sync, _assigns), do: nil

  defp get_state_change_handler(true, custom_handler, _table_id) do
    # Return the callback atom that UrlManager expects
    # UrlManager will send {:table_state_change, table_id, encoded_state}
    if custom_handler do
      custom_handler
    else
      :table_state_change
    end
  end

  defp get_state_change_handler(_url_sync, custom_handler, _table_id) do
    custom_handler
  end

  @doc """
  Helper function to add CSS classes for responsive design.

  ## Examples

      <Cinder.Table.table resource={User} current_user={@user} class={responsive_classes()}>
        <:col field="name" filter sort class={responsive_col_classes(:name)}>Name</:col>
      </Cinder.Table.table>
  """
  def responsive_classes do
    "overflow-x-auto"
  end

  def responsive_col_classes(:name), do: "min-w-[200px]"
  def responsive_col_classes(:email), do: "min-w-[250px] hidden md:table-cell"
  def responsive_col_classes(:created_at), do: "min-w-[150px] hidden lg:table-cell"
  def responsive_col_classes(_), do: ""
end
