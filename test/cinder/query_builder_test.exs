defmodule Cinder.QueryBuilderTest do
  use ExUnit.Case, async: true

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

  describe "build_page_info_from_list/3" do
    test "builds pagination info from results list" do
      results = Enum.map(1..25, &%{id: &1})
      current_page = 1
      page_size = 25

      result = QueryBuilder.build_page_info_from_list(results, current_page, page_size)

      assert result.current_page == 1
      assert result.total_pages == 1
      assert result.total_count == 25
      assert result.has_next_page == false
      assert result.has_previous_page == false
      assert result.start_index == 1
      assert result.end_index == 25
    end

    test "handles partial page" do
      results = Enum.map(1..10, &%{id: &1})
      current_page = 2
      page_size = 25

      result = QueryBuilder.build_page_info_from_list(results, current_page, page_size)

      assert result.current_page == 2
      assert result.total_pages == 1
      assert result.total_count == 10
      assert result.has_next_page == false
      assert result.has_previous_page == true
      assert result.start_index == 26
      assert result.end_index == 10
    end

    test "handles empty results" do
      results = []
      current_page = 1
      page_size = 25

      result = QueryBuilder.build_page_info_from_list(results, current_page, page_size)

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
      columns = [%{key: "title", filter_fn: custom_filter_fn}]

      result = QueryBuilder.apply_filters(query, filters, columns)
      assert result.filters == [:custom_applied]
    end

    test "attempts to apply standard filters for columns without custom functions" do
      query = %MockQueryFilters{resource: TestResource}
      filters = %{"title" => %{type: :text, value: "test", operator: :contains}}
      columns = [%{key: "title", filter_fn: nil}]

      # This will fail with mock query but that's expected since it tries to use Ash.Query
      # In real usage, this would work with actual Ash queries
      assert_raise ArgumentError, fn ->
        QueryBuilder.apply_filters(query, filters, columns)
      end
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

      columns = [%{key: "title", sort_fn: custom_sort_fn}]

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
        %{key: "title", sort_fn: custom_sort_fn},
        %{key: "created_at", sort_fn: nil}
      ]

      # This will fail with mock query when it tries to apply standard sort
      assert_raise ArgumentError, fn ->
        QueryBuilder.apply_sorting(query, sort_by, columns)
      end
    end
  end
end
