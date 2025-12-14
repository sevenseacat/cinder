defmodule Cinder.Data.HelpersTest do
  @moduledoc """
  Tests for Cinder.Data.Helpers shared utility functions.
  """
  use ExUnit.Case, async: true

  alias Cinder.Data.Helpers

  # ============================================================================
  # THEME RESOLUTION TESTS
  # ============================================================================

  describe "resolve_theme/1" do
    test "resolves 'default' string to merged default theme" do
      result = Helpers.resolve_theme("default")

      # Should return a map with theme properties
      assert is_map(result)
      assert Map.has_key?(result, :container_class)
    end

    test "resolves named string theme" do
      result = Helpers.resolve_theme("compact")

      assert is_map(result)
      assert Map.has_key?(result, :container_class)
    end

    test "resolves string theme names" do
      # String themes are matched in Theme.merge/1 clauses
      result = Helpers.resolve_theme("modern")

      assert is_map(result)
      assert Map.has_key?(result, :container_class)
    end

    test "resolves nil to default theme" do
      result = Helpers.resolve_theme(nil)

      assert is_map(result)
      assert Map.has_key?(result, :container_class)
    end

    test "falls back to default for invalid input" do
      result = Helpers.resolve_theme(%{invalid: true})

      assert is_map(result)
      assert Map.has_key?(result, :container_class)
    end
  end

  # ============================================================================
  # URL STATE EXTRACTION TESTS
  # ============================================================================

  describe "get_url_filters/1" do
    test "extracts filters from URL state map" do
      url_state = %{filters: %{"name" => "test"}, current_page: 1}

      result = Helpers.get_url_filters(url_state)

      assert result == %{"name" => "test"}
    end

    test "returns empty map when filters not present" do
      url_state = %{current_page: 1}

      result = Helpers.get_url_filters(url_state)

      assert result == %{}
    end

    test "returns empty map for non-map URL state" do
      assert Helpers.get_url_filters(nil) == %{}
      assert Helpers.get_url_filters(false) == %{}
      assert Helpers.get_url_filters("string") == %{}
    end
  end

  describe "get_url_page/1" do
    test "extracts current_page from URL state map" do
      url_state = %{current_page: 5}

      result = Helpers.get_url_page(url_state)

      assert result == 5
    end

    test "returns nil when current_page not present" do
      url_state = %{filters: %{}}

      result = Helpers.get_url_page(url_state)

      assert result == nil
    end

    test "returns nil for non-map URL state" do
      assert Helpers.get_url_page(nil) == nil
      assert Helpers.get_url_page(false) == nil
    end
  end

  describe "get_url_sort/1" do
    test "extracts sort_by from URL state map" do
      url_state = %{sort_by: [{"name", :asc}]}

      result = Helpers.get_url_sort(url_state)

      assert result == [{"name", :asc}]
    end

    test "returns nil for empty sort list" do
      url_state = %{sort_by: []}

      result = Helpers.get_url_sort(url_state)

      assert result == nil
    end

    test "returns nil when sort_by not present" do
      url_state = %{filters: %{}}

      result = Helpers.get_url_sort(url_state)

      assert result == nil
    end

    test "returns nil for non-map URL state" do
      assert Helpers.get_url_sort(nil) == nil
      assert Helpers.get_url_sort(false) == nil
    end
  end

  describe "get_raw_url_params/1" do
    test "extracts filters as raw params from URL state map" do
      url_state = %{filters: %{"name" => "value"}}

      result = Helpers.get_raw_url_params(url_state)

      assert result == %{"name" => "value"}
    end

    test "returns empty map for non-map URL state" do
      assert Helpers.get_raw_url_params(nil) == %{}
      assert Helpers.get_raw_url_params(false) == %{}
    end
  end

  describe "get_state_change_handler/3" do
    test "returns custom handler when URL state is map and custom handler provided" do
      url_state = %{filters: %{}}

      result = Helpers.get_state_change_handler(url_state, :my_handler, "table-1")

      assert result == :my_handler
    end

    test "returns :table_state_change when URL state is map and no custom handler" do
      url_state = %{filters: %{}}

      result = Helpers.get_state_change_handler(url_state, nil, "table-1")

      assert result == :table_state_change
    end

    test "returns custom handler when URL state is not a map" do
      result = Helpers.get_state_change_handler(false, :my_handler, "table-1")

      assert result == :my_handler
    end

    test "returns nil when URL state is not a map and no custom handler" do
      result = Helpers.get_state_change_handler(false, nil, "table-1")

      assert result == nil
    end
  end

  # ============================================================================
  # ACTOR/TENANT RESOLUTION TESTS
  # ============================================================================

  describe "resolve_actor_and_tenant/1" do
    test "returns explicit actor and tenant when provided" do
      assigns = %{actor: :my_actor, tenant: :my_tenant}

      result = Helpers.resolve_actor_and_tenant(assigns)

      assert result == %{actor: :my_actor, tenant: :my_tenant}
    end

    test "returns nil values when not provided" do
      assigns = %{}

      result = Helpers.resolve_actor_and_tenant(assigns)

      assert result == %{actor: nil, tenant: nil}
    end

    test "explicit actor takes precedence over scope" do
      assigns = %{actor: :explicit_actor, scope: nil}

      result = Helpers.resolve_actor_and_tenant(assigns)

      assert result.actor == :explicit_actor
    end

    test "explicit tenant takes precedence over scope" do
      assigns = %{tenant: :explicit_tenant, scope: nil}

      result = Helpers.resolve_actor_and_tenant(assigns)

      assert result.tenant == :explicit_tenant
    end

    test "handles nil scope gracefully" do
      assigns = %{scope: nil}

      result = Helpers.resolve_actor_and_tenant(assigns)

      assert result == %{actor: nil, tenant: nil}
    end
  end

  # ============================================================================
  # PAGE SIZE CONFIGURATION TESTS
  # ============================================================================

  describe "parse_page_size_config/1" do
    test "parses integer page size" do
      result = Helpers.parse_page_size_config(50)

      assert result == %{
               selected_page_size: 50,
               page_size_options: [],
               default_page_size: 50,
               configurable: false
             }
    end

    test "parses keyword list with default and options" do
      result = Helpers.parse_page_size_config(default: 25, options: [10, 25, 50])

      assert result == %{
               selected_page_size: 25,
               page_size_options: [10, 25, 50],
               default_page_size: 25,
               configurable: true
             }
    end

    test "marks single option as non-configurable" do
      result = Helpers.parse_page_size_config(default: 25, options: [25])

      assert result.configurable == false
    end

    test "uses default of 25 when default not specified" do
      result = Helpers.parse_page_size_config(options: [10, 25, 50])

      assert result.selected_page_size == 25
      assert result.default_page_size == 25
    end

    test "handles empty options list" do
      result = Helpers.parse_page_size_config(default: 25, options: [])

      assert result.page_size_options == []
      assert result.configurable == false
    end

    test "falls back to defaults for invalid input" do
      result = Helpers.parse_page_size_config("invalid")

      assert result == %{
               selected_page_size: 25,
               page_size_options: [],
               default_page_size: 25,
               configurable: false
             }
    end

    test "handles nil input" do
      result = Helpers.parse_page_size_config(nil)

      assert result == %{
               selected_page_size: 25,
               page_size_options: [],
               default_page_size: 25,
               configurable: false
             }
    end

    test "validates options are integers" do
      result = Helpers.parse_page_size_config(default: 25, options: ["10", "25", "50"])

      # Invalid options should be filtered out
      assert result.page_size_options == []
      assert result.configurable == false
    end
  end
end
