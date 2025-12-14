defmodule Cinder.List do
  @moduledoc """
  Flexible list/card component for displaying collections with filtering, sorting, and pagination.

  This component separates field definitions (for filtering/sorting) from item rendering,
  with layout controlled purely through CSS/themes. The same component can render as a
  vertical list, grid, or cards by changing the container CSS classes.

  ## Basic Usage

  ```heex
  <Cinder.List.list resource={MyApp.User} actor={@current_user}>
    <:col field="name" filter sort search />
    <:col field="email" filter />
    <:col field="status" filter={:select} />

    <:item :let={user}>
      <div class="p-4 border-b hover:bg-gray-50">
        <h3 class="font-bold">{user.name}</h3>
        <p class="text-gray-600">{user.email}</p>
        <span class="text-sm">{user.status}</span>
      </div>
    </:item>
  </Cinder.List.list>
  ```

  ## Grid Layout

  Change the layout to a grid by overriding the container class:

  ```heex
  <Cinder.List.list
    resource={MyApp.Product}
    actor={@current_user}
    container_class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4"
  >
    <:col field="name" filter sort search />
    <:col field="category" filter={:select} />

    <:item :let={product}>
      <div class="p-4 border rounded-lg shadow-sm">
        <h3 class="font-bold">{product.name}</h3>
        <p class="text-gray-600">{product.category}</p>
        <p class="text-lg font-semibold">${product.price}</p>
      </div>
    </:item>
  </Cinder.List.list>
  ```

  ## Sort Controls

  Since there are no table headers, sort controls render as a button group when
  any column has `sort` enabled. Customize the sort label:

  ```heex
  <Cinder.List.list resource={MyApp.User} actor={@current_user} sort_label="Order by:">
    <:col field="name" sort />
    <:col field="created_at" sort />

    <:item :let={user}>
      <div class="p-4">{user.name} - {user.created_at}</div>
    </:item>
  </Cinder.List.list>
  ```

  ## Item Click Handler

  Add click handlers to items (similar to Table's `row_click`):

  ```heex
  <Cinder.List.list
    resource={MyApp.Topic}
    actor={@current_user}
    item_click={fn topic -> JS.patch(~p"/topics/\#{topic.id}") end}
  >
    <:col field="name" filter sort />

    <:item :let={topic}>
      <div class="p-4">{topic.name}</div>
    </:item>
  </Cinder.List.list>
  ```
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
  attr(:id, :string, default: "cinder-list", doc: "Unique identifier for the list")

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

  attr(:show_filters, :boolean,
    default: nil,
    doc: "Whether to show filter controls (auto-detected if nil)"
  )

  attr(:show_sort, :boolean,
    default: nil,
    doc: "Whether to show sort controls (auto-detected if nil)"
  )

  attr(:loading_message, :string, default: "Loading...", doc: "Message to show while loading")

  attr(:filters_label, :string,
    default: "🔍 Filters",
    doc: "Label for the filters component"
  )

  attr(:sort_label, :string,
    default: "Sort by:",
    doc: "Label for the sort controls"
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
    doc: "Override the item container CSS class (for grid layouts, etc.)"
  )

  attr(:item_click, :any,
    default: nil,
    doc: "Function to call when an item is clicked. Receives the item as argument."
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
  end

  slot(:item,
    required: false,
    doc: "Template for rendering each item. If not provided, a warning will be logged."
  )

  def list(assigns) do
    # Set intelligent defaults
    assigns =
      assigns
      |> assign_new(:id, fn -> "cinder-list" end)
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

    # Resolve actor and tenant from scope and explicit attributes
    resolved_options = resolve_actor_and_tenant(assigns)

    # Validate and normalize query/resource parameters
    normalized_query = normalize_query_params(assigns.resource, assigns.query)
    resource = extract_resource_from_query(normalized_query)

    # Process columns (reuse Table's processing)
    processed_columns = Cinder.Table.process_columns(assigns.col, resource)

    # Process unified search configuration
    {search_label, search_placeholder, search_enabled, search_fn} =
      Cinder.Table.process_search_config(assigns.search, processed_columns)

    # Determine if filters should be shown
    show_filters = determine_show_filters(assigns, processed_columns, search_enabled)

    # Determine if sort controls should be shown
    show_sort = determine_show_sort(assigns, processed_columns)

    # Parse page_size configuration
    page_size_config = parse_page_size_config(assigns.page_size)

    # Get the item slot
    item_slot = Map.get(assigns, :item, [])

    assigns =
      assigns
      |> assign(:normalized_query, normalized_query)
      |> assign(:processed_columns, processed_columns)
      |> assign(:resolved_options, resolved_options)
      |> assign(:page_size_config, page_size_config)
      |> assign(:search_label, search_label)
      |> assign(:search_placeholder, search_placeholder)
      |> assign(:search_enabled, search_enabled)
      |> assign(:search_fn, search_fn)
      |> assign(:show_filters, show_filters)
      |> assign(:show_sort, show_sort)
      |> assign(:item_slot, item_slot)

    ~H"""
    <div class={["cinder-list", @class]}>
      <.live_component
        module={Cinder.Data.LiveComponent}
        id={@id}
        renderer={Cinder.Renderers.List}
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
        show_sort={@show_sort}
        show_pagination={@show_pagination}
        loading_message={@loading_message}
        filters_label={@filters_label}
        sort_label={@sort_label}
        empty_message={@empty_message}
        col={@processed_columns}
        filter_configs={@processed_columns}
        item_click={@item_click}
        item_slot={@item_slot}
        container_class={@container_class}
        search_enabled={@search_enabled}
        search_label={@search_label}
        search_placeholder={@search_placeholder}
        search_fn={@search_fn}
      />
    </div>
    """
  end

  # ============================================================================
  # PRIVATE FUNCTIONS
  # ============================================================================

  defp normalize_query_params(resource, query) do
    case {resource, query} do
      {nil, nil} ->
        raise ArgumentError, "Either resource or query must be provided"

      {resource, nil} when not is_nil(resource) ->
        resource

      {nil, query} when not is_nil(query) ->
        query

      {_resource, query} ->
        query
    end
  end

  defp extract_resource_from_query(%Ash.Query{resource: resource}), do: resource
  defp extract_resource_from_query(resource) when is_atom(resource), do: resource
  defp extract_resource_from_query(_), do: nil

  defp resolve_actor_and_tenant(assigns) do
    scope_opts = extract_scope_options(assigns[:scope])

    %{
      actor: assigns[:actor] || scope_opts[:actor],
      tenant: assigns[:tenant] || scope_opts[:tenant]
    }
  end

  defp extract_scope_options(nil), do: []

  defp extract_scope_options(scope) do
    try do
      Ash.Scope.to_opts(scope, [:actor, :tenant])
    rescue
      _ -> []
    end
  end

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

  defp parse_page_size_config(_invalid) do
    parse_page_size_config(25)
  end

  defp resolve_theme("default") do
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
    default_theme = Cinder.Theme.get_default_theme()
    Cinder.Theme.merge(default_theme)
  end

  defp resolve_theme(_), do: Cinder.Theme.merge("default")

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

  defp get_state_change_handler(url_state, custom_handler, _component_id)
       when is_map(url_state) do
    if custom_handler do
      custom_handler
    else
      :table_state_change
    end
  end

  defp get_state_change_handler(_url_state, custom_handler, _component_id) do
    custom_handler
  end
end
