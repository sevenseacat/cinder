defmodule Cinder.Integration.NonPaginatedActionTest do
  use ExUnit.Case, async: true
  import ExUnit.CaptureLog

  alias Cinder.QueryBuilder

  # Test resource with non-paginated action
  defmodule TestUser do
    use Ash.Resource,
      domain: Cinder.Integration.NonPaginatedActionTest.TestDomain,
      data_layer: Ash.DataLayer.Ets,
      validate_domain_inclusion?: false

    ets do
      private?(true)
    end

    attributes do
      uuid_primary_key(:id)
      attribute(:name, :string, public?: true)
      attribute(:email, :string, public?: true)
    end

    actions do
      defaults([:read])

      create :create do
        primary?(true)
        accept([:name, :email])
      end

      destroy :destroy do
        primary?(true)
      end

      # Action that doesn't support pagination - this simulates the issue
      read :by_name do
        argument(:name, :string, allow_nil?: false)
        filter(expr(name == ^arg(:name)))
      end

      # Another non-paginated action for testing
      read :list_non_paginated do
        # No pagination configured
      end
    end
  end

  defmodule TestDomain do
    use Ash.Domain, validate_config_inclusion?: false

    resources do
      resource(TestUser)
    end
  end

  setup do
    # Create test data
    {:ok, user1} = Ash.create(TestUser, %{name: "Alice", email: "alice@example.com"})
    {:ok, user2} = Ash.create(TestUser, %{name: "Bob", email: "bob@example.com"})
    {:ok, user3} = Ash.create(TestUser, %{name: "Charlie", email: "charlie@example.com"})

    %{users: [user1, user2, user3]}
  end

  describe "build_and_execute/2 with Ash.Query input" do
    test "handles resource (atom) input with default action", %{users: _users} do
      options = [
        actor: nil,
        filters: %{},
        sort_by: [],
        page_size: 2,
        current_page: 1,
        columns: [],
        query_opts: []
      ]

      {:ok, {results, page_info}} = QueryBuilder.build_and_execute(TestUser, options)

      # Should work with default paginated action
      assert is_list(results)
      assert page_info.current_page == 1
      assert is_integer(page_info.total_count)
    end

    test "handles pre-built query with action that has arguments - the main fix" do
      # This simulates the issue described - using an action with arguments
      # that doesn't support pagination
      query = Ash.Query.for_read(TestUser, :by_name, %{name: "Alice"})

      options = [
        actor: nil,
        filters: %{},
        sort_by: [],
        page_size: 10,
        current_page: 1,
        columns: [],
        query_opts: []
      ]

      # This should NOT raise ActionRequiresPagination error
      {:ok, {results, page_info}} = QueryBuilder.build_and_execute(query, options)

      # Should find Alice
      assert length(results) == 1
      assert hd(results).name == "Alice"

      # Should still provide pagination info for UI consistency
      assert page_info.total_count == 1
      assert page_info.current_page == 1
    end

    test "handles pre-built query with default paginated action" do
      query = Ash.Query.for_read(TestUser, :read)

      options = [
        actor: nil,
        filters: %{},
        sort_by: [],
        page_size: 2,
        current_page: 1,
        columns: [],
        query_opts: []
      ]

      {:ok, {results, page_info}} = QueryBuilder.build_and_execute(query, options)

      # Should use normal pagination
      assert is_list(results)
      assert page_info.current_page == 1
    end

    test "handles empty results from argument-based action" do
      query = Ash.Query.for_read(TestUser, :by_name, %{name: "NonExistent"})

      options = [
        actor: nil,
        filters: %{},
        sort_by: [],
        page_size: 10,
        current_page: 1,
        columns: [],
        query_opts: []
      ]

      {:ok, {results, page_info}} = QueryBuilder.build_and_execute(query, options)

      assert results == []
      assert page_info.total_count == 0
      assert page_info.current_page == 1
    end
  end

  describe "manual pagination" do
    test "manually paginates results when action doesn't support native pagination" do
      # Create multiple users with same name to test pagination
      for i <- 1..5 do
        Ash.create(TestUser, %{name: "TestUser", email: "test#{i}@example.com"})
      end

      # Use an action that can't be paginated natively
      query = Ash.Query.for_read(TestUser, :by_name, %{name: "TestUser"})

      # Request pagination - second page
      options = [
        actor: nil,
        filters: %{},
        sort_by: [],
        page_size: 2,
        current_page: 2,
        columns: [],
        query_opts: []
      ]

      {:ok, {results, page_info}} = QueryBuilder.build_and_execute(query, options)

      # Should return all results since action doesn't support pagination
      assert length(results) == 5
      assert page_info.total_count == 5
      assert page_info.current_page == 1
      assert page_info.total_pages == 1
      assert page_info.has_next_page == false
    end
  end

  describe "pagination configuration warnings" do
    test "warns when pagination is configured but action doesn't support it" do
      # Use the non-paginated action with pagination_configured flag
      query = Ash.Query.for_read(TestUser, :by_name, %{name: "Alice"})

      options = [
        actor: nil,
        filters: %{},
        sort_by: [],
        page_size: 50,
        current_page: 1,
        columns: [],
        query_opts: [],
        # User explicitly configured pagination
        pagination_configured: true
      ]

      # Capture log output to verify the warning appears
      log_output =
        capture_log(fn ->
          {:ok, {results, page_info}} = QueryBuilder.build_and_execute(query, options)

          # Should return matching results
          assert length(results) == 1
          assert page_info.non_paginated == true
        end)

      # Should warn about pagination configuration mismatch
      assert log_output =~ "Table configured with page_size but action"
      assert log_output =~ "doesn't support pagination"
      assert log_output =~ "https://hexdocs.pm/ash/pagination.html"
    end

    test "does not warn when pagination is not explicitly configured" do
      # Use the non-paginated action without pagination_configured flag
      query = Ash.Query.for_read(TestUser, :by_name, %{name: "Alice"})

      options = [
        actor: nil,
        filters: %{},
        sort_by: [],
        # Default page size
        page_size: 25,
        current_page: 1,
        columns: [],
        query_opts: []
        # pagination_configured: false (implicit)
      ]

      # Capture log output to verify no warning appears
      log_output =
        capture_log(fn ->
          {:ok, {results, page_info}} = QueryBuilder.build_and_execute(query, options)

          # Should return matching results
          assert length(results) == 1
          assert page_info.non_paginated == true
        end)

      # Should not warn about pagination
      refute log_output =~ "Table configured with page_size"
      refute log_output =~ "doesn't support pagination"
    end
  end
end
