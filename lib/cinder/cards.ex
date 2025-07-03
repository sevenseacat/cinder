defmodule Cinder.Cards do
  @moduledoc """
  Simplified Cinder cards component with intelligent defaults.

  This component provides card-based layouts that leverage the same filtering,
  sorting, and pagination logic as the table component while providing flexible
  card rendering through the `:card` slot.

  ## Basic Usage

  ### With Resource Parameter (Simple)

      <Cinder.Cards.cards resource={MyApp.User} actor={@current_user}>
        <:prop field="name" filter sort />
        <:prop field="email" filter />
        <:prop field="created_at" sort />
        <:card :let={user}>
          <div class="card">
            <h3>{user.name}</h3>
            <p>{user.email}</p>
            <small>{user.created_at}</small>
          </div>
        </:card>
      </Cinder.Cards.cards>

  ### With Query Parameter (Advanced)

      <!-- Using resource as query -->
      <Cinder.Cards.cards query={MyApp.User} actor={@current_user}>
        <:prop field="name" filter sort />
        <:prop field="email" filter />
        <:card :let={user}>
          <div class="user-card">
            <h3>{user.name}</h3>
            <p>{user.email}</p>
          </div>
        </:card>
      </Cinder.Cards.cards>

      <!-- Pre-configured query with custom read action -->
      <Cinder.Cards.cards query={Ash.Query.for_read(MyApp.User, :active_users)} actor={@current_user}>
        <:prop field="name" filter sort />
        <:prop field="email" filter />
        <:card :let={user}>
          <div class="active-user-card">
            <h3>{user.name}</h3>
            <p>{user.email}</p>
          </div>
        </:card>
      </Cinder.Cards.cards>

      <!-- Query with base filters -->
      <Cinder.Cards.cards query={MyApp.User |> Ash.Query.filter(department: "Engineering")} actor={@current_user}>
        <:prop field="name" filter sort />
        <:prop field="email" filter />
        <:prop field="department.name" filter />
        <:prop field="profile__country" filter />
        <:card :let={user}>
          <div class="engineer-card">
            <h3>{user.name}</h3>
            <p>{user.email}</p>
            <p>Department: {user.department.name}</p>
            <p>Country: {user.profile.country}</p>
          </div>
        </:card>
      </Cinder.Cards.cards>

  ## Field Types

  ### Relationship Fields

  Use dot notation to access related resource fields:

      <:prop field="department.name" filter sort />
      <:prop field="manager.email" filter />
      <:prop field="office.building.address" filter />

  ### Embedded Resource Fields

  Use double underscore notation for embedded resource fields:

      <:prop field="profile__bio" filter />
      <:prop field="settings__country" filter />
      <:prop field="metadata__preferences__theme" filter />

  Embedded enum fields are automatically detected and rendered as select filters:

      <!-- If profile.country is an Ash.Type.Enum, this becomes a select filter -->
      <:prop field="profile__country" filter />

  ## Advanced Configuration

      <Cinder.Cards.cards
        resource={MyApp.Album}
        actor={@current_user}
        url_state={@url_state}
        page_size={12}
        theme="modern"
      >
        <:prop field="title" filter sort />
        <:prop field="artist.name" filter sort />
        <:prop field="genre" filter={:select} />
        <:card :let={album}>
          <div class="album-card">
            <img src={album.cover_url} alt={album.title} />
            <h3>{album.title}</h3>
            <p>by {album.artist.name}</p>
            <span class="genre">{album.genre}</span>
          </div>
        </:card>
      </Cinder.Cards.cards>

  ## Row/Card Click Functionality

  Cards can be made interactive by providing a `card_click` function that will be
  executed when a card is clicked:

      <Cinder.Cards.cards
        resource={MyApp.Item}
        actor={@current_user}
        card_click={fn item -> JS.navigate(~p"/items/\#{item.id}") end}
      >
        <:prop field="name" filter sort />
        <:prop field="description" />
        <:card :let={item}>
          <div class="clickable-card">
            <h3>{item.name}</h3>
            <p>{item.description}</p>
          </div>
        </:card>
      </Cinder.Cards.cards>

  The `card_click` function receives the card item as its argument and should return
  a Phoenix.LiveView.JS command or similar action. When provided, cards will be
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
  attr(:id, :string, default: "cinder-cards", doc: "Unique identifier for the cards")
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

  attr(:card_click, :any,
    default: nil,
    doc: "Function to call when a card is clicked. Receives the card item as argument."
  )

  slot :prop, required: true do
    attr(:field, :string,
      required: false,
      doc:
        "Field name (supports dot notation for relationships or `__` for embedded attributes). Required when filter or sort is enabled."
    )

    attr(:filter, :any, doc: "Enable filtering (true, false, or filter type atom)")

    attr(:filter_options, :list,
      doc: "Custom filter options (e.g., [options: [{\"Label\", \"value\"}]])"
    )

    attr(:sort, :boolean, doc: "Enable sorting")
    attr(:label, :string, doc: "Custom property label (auto-generated if not provided)")
  end

  slot :card, required: true do
    attr(:class, :string, doc: "CSS classes for individual cards")
  end

  def cards(assigns) do
    # Set intelligent defaults
    assigns =
      assigns
      |> assign_new(:id, fn -> "cinder-cards" end)
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

    # Process properties and determine if filters should be shown
    processed_props = process_props(assigns.prop, resource)
    show_filters = determine_show_filters(assigns, processed_props)

    assigns =
      assigns
      |> assign(:normalized_query, normalized_query)
      |> assign(:processed_props, processed_props)
      |> assign(:resolved_options, resolved_options)
      |> assign_new(:show_filters, fn -> show_filters end)

    ~H"""
    <div class={["cinder-cards", @class]}>
      <.live_component
        module={Cinder.Cards.LiveComponent}
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
        props={@processed_props}
        card_slot={@card}
        card_click={@card_click}
      />
    </div>
    """
  end

  # Process property definitions into the format expected by the underlying component
  def process_props(prop_slots, resource) do
    Enum.map(prop_slots, fn slot ->
      # Convert property slot to internal format using Column module
      field = Map.get(slot, :field)
      filter_attr = Map.get(slot, :filter, false)
      sort_attr = Map.get(slot, :sort, false)

      # Validate field requirement for filtering/sorting
      validate_field_requirement!(slot, field, filter_attr, sort_attr)

      # Use Column module to parse the property configuration
      column_config = %{
        field: field,
        sortable: sort_attr,
        filterable: filter_attr != false,
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

      # Parse through Column module for intelligent defaults (only if field exists)
      parsed_column =
        if field do
          Cinder.Column.parse_column(column_config, resource)
        else
          # For properties without fields, provide sensible defaults
          %{
            label: Map.get(slot, :label, ""),
            filterable: false,
            filter_type: :text,
            filter_options: [],
            sortable: false
          }
        end

      # Create property in internal format with proper label handling
      %{
        field: field,
        label: Map.get(slot, :label, parsed_column.label),
        filterable: parsed_column.filterable,
        filter_type: parsed_column.filter_type,
        filter_options: parsed_column.filter_options,
        sortable: parsed_column.sortable,
        filter_fn: Map.get(parsed_column, :filter_fn, nil),
        sort_fn: Map.get(parsed_column, :sort_fn, nil)
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

  # Validates that field is provided when filter or sort is enabled
  defp validate_field_requirement!(_slot, field, filter_attr, sort_attr) do
    field_required = filter_attr != false or sort_attr == true

    if field_required and (is_nil(field) or field == "") do
      filter_msg = if filter_attr != false, do: " filter", else: ""
      sort_msg = if sort_attr == true, do: " sort", else: ""

      raise ArgumentError, """
      Cinder cards property with#{filter_msg}#{sort_msg} attribute(s) requires a 'field' attribute.

      Either:
      - Add a field: <:prop field="field_name"#{filter_msg}#{sort_msg} />
      - Remove#{filter_msg}#{sort_msg} attribute(s): <:prop />
      """
    end
  end

  # Determine if filters should be shown automatically
  defp determine_show_filters(assigns, processed_props) do
    case Map.get(assigns, :show_filters) do
      nil ->
        # Auto-detect: show filters if any property is filterable
        Enum.any?(processed_props, & &1.filterable)

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

  defp get_state_change_handler(url_state, custom_handler, _cards_id) when is_map(url_state) do
    # Return the callback atom that UrlManager expects
    # UrlManager will send {:table_state_change, cards_id, encoded_state}
    if custom_handler do
      custom_handler
    else
      :table_state_change
    end
  end

  defp get_state_change_handler(_url_state, custom_handler, _cards_id) do
    custom_handler
  end

  # Query normalization and validation helpers
  defp normalize_query_params(resource, query) do
    case {resource, query} do
      {nil, nil} ->
        raise ArgumentError, "Either :resource or :query must be provided to Cinder.Cards.cards"

      {resource, nil} when not is_nil(resource) ->
        # Convert resource to query
        Ash.Query.new(resource)

      {nil, query} when not is_nil(query) ->
        # Use provided query directly
        query

      {resource, query} when not is_nil(resource) and not is_nil(query) ->
        raise ArgumentError,
              "Cannot provide both :resource and :query to Cinder.Cards.cards. Use one or the other."
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
