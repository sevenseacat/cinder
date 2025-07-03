defmodule Cinder.Helpers do
  @moduledoc """
  Shared helper functions used by both Table and Cards components.
  
  Contains utility functions for query normalization, URL state management,
  theme resolution, and other common operations.
  """

  @doc """
  Normalizes query parameters for consistent handling across components.
  
  Accepts either a resource module or an Ash.Query and returns a normalized query.
  """
  def normalize_query_params(resource, query) do
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

  @doc """
  Validates that either resource or query is provided, but not both.
  """
  def validate_resource_query_params!(resource, query) do
    cond do
      resource && query ->
        raise ArgumentError, """
        Cannot provide both resource and query parameters.
        
        Use either:
        - resource={MyApp.User} (for simple cases)
        - query={Ash.Query.for_read(MyApp.User, :some_action)} (for advanced cases)
        """

      not resource && not query ->
        raise ArgumentError, """
        Must provide either resource or query parameter.
        
        Use either:
        - resource={MyApp.User} (for simple cases)  
        - query={Ash.Query.for_read(MyApp.User, :some_action)} (for advanced cases)
        """

      true ->
        :ok
    end
  end

  @doc """
  Resolves theme configuration from various inputs.
  
  Handles theme name strings, theme modules, and fallback to default theme.
  """
  def resolve_theme("default") do
    # Use configured default theme when theme is "default"
    default_theme = Cinder.Theme.get_default_theme()
    Cinder.Theme.merge(default_theme)
  end

  def resolve_theme(theme) when is_binary(theme) do
    Cinder.Theme.merge(theme)
  end

  def resolve_theme(theme) when is_atom(theme) and not is_nil(theme) do
    Cinder.Theme.merge(theme)
  end

  def resolve_theme(nil) do
    # Use configured default theme when no explicit theme provided
    default_theme = Cinder.Theme.get_default_theme()
    Cinder.Theme.merge(default_theme)
  end

  @doc """
  Resolves actor from various sources (direct assignment, LiveView assigns, etc.).
  """
  def resolve_actor(assigns) do
    case Map.get(assigns, :actor) do
      nil ->
        # Try to get from LiveView assigns as fallback
        case Map.get(assigns, :current_user) do
          nil -> nil
          user -> user
        end

      actor ->
        actor
    end
  end

  @doc """
  Resolves tenant from various sources.
  """
  def resolve_tenant(assigns) do
    Map.get(assigns, :tenant)
  end

  @doc """
  Resolves scope from various sources.
  """
  def resolve_scope(assigns) do
    Map.get(assigns, :scope)
  end

  @doc """
  Extracts URL state parameters from assigns.
  """
  def extract_url_state_params(assigns) do
    url_state = Map.get(assigns, :url_state, %{})

    if is_map(url_state) and map_size(url_state) > 0 do
      %{
        filters: Map.get(url_state, :filters, %{}),
        page: Map.get(url_state, :current_page, 1),
        sort: Map.get(url_state, :sort_by, [])
      }
    else
      %{filters: %{}, page: 1, sort: []}
    end
  end

  @doc """
  Validates field requirements for slots with filter or sort enabled.
  """
  def validate_field_requirement!(slot_name, field, filter_attr, sort_attr) do
    field_required = filter_attr != false or sort_attr == true

    if field_required and (is_nil(field) or field == "") do
      filter_msg = if filter_attr != false, do: " filter", else: ""
      sort_msg = if sort_attr == true, do: " sort", else: ""

      raise ArgumentError, """
      Cinder #{slot_name} with#{filter_msg}#{sort_msg} attribute(s) requires a 'field' attribute.

      Either:
      - Add a field: <:#{slot_name} field="field_name"#{filter_msg}#{sort_msg} />
      - Remove#{filter_msg}#{sort_msg} attribute(s): <:#{slot_name} />
      """
    end
  end

  @doc """
  Determines if filters should be shown automatically based on slot configuration.
  """
  def determine_show_filters(assigns, processed_slots) do
    case Map.get(assigns, :show_filters) do
      nil ->
        # Auto-detect: show filters if any slot is filterable
        Enum.any?(processed_slots, & &1.filterable)

      show_filters ->
        show_filters
    end
  end

  @doc """
  Gets URL state filter parameters, with fallback to empty map.
  """
  def get_url_filters(url_state) when is_map(url_state) do
    Map.get(url_state, :filters, %{})
  end

  def get_url_filters(_url_state), do: %{}

  @doc """
  Gets URL state page parameter, with fallback to 1.
  """
  def get_url_page(url_state) when is_map(url_state) do
    Map.get(url_state, :current_page, 1)
  end

  def get_url_page(_url_state), do: 1

  @doc """
  Gets URL state sort parameters, with fallback to nil.
  """
  def get_url_sort(url_state) when is_map(url_state) do
    sort = Map.get(url_state, :sort_by, [])
    
    case sort do
      [] -> nil
      sort -> sort
    end
  end

  def get_url_sort(_url_state), do: nil

  @doc """
  Gets raw URL parameters (for debugging/advanced use).
  """
  def get_raw_url_params(_url_state), do: %{}

  @doc """
  Gets the appropriate state change handler for URL synchronization.
  
  Returns :table_state_change for compatibility with existing UrlSync modules.
  """
  def get_state_change_handler(url_state, custom_handler, _component_id) when is_map(url_state) do
    if custom_handler do
      custom_handler
    else
      :table_state_change
    end
  end

  def get_state_change_handler(_url_state, custom_handler, _component_id) do
    custom_handler
  end
end