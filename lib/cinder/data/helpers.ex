defmodule Cinder.Data.Helpers do
  @moduledoc """
  Shared helper functions for Cinder data components.

  This module provides utility functions that are used by both Table and List
  components for theme resolution, URL state extraction, and other common operations.
  """

  # ============================================================================
  # THEME RESOLUTION
  # ============================================================================

  @doc """
  Resolves a theme specification to a merged theme map.

  Accepts:
  - `"default"` - uses the configured default theme
  - A binary theme name - looks up and merges the named theme
  - An atom theme name - looks up and merges the named theme
  - `nil` - uses the configured default theme
  - Any other value - falls back to the "default" theme
  """
  def resolve_theme("default") do
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
    default_theme = Cinder.Theme.get_default_theme()
    Cinder.Theme.merge(default_theme)
  end

  def resolve_theme(_), do: Cinder.Theme.merge("default")

  # ============================================================================
  # URL STATE EXTRACTION
  # ============================================================================

  @doc """
  Extracts filter state from a URL state map.

  Returns an empty map if URL state is not a map.
  """
  def get_url_filters(url_state) when is_map(url_state) do
    Map.get(url_state, :filters, %{})
  end

  def get_url_filters(_url_state), do: %{}

  @doc """
  Extracts the current page from a URL state map.

  Returns nil if URL state is not a map or page is not set.
  """
  def get_url_page(url_state) when is_map(url_state) do
    Map.get(url_state, :current_page, nil)
  end

  def get_url_page(_url_state), do: nil

  @doc """
  Extracts sort state from a URL state map.

  Returns nil if URL state is not a map or sort is empty.
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
  Extracts raw URL parameters from a URL state map.

  Returns an empty map if URL state is not a map.
  """
  def get_raw_url_params(url_state) when is_map(url_state) do
    Map.get(url_state, :filters, %{})
  end

  def get_raw_url_params(_url_state), do: %{}

  @doc """
  Determines the state change handler for URL synchronization.

  When URL state is enabled (is a map), returns the custom handler if provided,
  otherwise returns `:table_state_change` as the default.
  When URL state is disabled, returns only the custom handler (or nil).
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

  # ============================================================================
  # ACTOR/TENANT RESOLUTION
  # ============================================================================

  @doc """
  Resolves actor and tenant from assigns, supporting both explicit attributes and scope.

  Explicit `actor` and `tenant` attributes take precedence over values extracted from `scope`.

  Returns a map with `:actor` and `:tenant` keys.
  """
  def resolve_actor_and_tenant(assigns) do
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

  # ============================================================================
  # PAGE SIZE CONFIGURATION
  # ============================================================================

  @doc """
  Parses page size configuration from various input formats.

  Accepts:
  - An integer - simple page size with no options
  - A keyword list with `:default` and `:options` keys - configurable page size
  - Invalid input - falls back to default of 25

  Returns a map with:
  - `:selected_page_size` - the currently selected page size
  - `:page_size_options` - list of available options (empty for non-configurable)
  - `:default_page_size` - the default page size
  - `:configurable` - whether the user can change page size
  """
  def parse_page_size_config(page_size) when is_integer(page_size) do
    %{
      selected_page_size: page_size,
      page_size_options: [],
      default_page_size: page_size,
      configurable: false
    }
  end

  def parse_page_size_config(config) when is_list(config) do
    default = Keyword.get(config, :default, 25)
    options = Keyword.get(config, :options, [])

    # Validate options is a list
    valid_options =
      if is_list(options) and Enum.all?(options, &is_integer/1) do
        options
      else
        []
      end

    # Only configurable if there are multiple valid options
    configurable = length(valid_options) > 1

    %{
      selected_page_size: default,
      page_size_options: valid_options,
      default_page_size: default,
      configurable: configurable
    }
  end

  def parse_page_size_config(_invalid) do
    %{
      selected_page_size: 25,
      page_size_options: [],
      default_page_size: 25,
      configurable: false
    }
  end
end
