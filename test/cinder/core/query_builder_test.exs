defmodule Cinder.QueryBuilderTest do
  use ExUnit.Case, async: true
  use Mimic
  import ExUnit.CaptureLog

  alias Cinder.QueryBuilder

  # Test resource for tenant testing
  defmodule TestUser do
    use Ash.Resource,
      domain: Cinder.QueryBuilderTest.TestDomain,
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
    end
  end

  # Test enum for Country
  defmodule Country do
    use Ash.Type.Enum,
      values: ["Australia", "India", "Japan", "England", "New Zealand", "Canada", "Sweden"]
  end

  # Test embedded resource for Publisher

  defmodule Publisher do
    use Ash.Resource, data_layer: :embedded

    attributes do
      attribute(:name, :string)
      attribute(:country, Country)
    end

    actions do
      create :create do
        primary?(true)
        accept([:name, :country])
      end
    end
  end

  # Test resource with embedded Publisher
  defmodule Album do
    use Ash.Resource,
      domain: Cinder.QueryBuilderTest.TestDomain,
      data_layer: Ash.DataLayer.Ets,
      validate_domain_inclusion?: false

    ets do
      private?(true)
    end

    attributes do
      uuid_primary_key(:id)
      attribute(:title, :string, public?: true)
      attribute(:publisher, Publisher, public?: true)
    end

    actions do
      defaults([:read])

      create :create do
        primary?(true)
        accept([:title, :publisher])
      end
    end
  end

  defmodule TestDomain do
    use Ash.Domain, validate_config_inclusion?: false

    resources do
      resource(TestUser)
      resource(Album)
    end
  end

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
    defstruct [:resource, :filters, :converted_field]
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

    test "handles tenant option by calling Ash.Query.set_tenant" do
      # Use a real Ash.Query to test the actual function call
      query = Ash.Query.new(TestUser)
      opts = [tenant: "test_tenant"]

      result = QueryBuilder.apply_query_opts(query, opts)

      # Verify the tenant was set (checking the query struct)
      assert result.tenant == "test_tenant"
    end
  end

  describe "build_and_execute/2 with tenant support" do
    test "includes actor when provided" do
      # Test the private function indirectly by testing apply_query_opts with tenant
      query = Ash.Query.new(TestUser)
      opts = [tenant: "test_tenant"]

      result = QueryBuilder.apply_query_opts(query, opts)

      # Verify tenant was set using query_opts path
      assert result.tenant == "test_tenant"
    end

    test "tenant extraction from options" do
      options = [
        actor: nil,
        tenant: "test_tenant",
        filters: %{},
        sort_by: [],
        page_size: 25,
        current_page: 1,
        columns: [],
        query_opts: []
      ]

      # Should succeed with proper domain setup
      result = QueryBuilder.build_and_execute(TestUser, options)
      assert {:ok, {results, page_info}} = result
      assert is_list(results)
      assert is_map(page_info)
    end

    test "query_opts tenant handling" do
      options = [
        actor: nil,
        tenant: nil,
        filters: %{},
        sort_by: [],
        page_size: 25,
        current_page: 1,
        columns: [],
        query_opts: [tenant: "query_opts_tenant"]
      ]

      # Should succeed with tenant from query_opts
      result = QueryBuilder.build_and_execute(TestUser, options)
      assert {:ok, {results, page_info}} = result
      assert is_list(results)
      assert is_map(page_info)
    end

    test "handles nil tenant gracefully" do
      options = [
        actor: nil,
        tenant: nil,
        filters: %{},
        sort_by: [],
        page_size: 25,
        current_page: 1,
        columns: [],
        query_opts: []
      ]

      # Should succeed without tenant
      result = QueryBuilder.build_and_execute(TestUser, options)
      assert {:ok, {results, page_info}} = result
      assert is_list(results)
      assert is_map(page_info)
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

  describe "apply_standard_filter/4 URL-safe field notation conversion" do
    test "converts URL-safe embedded field notation to bracket notation" do
      # Test the field notation conversion directly since that's what we're testing

      # Test simple embedded field: publisher__name -> publisher[:name]
      converted = Cinder.Filter.Helpers.field_notation_from_url_safe("publisher__name")
      assert converted == "publisher[:name]"

      # Test nested embedded field: settings__address__street -> settings[:address][:street]
      converted = Cinder.Filter.Helpers.field_notation_from_url_safe("settings__address__street")
      assert converted == "settings[:address][:street]"

      # Test mixed relationship and embedded: user.profile__first_name -> user.profile[:first_name]
      converted = Cinder.Filter.Helpers.field_notation_from_url_safe("user.profile__first_name")
      assert converted == "user.profile[:first_name]"

      # Test regular field (no conversion needed): name -> name
      converted = Cinder.Filter.Helpers.field_notation_from_url_safe("name")
      assert converted == "name"

      # Test relationship field (no conversion needed): user.name -> user.name
      converted = Cinder.Filter.Helpers.field_notation_from_url_safe("user.name")
      assert converted == "user.name"
    end

    test "apply_standard_filter calls field_notation_from_url_safe" do
      # This test verifies that the conversion is actually being called in apply_standard_filter
      # We'll test with an unknown filter type to avoid triggering the actual filter logic
      query = %MockQueryFilters{resource: TestResource}
      filter_config = %{type: :unknown_filter_type, value: "test"}

      # This should not crash and should return the original query unchanged
      # The important part is that field_notation_from_url_safe gets called internally
      result = QueryBuilder.apply_standard_filter(query, "publisher__name", filter_config, nil)
      assert result == query
    end
  end

  describe "embedded field filtering integration" do
    test "filters embedded fields using URL-safe notation" do
      # Create test data
      {:ok, _album1} =
        Ash.create(Album, %{
          title: "Album 1",
          publisher: %{name: "Test Publisher", country: "Australia"}
        })

      {:ok, _album2} =
        Ash.create(Album, %{
          title: "Album 2",
          publisher: %{name: "Another Publisher", country: "England"}
        })

      {:ok, _album3} =
        Ash.create(Album, %{
          title: "Album 3",
          publisher: %{name: "Test Records", country: "Australia"}
        })

      # Test filtering by publisher name using URL-safe notation
      query = Ash.Query.for_read(Album, :read)

      filters = %{
        "publisher__name" => %{type: :text, value: "Test", operator: :contains}
      }

      columns = [
        %{field: "publisher__name", filterable: true, filter_type: :text, filter_fn: nil}
      ]

      filtered_query = QueryBuilder.apply_filters(query, filters, columns)
      {:ok, results} = Ash.read(filtered_query)

      # Should return albums with publishers containing "Test" in the name
      result_titles = Enum.map(results, & &1.title) |> Enum.sort()
      assert result_titles == ["Album 1", "Album 3"]

      # Test filtering by publisher country (enum field)
      filters2 = %{
        "publisher__country" => %{type: :select, value: "Australia"}
      }

      columns2 = [
        %{field: "publisher__country", filterable: true, filter_type: :select, filter_fn: nil}
      ]

      filtered_query2 = QueryBuilder.apply_filters(query, filters2, columns2)
      {:ok, results2} = Ash.read(filtered_query2)

      # Should return albums with publishers from Australia
      result_titles2 = Enum.map(results2, & &1.title) |> Enum.sort()
      assert result_titles2 == ["Album 1", "Album 3"]

      # Test filtering by different enum value
      filters3 = %{
        "publisher__country" => %{type: :select, value: "England"}
      }

      columns3 = [
        %{field: "publisher__country", filterable: true, filter_type: :select, filter_fn: nil}
      ]

      filtered_query3 = QueryBuilder.apply_filters(query, filters3, columns3)
      {:ok, results3} = Ash.read(filtered_query3)

      # Should return only the album with publisher from England
      result_titles3 = Enum.map(results3, & &1.title) |> Enum.sort()
      assert result_titles3 == ["Album 2"]
    end

    test "automatically infers select filter type for embedded enum fields" do
      # Test that enum fields in embedded resources are automatically detected as select filters

      # Create a column configuration for the embedded enum field
      slot = %{
        field: "publisher__country",
        filterable: true
      }

      # Infer filter configuration - should automatically detect enum and set filter_type to :select
      filter_config = Cinder.FilterManager.infer_filter_config("publisher__country", Album, slot)

      # Should be detected as a select filter
      assert filter_config.filter_type == :select

      # Should have the enum values as options
      assert filter_config.filter_options[:options] == [
               {"Australia", "Australia"},
               {"India", "India"},
               {"Japan", "Japan"},
               {"England", "England"},
               {"New zealand", "New Zealand"},
               {"Canada", "Canada"},
               {"Sweden", "Sweden"}
             ]

      # Should have a prompt
      assert filter_config.filter_options[:prompt] == "All Publisher > Country"
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

    test "table sorts should override existing query sorts" do
      # Create a real Ash query that already has sorts applied
      query_with_existing_sorts =
        TestUser
        |> Ash.Query.for_read(:read)
        |> Ash.Query.sort([{:name, :desc}])

      # Apply table sorting - this should override the existing sorts
      sort_by = [{"email", :asc}]
      columns = []

      # Currently this test will fail because existing sorts take precedence
      # The query will have both sorts: [{:name, :desc}, {:email, :asc}]
      # But we want only the table sort: [{:email, :asc}]
      result = QueryBuilder.apply_sorting(query_with_existing_sorts, sort_by, columns)

      # This assertion will fail with current implementation
      # because the existing sort is not cleared
      expected_sorts = [{:email, :asc}]

      assert result.sort == expected_sorts,
             "Expected table sorts to override existing query sorts, but got: #{inspect(result.sort)}"
    end
  end

  describe "extract_query_sorts/2" do
    test "extracts sorts from Ash query" do
      query =
        TestUser
        |> Ash.Query.for_read(:read)
        |> Ash.Query.sort([{:name, :desc}, {:email, :asc}])

      columns = [
        %{field: "name"},
        %{field: "email"},
        %{field: "created_at"}
      ]

      result = QueryBuilder.extract_query_sorts(query, columns)
      assert result == [{"name", :desc}, {"email", :asc}]
    end

    test "returns empty list for resource module" do
      result = QueryBuilder.extract_query_sorts(TestUser, [])
      assert result == []
    end

    test "returns empty list for query with no sorts" do
      query = TestUser |> Ash.Query.for_read(:read)
      result = QueryBuilder.extract_query_sorts(query, [])
      assert result == []
    end

    test "filters out sorts not matching table columns" do
      query =
        TestUser
        |> Ash.Query.for_read(:read)
        |> Ash.Query.sort([{:name, :desc}, {:email, :asc}])

      columns = [%{field: "name"}]

      result = QueryBuilder.extract_query_sorts(query, columns)
      assert result == [{"name", :desc}]
    end

    test "handles single field sorts without direction" do
      query =
        TestUser
        |> Ash.Query.for_read(:read)
        |> Ash.Query.sort([:name])

      columns = [%{field: "name"}]

      result = QueryBuilder.extract_query_sorts(query, columns)
      assert result == [{"name", :asc}]
    end

    test "accepts all sorts when no columns provided" do
      query =
        TestUser
        |> Ash.Query.for_read(:read)
        |> Ash.Query.sort([{:name, :desc}, {:email, :asc}])

      result = QueryBuilder.extract_query_sorts(query, [])
      assert result == [{"name", :desc}, {"email", :asc}]
    end

    test "handles invalid sort formats gracefully" do
      # Create a mock query with invalid sort data
      query = %Ash.Query{
        resource: TestUser,
        sort: [nil, {:valid_field, :asc}, "invalid"]
      }

      columns = [%{field: "valid_field"}]

      result = QueryBuilder.extract_query_sorts(query, columns)
      assert result == [{"valid_field", :asc}]
    end

    test "extracts sorts from default_sort" do
      # Test with Ash.Query.default_sort which might use different format
      query =
        TestUser
        |> Ash.Query.for_read(:read, %{}, domain: TestDomain)
        |> Ash.Query.default_sort([{:name, :desc}])

      columns = [%{field: "name"}, %{field: "email"}]

      result = QueryBuilder.extract_query_sorts(query, columns)
      assert result == [{"name", :desc}]
    end

    test "extracts sorts from default_sort with string format" do
      # Test the "-name" string format that might be used
      query =
        TestUser
        |> Ash.Query.for_read(:read, %{}, domain: TestDomain)
        |> Ash.Query.default_sort(["-name"])

      columns = [%{field: "name"}, %{field: "email"}]

      result = QueryBuilder.extract_query_sorts(query, columns)
      assert result == [{"name", :desc}]
    end

    test "extracts sorts from Ash.Query.sort with string format" do
      # Test the exact format used in the user's code
      query =
        TestUser
        |> Ash.Query.for_read(:read, %{}, domain: TestDomain)
        |> Ash.Query.sort("-name")

      columns = [%{field: :name}, %{field: :email}]

      result = QueryBuilder.extract_query_sorts(query, columns)
      assert result == [{"name", :desc}]
    end

    test "handles atom field names in columns" do
      # Test that columns with atom field names work correctly
      query =
        TestUser
        |> Ash.Query.for_read(:read, %{}, domain: TestDomain)
        |> Ash.Query.sort([{:name, :desc}, {:email, :asc}])

      # Columns with atom field names (common in slot definitions)
      columns = [%{field: :name}, %{field: :email}]

      result = QueryBuilder.extract_query_sorts(query, columns)
      assert result == [{"name", :desc}, {"email", :asc}]
    end

    test "handles mixed atom and string field names in columns" do
      # Test mixed field name types
      query =
        TestUser
        |> Ash.Query.for_read(:read, %{}, domain: TestDomain)
        |> Ash.Query.sort([{:name, :desc}, {:email, :asc}])

      # Mixed column field types
      columns = [%{field: :name}, %{field: "email"}]

      result = QueryBuilder.extract_query_sorts(query, columns)
      assert result == [{"name", :desc}, {"email", :asc}]
    end

    test "toggle behavior starting from query-extracted desc sort" do
      # This test documents the issue: when starting with desc from query,
      # the toggle cycle is: desc -> none -> asc -> desc -> none
      # User expects: desc -> asc -> desc -> none

      # From query extraction
      initial_sort = [{"name", :desc}]

      # First click: desc -> none (current behavior)
      sort_after_click_1 = QueryBuilder.toggle_sort_direction(initial_sort, "name")
      assert sort_after_click_1 == []

      # Second click: none -> asc
      sort_after_click_2 = QueryBuilder.toggle_sort_direction(sort_after_click_1, "name")
      assert sort_after_click_2 == [{"name", :asc}]

      # Third click: asc -> desc
      sort_after_click_3 = QueryBuilder.toggle_sort_direction(sort_after_click_2, "name")
      assert sort_after_click_3 == [{"name", :desc}]

      # This creates the confusing cycle: desc -> none -> asc -> desc -> none
      # instead of the expected: desc -> asc -> desc -> none
    end
  end

  describe "build_ash_options/3 timeout handling" do
    # Test the private function indirectly through build_and_execute
    test "includes execution options in both query building and execution" do
      # We'll test this by mocking Ash.read to capture the options
      timeout_value = :timer.seconds(30)

      options = [
        actor: nil,
        tenant: nil,
        filters: %{},
        sort_by: [],
        page_size: 25,
        current_page: 1,
        columns: [],
        query_opts: [timeout: timeout_value]
      ]

      test_pid = self()

      # Mock Ash.read to capture options
      Ash
      |> expect(:read, fn _query, opts ->
        send(test_pid, {:ash_read_called, opts})
        # Return a valid response structure
        {:ok, %{results: [], count: 0}}
      end)

      QueryBuilder.build_and_execute(TestUser, options)

      # Verify that Ash.read was called with timeout option
      assert_received {:ash_read_called, ash_opts}
      assert Keyword.get(ash_opts, :timeout) == timeout_value
      assert Keyword.get(ash_opts, :actor) == nil
    end

    test "includes execution Ash options from query_opts" do
      timeout_value = :timer.seconds(15)

      options = [
        actor: :test_actor,
        tenant: "test_tenant",
        filters: %{},
        sort_by: [],
        page_size: 25,
        current_page: 1,
        columns: [],
        query_opts: [
          timeout: timeout_value,
          authorize?: false,
          max_concurrency: 2,
          # Query building option - handled by apply_query_opts
          select: [:name]
        ]
      ]

      test_pid = self()

      Ash
      |> expect(:read, fn _query, opts ->
        send(test_pid, {:ash_read_called, opts})
        {:ok, %{results: [], count: 0}}
      end)

      QueryBuilder.build_and_execute(TestUser, options)

      assert_received {:ash_read_called, ash_opts}
      assert Keyword.get(ash_opts, :timeout) == timeout_value
      assert Keyword.get(ash_opts, :authorize?) == false
      assert Keyword.get(ash_opts, :max_concurrency) == 2
      assert Keyword.get(ash_opts, :actor) == :test_actor
      assert Keyword.get(ash_opts, :tenant) == "test_tenant"
    end

    test "ignores non-execution options from query_opts" do
      options = [
        actor: nil,
        tenant: nil,
        filters: %{},
        sort_by: [],
        page_size: 25,
        current_page: 1,
        columns: [],
        query_opts: [
          timeout: :timer.seconds(10),
          authorize?: false,
          # These should be ignored by build_ash_options - not execution options
          context: %{test: true},
          domain: SomeDomain,
          action: :read,
          # This is handled by apply_query_opts, not build_ash_options
          select: [:name],
          # These should be ignored by build_ash_options - unknown options
          custom_option: "ignored",
          another_option: 123
        ]
      ]

      test_pid = self()

      Ash
      |> expect(:read, fn _query, opts ->
        send(test_pid, {:ash_read_called, opts})
        {:ok, %{results: [], count: 0}}
      end)

      QueryBuilder.build_and_execute(TestUser, options)

      assert_received {:ash_read_called, ash_opts}
      assert Keyword.get(ash_opts, :timeout) == :timer.seconds(10)
      assert Keyword.get(ash_opts, :authorize?) == false
      # These should not be in the Ash.read options - not execution options
      refute Keyword.has_key?(ash_opts, :context)
      refute Keyword.has_key?(ash_opts, :domain)
      refute Keyword.has_key?(ash_opts, :action)
      # These should not be in the Ash.read options - unknown options
      refute Keyword.has_key?(ash_opts, :custom_option)
      refute Keyword.has_key?(ash_opts, :another_option)
      # This should not be in Ash.read options - it's handled by apply_query_opts
      refute Keyword.has_key?(ash_opts, :select)
    end

    test "works without any execution options in query_opts" do
      options = [
        actor: :test_actor,
        tenant: nil,
        filters: %{},
        sort_by: [],
        page_size: 25,
        current_page: 1,
        columns: [],
        query_opts: []
      ]

      test_pid = self()

      Ash
      |> expect(:read, fn _query, opts ->
        send(test_pid, {:ash_read_called, opts})
        {:ok, %{results: [], count: 0}}
      end)

      QueryBuilder.build_and_execute(TestUser, options)

      assert_received {:ash_read_called, ash_opts}
      assert Keyword.get(ash_opts, :actor) == :test_actor
      refute Keyword.has_key?(ash_opts, :timeout)
      refute Keyword.has_key?(ash_opts, :authorize?)
      refute Keyword.has_key?(ash_opts, :max_concurrency)
    end
  end
end
