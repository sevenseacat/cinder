defmodule Cinder.QueryBuilderTest do
  use ExUnit.Case, async: true
  import ExUnit.CaptureLog

  alias Cinder.QueryBuilder

  describe "toggle_sort_direction/2" do
    test "adds ascending sort for new field" do
      current_sort = []
      result = QueryBuilder.toggle_sort_direction(current_sort, "title")
      assert result == [{"title", :asc}]
    end

    test "changes ascending to descending" do
      current_sort = [{"title", :asc}]
      result = QueryBuilder.toggle_sort_direction(current_sort, "title")
      assert result == [{"title", :desc}]
    end

    test "removes descending sort" do
      current_sort = [{"title", :desc}]
      result = QueryBuilder.toggle_sort_direction(current_sort, "title")
      assert result == []
    end

    test "preserves other sorts when toggling" do
      current_sort = [{"title", :asc}, {"created_at", :desc}]
      result = QueryBuilder.toggle_sort_direction(current_sort, "title")
      assert result == [{"title", :desc}, {"created_at", :desc}]
    end

    test "adds new sort to existing sorts" do
      current_sort = [{"created_at", :desc}]
      result = QueryBuilder.toggle_sort_direction(current_sort, "title")
      assert result == [{"title", :asc}, {"created_at", :desc}]
    end
  end

  describe "build_and_execute/2 error logging" do
    defmodule TestResource do
      use Ash.Resource, domain: nil, validate_domain_inclusion?: false

      attributes do
        uuid_primary_key(:id)
        attribute(:name, :string)
      end

      actions do
        defaults([:read])
      end
    end

    test "logs errors when query execution fails" do
      options = [
        actor: nil,
        filters: %{},
        sort_by: [],
        page_size: 25,
        current_page: 1,
        columns: [],
        query_opts: []
      ]

      log_output =
        capture_log(fn ->
          # This should fail because TestResource doesn't have a proper domain setup
          result = QueryBuilder.build_and_execute(TestResource, options)
          assert {:error, _} = result
        end)

      assert log_output =~ "Cinder table query crashed with exception for"
      assert log_output =~ "TestResource"
    end

    test "logs calculation errors with detailed error information" do
      defmodule TestResourceWithCalculation do
        use Ash.Resource, domain: nil, validate_domain_inclusion?: false

        attributes do
          uuid_primary_key(:id)
          attribute(:name, :string)
        end

        calculations do
          calculate(:failing_calc, :string, expr(fragment("INVALID_SQL_FUNCTION(?)", name)))
        end

        actions do
          defaults([:read])
        end
      end

      options = [
        actor: nil,
        filters: %{},
        sort_by: [],
        page_size: 25,
        current_page: 1,
        columns: [],
        query_opts: [load: [:failing_calc]]
      ]

      log_output =
        capture_log(fn ->
          result = QueryBuilder.build_and_execute(TestResourceWithCalculation, options)
          assert {:error, _} = result
        end)

      # Should show the resource name and actual error details
      assert log_output =~ "TestResourceWithCalculation"
      assert log_output =~ "Cinder table query crashed with exception for"
    end
  end

  describe "get_sort_direction/2" do
    test "returns nil for non-sorted field" do
      sort_by = [{"title", :asc}]
      result = QueryBuilder.get_sort_direction(sort_by, "status")
      assert result == nil
    end

    test "returns direction for sorted field" do
      sort_by = [{"title", :asc}, {"created_at", :desc}]
      assert QueryBuilder.get_sort_direction(sort_by, "title") == :asc
      assert QueryBuilder.get_sort_direction(sort_by, "created_at") == :desc
    end

    test "handles empty sort list" do
      sort_by = []
      result = QueryBuilder.get_sort_direction(sort_by, "title")
      assert result == nil
    end
  end

  describe "build_expression_sort/1" do
    test "handles relationship field" do
      result = QueryBuilder.build_expression_sort("author.name")
      assert result == {:author, :name}
    end

    test "handles simple field" do
      result = QueryBuilder.build_expression_sort("title")
      assert result == :title
    end

    test "handles complex nested field" do
      result = QueryBuilder.build_expression_sort("author.profile.name")
      # Takes first two parts for now
      assert result == {:author, :profile}
    end
  end

  describe "build_page_info_with_total_count/4" do
    test "builds correct pagination info" do
      results = [%{id: 1}, %{id: 2}, %{id: 3}]
      current_page = 2
      page_size = 25
      total_count = 100

      result =
        QueryBuilder.build_page_info_with_total_count(
          results,
          current_page,
          page_size,
          total_count
        )

      assert result.current_page == 2
      assert result.total_pages == 4
      assert result.total_count == 100
      assert result.has_next_page == true
      assert result.has_previous_page == true
      assert result.start_index == 26
      assert result.end_index == 28
    end

    test "handles first page" do
      results = Enum.map(1..25, &%{id: &1})
      current_page = 1
      page_size = 25
      total_count = 100

      result =
        QueryBuilder.build_page_info_with_total_count(
          results,
          current_page,
          page_size,
          total_count
        )

      assert result.current_page == 1
      assert result.has_next_page == true
      assert result.has_previous_page == false
      assert result.start_index == 1
      assert result.end_index == 25
    end

    test "handles last page" do
      results = Enum.map(1..10, &%{id: &1})
      current_page = 4
      page_size = 25
      total_count = 85

      result =
        QueryBuilder.build_page_info_with_total_count(
          results,
          current_page,
          page_size,
          total_count
        )

      assert result.current_page == 4
      assert result.total_pages == 4
      assert result.has_next_page == false
      assert result.has_previous_page == true
      assert result.start_index == 76
      assert result.end_index == 85
    end

    test "handles empty results" do
      results = []
      current_page = 1
      page_size = 25
      total_count = 0

      result =
        QueryBuilder.build_page_info_with_total_count(
          results,
          current_page,
          page_size,
          total_count
        )

      assert result.current_page == 1
      assert result.total_pages == 1
      assert result.total_count == 0
      assert result.has_next_page == false
      assert result.has_previous_page == false
      assert result.start_index == 0
      assert result.end_index == 0
    end
  end

  describe "build_error_page_info/0" do
    test "returns error pagination state" do
      result = QueryBuilder.build_error_page_info()

      assert result.current_page == 1
      assert result.total_pages == 1
      assert result.total_count == 0
      assert result.has_next_page == false
      assert result.has_previous_page == false
      assert result.start_index == 0
      assert result.end_index == 0
    end
  end

  # Mock query structs for testing - defined once to avoid redefinition warnings
  defmodule MockQueryOpts do
    defstruct [:resource, :loads, :selects]
  end

  defmodule MockQueryFilters do
    defstruct [:resource, :filters]
  end

  defmodule MockQuerySorts do
    defstruct [:resource, :sorts]
  end

  describe "apply_query_opts/2" do
    test "handles empty options" do
      query = %MockQueryOpts{resource: TestResource}
      opts = []

      result = QueryBuilder.apply_query_opts(query, opts)
      assert result == query
    end

    test "ignores filter options" do
      query = %MockQueryOpts{resource: TestResource}
      opts = [filter: %{title: "test"}]

      result = QueryBuilder.apply_query_opts(query, opts)
      assert result == query
    end

    test "ignores unknown options" do
      query = %MockQueryOpts{resource: TestResource}
      opts = [unknown: "value", another: "test"]

      result = QueryBuilder.apply_query_opts(query, opts)
      assert result == query
    end
  end

  describe "apply_filters/3" do
    test "returns query unchanged when no filters" do
      query = %MockQueryFilters{resource: TestResource}
      filters = %{}
      columns = []

      result = QueryBuilder.apply_filters(query, filters, columns)
      assert result == query
    end

    test "applies custom filter functions" do
      query = %MockQueryFilters{resource: TestResource}

      custom_filter_fn = fn query, _filter_config ->
        %{query | filters: [:custom_applied]}
      end

      filters = %{"title" => %{type: :text, value: "test", operator: :contains}}
      columns = [%{field: "title", filter_fn: custom_filter_fn}]

      result = QueryBuilder.apply_filters(query, filters, columns)
      assert result.filters == [:custom_applied]
    end

    test "attempts to apply standard filters for columns without custom functions" do
      query = %MockQueryFilters{resource: TestResource}
      filters = %{"title" => %{type: :text, value: "test", operator: :contains}}
      columns = [%{field: "title", filter_fn: nil}]

      # This will now gracefully handle errors and return the original query
      # instead of raising an exception. We use with_log to get both result and suppress logs.
      {result, _logs} =
        ExUnit.CaptureLog.with_log(fn ->
          QueryBuilder.apply_filters(query, filters, columns)
        end)

      assert result == query
    end
  end

  describe "apply_sorting/3" do
    test "returns query unchanged when no sorting" do
      query = %MockQuerySorts{resource: TestResource}
      sort_by = []
      columns = []

      result = QueryBuilder.apply_sorting(query, sort_by, columns)
      assert result == query
    end

    test "uses custom sort functions when present" do
      query = %MockQuerySorts{resource: TestResource}
      sort_by = [{"title", :desc}]

      custom_sort_fn = fn query, _direction ->
        %{query | sorts: [:custom_sort_applied]}
      end

      columns = [%{field: "title", sort_fn: custom_sort_fn}]

      result = QueryBuilder.apply_sorting(query, sort_by, columns)
      assert result.sorts == [:custom_sort_applied]
    end

    test "handles mixed custom and standard sorts" do
      query = %MockQuerySorts{resource: TestResource}
      sort_by = [{"title", :desc}, {"created_at", :asc}]

      custom_sort_fn = fn query, _direction ->
        %{query | sorts: (query.sorts || []) ++ [:custom_sort]}
      end

      columns = [
        %{field: "title", sort_fn: custom_sort_fn},
        %{field: "created_at", sort_fn: nil}
      ]

      # This will fail with mock query when it tries to apply standard sort
      assert_raise ArgumentError, fn ->
        QueryBuilder.apply_sorting(query, sort_by, columns)
      end
    end

    test "handles invalid sort_by input gracefully without Protocol.UndefinedError" do
      # This test verifies the fix for the specific error mentioned in the bug report
      # where invalid data might be passed to sorting functions
      import ExUnit.CaptureLog

      # Create a proper Ash query
      query = %MockQuerySorts{resource: TestResource}

      # Test scenario: when sort_by contains invalid data instead of expected tuple format
      # This should be [{"field", :asc}] format, but test with invalid data
      # Missing direction
      invalid_sort_by = [{"field"}]
      columns = []

      # This should not crash with Protocol.UndefinedError
      # The function should handle invalid input gracefully and return original query
      {result, _logs} =
        with_log(fn -> QueryBuilder.apply_sorting(query, invalid_sort_by, columns) end)

      assert result == query

      # Test with completely wrong data type
      invalid_sort_by2 = ["not_a_tuple"]

      {result2, _logs} =
        with_log(fn -> QueryBuilder.apply_sorting(query, invalid_sort_by2, columns) end)

      assert result2 == query

      # Test with Ash.Query struct (the original issue scenario)
      # This would previously cause Protocol.UndefinedError
      invalid_sort_by3 = [query]

      {result3, _logs} =
        with_log(fn -> QueryBuilder.apply_sorting(query, invalid_sort_by3, columns) end)

      assert result3 == query
    end

    test "regression test: Protocol.UndefinedError when Ash.Query passed to String.Chars" do
      # This is a specific regression test for the original issue where
      # an Ash.Query struct was being passed to string conversion functions
      import ExUnit.CaptureLog

      query = %MockQuerySorts{resource: TestResource}

      # Simulate the exact scenario that would cause Protocol.UndefinedError
      # if sort_by contained an Ash.Query instead of expected {field, direction} tuples
      # This would happen if there was a bug in data flow where queries got mixed up with sort specs
      ash_query_struct = %MockQuerySorts{resource: TestResource, sorts: [:some_sort]}
      problematic_sort_by = [ash_query_struct, {"valid_field", :asc}]
      columns = []

      # Before the fix, this would crash with:
      # Protocol.UndefinedError) protocol String.Chars not implemented for type Ash.Query
      # After the fix, it should handle gracefully and return original query
      {result, _logs} =
        with_log(fn -> QueryBuilder.apply_sorting(query, problematic_sort_by, columns) end)

      assert result == query

      # Test with actual string conversion that would have caused the original error
      # This simulates what would happen if the invalid data reached string interpolation
      {result, logs} =
        with_log(fn ->
          QueryBuilder.apply_sorting(query, problematic_sort_by, columns)
        end)

      assert result == query
      assert logs =~ "Invalid sort_by format"
      assert logs =~ "Expected list of {field, direction} tuples"
    end
  end
end
