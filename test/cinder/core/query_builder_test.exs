defmodule Cinder.QueryBuilderTest do
  use ExUnit.Case, async: true
  use Mimic
  import ExUnit.CaptureLog

  require Ash.Query
  alias Cinder.QueryBuilder

  # Test embedded resources
  defmodule TestAddress do
    use Ash.Resource, data_layer: :embedded

    attributes do
      attribute(:street, :string, public?: true)
    end
  end

  defmodule TestSettings do
    use Ash.Resource, data_layer: :embedded

    attributes do
      attribute(:theme, :string, public?: true)
      attribute(:address, TestAddress, public?: true)
    end
  end

  defmodule TestProfile do
    use Ash.Resource, data_layer: :embedded

    attributes do
      attribute(:first_name, :string, public?: true)
      attribute(:age, :integer, public?: true)
    end
  end

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
      attribute(:profile, TestProfile, public?: true)
      attribute(:settings, TestSettings, public?: true)
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

    calculations do
      calculate(:track_count, :integer, expr(10))
    end

    actions do
      defaults([:read])

      create :create do
        primary?(true)
        accept([:title, :publisher])
      end
    end
  end

  # Test resource for search testing
  defmodule SearchTestResource do
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
      attribute(:description, :string, public?: true)
      attribute(:status, :string, public?: true)
    end

    actions do
      defaults([:read])
    end
  end

  defmodule TestDomain do
    use Ash.Domain, validate_config_inclusion?: false

    resources do
      resource(TestUser)
      resource(Album)
      resource(SearchTestResource)
    end
  end

  # Test scope struct that implements Ash.Scope.ToOpts protocol
  defmodule TestScope do
    defstruct [:current_user, :current_tenant, :tz]

    defimpl Ash.Scope.ToOpts do
      def get_actor(%{current_user: current_user}), do: {:ok, current_user}
      def get_tenant(%{current_tenant: current_tenant}), do: {:ok, current_tenant}
      def get_context(%{tz: tz}) when not is_nil(tz), do: {:ok, %{shared: %{tz: tz}}}
      def get_context(_), do: :error
      def get_tracer(_), do: :error
      def get_authorize?(_), do: :error
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

  describe "validate_sortable_fields/2" do
    test "handles calculation field sorting" do
      # Test calculation fields work correctly
      sort_by = [{"track_count", :asc}]
      result = QueryBuilder.validate_sortable_fields(sort_by, Album)
      assert result == :ok
    end

    test "handles regular field sorting" do
      # Test regular fields work correctly
      sort_by = [{"title", :asc}]
      result = QueryBuilder.validate_sortable_fields(sort_by, Album)
      assert result == :ok
    end

    test "handles mixed calculation and field sorting" do
      # Test combination of different field types
      sort_by = [
        {"track_count", :asc},
        {"title", :desc}
      ]

      result = QueryBuilder.validate_sortable_fields(sort_by, Album)
      assert result == :ok
    end

    test "handles invalid field gracefully" do
      # Test that invalid fields return error instead of crashing
      invalid_sort = [{"nonexistent_field", :asc}]
      result = QueryBuilder.validate_sortable_fields(invalid_sort, Album)

      case result do
        :ok ->
          # This is fine - might be valid in some contexts
          :ok

        {:error, message} ->
          # Error message should be helpful
          assert is_binary(message)
          assert String.contains?(message, "nonexistent_field")
      end
    end
  end

  describe "resolve_field_resource/2" do
    test "handles direct fields" do
      # Should handle direct fields
      {resource, field} = QueryBuilder.resolve_field_resource(Album, "title")
      assert resource == Album
      assert field == "title"
    end

    test "handles calculation fields" do
      # Should handle calculations
      {resource, field} = QueryBuilder.resolve_field_resource(Album, "track_count")
      assert resource == Album
      assert field == "track_count"
    end

    test "handles relationship fields correctly" do
      # Test that it handles dot notation gracefully (even if relationship doesn't exist)
      {resource, field} = QueryBuilder.resolve_field_resource(Album, "artist.name")

      # Should return something reasonable, doesn't need to be perfect since relationship doesn't exist
      assert is_atom(resource)
      assert is_binary(field)
    end
  end

  describe "string-based sorting integration" do
    test "build_and_execute handles string-based field sorting" do
      # Integration test for string-based sorting (both regular and relationship fields)
      columns = [
        %{field: "title", label: "Title", sortable: true},
        %{field: "track_count", label: "Track Count", sortable: true}
      ]

      sort_by = [{"title", :asc}, {"track_count", :desc}]

      # This should work with string-based sorting
      result =
        QueryBuilder.build_and_execute(
          Album,
          filters: %{},
          sort_by: sort_by,
          current_page: 1,
          page_size: 10,
          columns: columns,
          actor: nil,
          tenant: nil,
          query_opts: []
        )

      # Should return either success or error, but should NOT crash
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  describe "page_size validation" do
    test "strips negative page_size and uses default" do
      options = [
        actor: nil,
        filters: %{},
        sort_by: [],
        page_size: -5,
        current_page: 1,
        columns: [],
        query_opts: []
      ]

      # Mock the query execution to verify default page_size (25) is used instead of -5
      expect(Ash, :read, fn query, _opts ->
        # Should use default page_size of 25, not the invalid -5
        assert Keyword.get(query.page, :limit) == 25
        {:ok, %Ash.Page.Offset{results: [], count: 0, limit: 25, offset: 0, more?: false}}
      end)

      {:ok, _page} = QueryBuilder.build_and_execute(TestUser, options)
    end

    test "strips zero page_size and uses default" do
      options = [
        actor: nil,
        filters: %{},
        sort_by: [],
        page_size: 0,
        current_page: 1,
        columns: [],
        query_opts: []
      ]

      # Zero page_size should also be treated as invalid and use default (25)
      expect(Ash, :read, fn query, _opts ->
        # Should use default page_size of 25, not the invalid 0
        assert Keyword.get(query.page, :limit) == 25
        {:ok, %Ash.Page.Offset{results: [], count: 0, limit: 25, offset: 0, more?: false}}
      end)

      {:ok, _page} = QueryBuilder.build_and_execute(TestUser, options)
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

      # Suppress expected warning about unsupported option
      {result, _logs} =
        ExUnit.CaptureLog.with_log(fn ->
          QueryBuilder.apply_query_opts(query, opts)
        end)

      assert result == query
    end

    test "ignores unknown options" do
      query = %MockQueryOpts{resource: TestResource}
      opts = [unknown: "value", another: "test"]

      # Suppress expected warning about unsupported options
      {result, _logs} =
        ExUnit.CaptureLog.with_log(fn ->
          QueryBuilder.apply_query_opts(query, opts)
        end)

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

    test "warns when unsupported query_opts are provided" do
      query = Ash.Query.new(TestUser)
      opts = [filter: %{status: :active}, unknown_option: "value", load: [:posts]]

      log =
        capture_log(fn ->
          QueryBuilder.apply_query_opts(query, opts)
        end)

      # Should warn about unsupported options
      assert log =~ "Unsupported query_opts provided: [:filter, :unknown_option]"
    end

    test "does not warn when only supported query_opts are provided" do
      query = Ash.Query.new(TestUser)
      opts = [load: [:posts], select: [:id, :name], tenant: "test", timeout: 5000]

      log =
        capture_log(fn ->
          QueryBuilder.apply_query_opts(query, opts)
        end)

      # Should not contain any warnings
      refute log =~ "Unsupported query_opts"
    end

    test "does not warn when no query_opts are provided" do
      query = Ash.Query.new(TestUser)
      opts = []

      log =
        capture_log(fn ->
          QueryBuilder.apply_query_opts(query, opts)
        end)

      # Should not contain any warnings
      refute log =~ "Unsupported query_opts"
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
      assert {:ok, page} = result
      assert is_list(page.results)
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
      assert {:ok, page} = result
      assert is_list(page.results)
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
      assert {:ok, page} = result
      assert is_list(page.results)
    end
  end

  describe "build_and_execute/2 with bulk_actions" do
    test "returns list of IDs when bulk_actions is true" do
      options = [
        actor: nil,
        filters: %{},
        sort_by: [],
        page_size: 25,
        current_page: 1,
        columns: [],
        query_opts: [],
        bulk_actions: true,
        id_field: :id
      ]

      result = QueryBuilder.build_and_execute(TestUser, options)
      assert {:ok, ids} = result
      assert is_list(ids)
    end

    test "applies filters before returning IDs" do
      options = [
        actor: nil,
        filters: %{"name" => %{type: :text, value: "NonexistentName", operator: :contains}},
        sort_by: [],
        page_size: 25,
        current_page: 1,
        columns: [%{field: "name", filter_fn: nil, filterable: true, filter_type: :text}],
        query_opts: [],
        bulk_actions: true,
        id_field: :id
      ]

      result = QueryBuilder.build_and_execute(TestUser, options)
      assert {:ok, ids} = result
      # Should return empty list since no records match
      assert ids == []
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

  describe "apply_sorting/2" do
    test "returns query unchanged when no sorting" do
      query = %MockQuerySorts{resource: TestResource}
      sort_by = []

      result = QueryBuilder.apply_sorting(query, sort_by)
      assert result == query
    end

    test "handles standard sorts without custom functions" do
      query = %MockQuerySorts{resource: TestResource}
      sort_by = [{"title", :desc}]

      # This will fail with mock query when it tries to apply standard sort
      # but that's expected since we're using a mock query struct
      assert_raise ArgumentError, fn ->
        QueryBuilder.apply_sorting(query, sort_by)
      end
    end

    test "supports all embedded field sorting patterns - GitHub issue #51" do
      query = Ash.Query.new(TestUser)

      # Test basic embedded field
      basic_result = QueryBuilder.apply_sorting(query, [{"profile__first_name", :asc}])
      assert length(basic_result.sort) == 1

      # Test nested embedded field
      nested_result = QueryBuilder.apply_sorting(query, [{"settings__address__street", :desc}])
      assert length(nested_result.sort) == 1

      # Test that embedded fields get converted to calc expressions (not rejected)
      assert length(basic_result.sort) == 1
      # No NoSuchField errors
      assert Enum.empty?(basic_result.errors)

      assert length(nested_result.sort) == 1
      assert Enum.empty?(nested_result.errors)
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

      # This should not crash with Protocol.UndefinedError
      # The function should handle invalid input gracefully and return original query
      {result, _logs} =
        with_log(fn -> QueryBuilder.apply_sorting(query, invalid_sort_by) end)

      assert result == query

      # Test with completely wrong data type
      invalid_sort_by2 = ["not_a_tuple"]

      {result2, _logs} =
        with_log(fn -> QueryBuilder.apply_sorting(query, invalid_sort_by2) end)

      assert result2 == query

      # Test with Ash.Query struct (the original issue scenario)
      # This would previously cause Protocol.UndefinedError
      invalid_sort_by3 = [query]

      {result3, _logs} =
        with_log(fn -> QueryBuilder.apply_sorting(query, invalid_sort_by3) end)

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
      # Before the fix, this would crash with:
      # Protocol.UndefinedError) protocol String.Chars not implemented for type Ash.Query
      # After the fix, it should handle gracefully and return original query
      {result, _logs} =
        with_log(fn -> QueryBuilder.apply_sorting(query, problematic_sort_by) end)

      assert result == query

      # Test with actual string conversion that would have caused the original error
      # This simulates what would happen if the invalid data reached string interpolation
      {result, logs} =
        with_log(fn ->
          QueryBuilder.apply_sorting(query, problematic_sort_by)
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
      # Currently this test will fail because existing sorts take precedence
      # The query will have both sorts: [{:name, :desc}, {:email, :asc}]
      # But we want only the table sort: [{:email, :asc}]
      result = QueryBuilder.apply_sorting(query_with_existing_sorts, sort_by)

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
        {:ok, %Ash.Page.Offset{results: [], count: 0, limit: 25, offset: 0, more?: false}}
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
        {:ok, %Ash.Page.Offset{results: [], count: 0, limit: 25, offset: 0, more?: false}}
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
        {:ok, %Ash.Page.Offset{results: [], count: 0, limit: 25, offset: 0, more?: false}}
      end)

      # Suppress expected warnings about unsupported options
      ExUnit.CaptureLog.with_log(fn ->
        QueryBuilder.build_and_execute(TestUser, options)
      end)

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
        {:ok, %Ash.Page.Offset{results: [], count: 0, limit: 25, offset: 0, more?: false}}
      end)

      QueryBuilder.build_and_execute(TestUser, options)

      assert_received {:ash_read_called, ash_opts}
      assert Keyword.get(ash_opts, :actor) == :test_actor
      refute Keyword.has_key?(ash_opts, :timeout)
      refute Keyword.has_key?(ash_opts, :authorize?)
      refute Keyword.has_key?(ash_opts, :max_concurrency)
    end
  end

  describe "normalize_resource_or_query/4 - query option bugs" do
    defp default_options(overrides \\ []) do
      [
        actor: :test_actor,
        tenant: nil,
        filters: %{},
        sort_by: [],
        page_size: 25,
        current_page: 1,
        columns: [],
        query_opts: []
      ]
      |> Keyword.merge(overrides)
    end

    test "explicit tenant overrides query tenant" do
      query_with_tenant = Ash.Query.for_read(TestUser, :read, %{}, tenant: "query_tenant")

      expect(Ash, :read, fn _query, opts ->
        send(self(), {:ash_opts, opts})
        {:ok, %Ash.Page.Offset{results: [], count: 0, limit: 25, offset: 0, more?: false}}
      end)

      QueryBuilder.build_and_execute(
        query_with_tenant,
        default_options(tenant: "explicit_tenant")
      )

      assert_received {:ash_opts, ash_opts}
      assert Keyword.get(ash_opts, :tenant) == "explicit_tenant"
    end

    test "query built from resource preserves filters and sorts" do
      # Reproduces the main bug: Resource |> Ash.Query.filter(...) loses modifications
      query_without_for_read =
        TestUser
        |> Ash.Query.filter(name == "test")
        |> Ash.Query.sort(:email)

      expect(Ash, :read, fn query, _opts ->
        send(self(), {:final_query, query})
        {:ok, %Ash.Page.Offset{results: [], count: 0, limit: 25, offset: 0, more?: false}}
      end)

      QueryBuilder.build_and_execute(query_without_for_read, default_options())

      assert_received {:final_query, final_query}
      assert final_query.filter != nil
      assert final_query.sort != []
    end

    test "query_opts applied to existing query" do
      base_query = Ash.Query.for_read(TestUser, :read)

      expect(Ash, :read, fn _query, opts ->
        send(self(), {:ash_opts, opts})
        {:ok, %Ash.Page.Offset{results: [], count: 0, limit: 25, offset: 0, more?: false}}
      end)

      QueryBuilder.build_and_execute(base_query, default_options(query_opts: [timeout: 5000]))

      assert_received {:ash_opts, ash_opts}
      assert Keyword.get(ash_opts, :timeout) == 5000
    end

    test "query tenant is preserved when no explicit tenant provided" do
      # This tests the actual bug: Ash.Query.set_tenant should be recognized
      query_with_tenant =
        TestUser
        |> Ash.Query.set_tenant("query_tenant")

      expect(Ash, :read, fn _query, opts ->
        send(self(), {:ash_opts, opts})
        {:ok, %Ash.Page.Offset{results: [], count: 0, limit: 25, offset: 0, more?: false}}
      end)

      # No explicit tenant provided (tenant: nil)
      QueryBuilder.build_and_execute(query_with_tenant, default_options())

      assert_received {:ash_opts, ash_opts}
      assert Keyword.get(ash_opts, :tenant) == "query_tenant"
    end

    test "context is properly merged without overwriting existing context" do
      # Create a query with existing context
      base_query = Ash.Query.for_read(TestUser, :read)

      query_with_context =
        Ash.Query.set_context(base_query, %{custom_flag: true, other_data: "test"})

      expect(Ash, :read, fn query, _opts ->
        send(self(), {:final_query_context, query.context})
        {:ok, %Ash.Page.Offset{results: [], count: 0, limit: 25, offset: 0, more?: false}}
      end)

      # Pass actor that should be merged with existing context
      QueryBuilder.build_and_execute(query_with_context, default_options(actor: :test_actor))

      assert_received {:final_query_context, final_context}
      assert final_context.actor == :test_actor
      assert final_context.custom_flag == true
      assert final_context.other_data == "test"
    end
  end

  describe "apply_search/4" do
    test "returns original query when search_term is nil" do
      query = Ash.Query.for_read(SearchTestResource, :read)
      columns = [%{field: "title", searchable: true}]

      result = QueryBuilder.apply_search(query, nil, columns, nil)
      assert result == query
    end

    test "returns original query when search_term is empty string" do
      query = Ash.Query.for_read(SearchTestResource, :read)
      columns = [%{field: "title", searchable: true}]

      result = QueryBuilder.apply_search(query, "", columns, nil)
      assert result == query
    end

    test "returns original query when no searchable columns exist" do
      query = Ash.Query.for_read(SearchTestResource, :read)
      columns = [%{field: "title", searchable: false}]

      result = QueryBuilder.apply_search(query, "test", columns, nil)
      assert result == query
    end

    test "applies default search across single searchable column" do
      query = Ash.Query.for_read(SearchTestResource, :read)
      columns = [%{field: "title", searchable: true}]

      result = QueryBuilder.apply_search(query, "widget", columns, nil)

      # Should have applied a filter
      assert result != query
      assert result.filter != nil
    end

    test "applies default search across multiple searchable columns" do
      query = Ash.Query.for_read(SearchTestResource, :read)

      columns = [
        %{field: "title", searchable: true},
        %{field: "description", searchable: true},
        %{field: "status", searchable: false}
      ]

      result = QueryBuilder.apply_search(query, "widget", columns, nil)

      # Should have applied a filter combining title and description (but not status)
      assert result != query
      assert result.filter != nil

      # Verify the query can actually be executed without errors
      assert {:ok, _results} = Ash.read(result)
    end

    test "multiple searchable columns create proper OR logic with query execution verification" do
      query = Ash.Query.for_read(SearchTestResource, :read)

      # Test 2 columns
      two_columns = [
        %{field: "title", searchable: true},
        %{field: "description", searchable: true}
      ]

      two_result = QueryBuilder.apply_search(query, "test", two_columns, nil)
      assert two_result != query
      assert two_result.filter != nil
      assert {:ok, _results} = Ash.read(two_result)

      # Test 3 columns for more complex OR logic
      three_columns = [
        %{field: "title", searchable: true},
        %{field: "description", searchable: true},
        %{field: "status", searchable: true}
      ]

      three_result = QueryBuilder.apply_search(query, "test", three_columns, nil)
      assert three_result != query
      assert three_result.filter != nil
      assert {:ok, _results} = Ash.read(three_result)

      # Verify single vs multiple field queries produce different filters
      single_result =
        QueryBuilder.apply_search(query, "test", [%{field: "title", searchable: true}], nil)

      assert single_result.filter != two_result.filter
      assert two_result.filter != three_result.filter
    end

    test "calls custom search function when provided" do
      query = Ash.Query.for_read(SearchTestResource, :read)
      columns = [%{field: "title", searchable: true}]

      # Mock custom search function
      custom_search_fn = fn query, searchable_columns, search_term ->
        assert search_term == "widget"
        assert length(searchable_columns) == 1
        assert hd(searchable_columns).field == "title"

        # Return modified query for verification
        Ash.Query.filter(query, title == "custom_search_applied")
      end

      result = QueryBuilder.apply_search(query, "widget", columns, custom_search_fn)

      # Should have applied custom search function
      assert result != query
      assert result.filter != nil
    end

    test "handles URL-safe field notation in default search" do
      query = Ash.Query.for_read(SearchTestResource, :read)
      columns = [%{field: "user__profile__name", searchable: true}]

      # Should not crash even with complex field notation
      result = QueryBuilder.apply_search(query, "test", columns, nil)

      # The function should handle this gracefully (even if it doesn't work perfectly)
      assert result != nil
    end

    test "handles errors gracefully and returns original query" do
      query = Ash.Query.for_read(SearchTestResource, :read)
      columns = [%{field: "nonexistent_field", searchable: true}]

      # Should handle invalid fields gracefully and log a warning
      result = QueryBuilder.apply_search(query, "test", columns, nil)

      # Should return original query on error
      assert result == query
    end

    test "handles mixed valid and invalid fields correctly" do
      query = Ash.Query.for_read(SearchTestResource, :read)

      columns = [
        # Valid field
        %{field: "title", searchable: true},
        # Invalid field
        %{field: "nonexistent_field", searchable: true},
        # Valid field
        %{field: "description", searchable: true}
      ]

      result = QueryBuilder.apply_search(query, "test", columns, nil)

      # Should create a search query using only the valid fields
      assert result != query
      assert result.filter != nil

      # Should execute successfully (invalid field filtered out)
      assert {:ok, _results} = Ash.read(result)
    end

    test "search query execution produces expected filter structure" do
      query = Ash.Query.for_read(SearchTestResource, :read)

      # Single field case
      single_result =
        QueryBuilder.apply_search(query, "test", [%{field: "title", searchable: true}], nil)

      # Multiple field case
      multi_result =
        QueryBuilder.apply_search(
          query,
          "test",
          [
            %{field: "title", searchable: true},
            %{field: "description", searchable: true}
          ],
          nil
        )

      # Both should execute successfully
      assert {:ok, _results} = Ash.read(single_result)
      assert {:ok, _results} = Ash.read(multi_result)

      # Multi-field should have different (more complex) filter structure
      assert single_result.filter != multi_result.filter
    end

    test "preserves existing query filters when applying search" do
      query =
        SearchTestResource
        |> Ash.Query.for_read(:read)
        |> Ash.Query.filter(status == "active")

      columns = [%{field: "title", searchable: true}]

      result = QueryBuilder.apply_search(query, "widget", columns, nil)

      # Should have both the original filter and the new search filter
      assert result != query
      assert result.filter != nil
      assert result.filter != query.filter
    end
  end

  describe "scope passthrough" do
    test "extracts actor/tenant from scope when no explicit values provided" do
      scope = %TestScope{
        current_user: :scope_actor,
        current_tenant: "scope_tenant",
        tz: nil
      }

      options = [
        actor: nil,
        tenant: nil,
        scope: scope,
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
        {:ok, %Ash.Page.Offset{results: [], count: 0, limit: 25, offset: 0, more?: false}}
      end)

      QueryBuilder.build_and_execute(TestUser, options)

      assert_received {:ash_read_called, ash_opts}
      # Should extract actor/tenant from scope
      assert Keyword.get(ash_opts, :actor) == :scope_actor
      assert Keyword.get(ash_opts, :tenant) == "scope_tenant"
    end

    test "passes full scope options including context to Ash.read" do
      # Using our TestScope that implements Ash.Scope.ToOpts protocol
      scope = %TestScope{
        current_user: :scope_actor,
        current_tenant: "scope_tenant",
        tz: "America/New_York"
      }

      options = [
        actor: nil,
        tenant: nil,
        scope: scope,
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
        {:ok, %Ash.Page.Offset{results: [], count: 0, limit: 25, offset: 0, more?: false}}
      end)

      QueryBuilder.build_and_execute(TestUser, options)

      assert_received {:ash_read_called, ash_opts}
      assert Keyword.get(ash_opts, :actor) == :scope_actor
      assert Keyword.get(ash_opts, :tenant) == "scope_tenant"
      assert Keyword.get(ash_opts, :context) == %{shared: %{tz: "America/New_York"}}
    end

    test "explicit actor/tenant override scope values" do
      scope = %TestScope{
        current_user: :scope_actor,
        current_tenant: "scope_tenant",
        tz: "America/New_York"
      }

      options = [
        actor: :explicit_actor,
        tenant: "explicit_tenant",
        scope: scope,
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
        {:ok, %Ash.Page.Offset{results: [], count: 0, limit: 25, offset: 0, more?: false}}
      end)

      QueryBuilder.build_and_execute(TestUser, options)

      assert_received {:ash_read_called, ash_opts}
      # Explicit values should override scope values
      assert Keyword.get(ash_opts, :actor) == :explicit_actor
      assert Keyword.get(ash_opts, :tenant) == "explicit_tenant"
      # But other scope options should still be passed through
      assert Keyword.get(ash_opts, :context) == %{shared: %{tz: "America/New_York"}}
    end

    test "extracts actor/tenant from TestScope when no explicit values" do
      scope = %TestScope{
        current_user: :scope_actor,
        current_tenant: "scope_tenant",
        tz: nil
      }

      options = [
        actor: nil,
        tenant: nil,
        scope: scope,
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
        {:ok, %Ash.Page.Offset{results: [], count: 0, limit: 25, offset: 0, more?: false}}
      end)

      QueryBuilder.build_and_execute(TestUser, options)

      assert_received {:ash_read_called, ash_opts}
      assert Keyword.get(ash_opts, :actor) == :scope_actor
      assert Keyword.get(ash_opts, :tenant) == "scope_tenant"
    end

    test "uses actor/tenant when no scope provided" do
      options = [
        actor: :explicit_actor,
        tenant: "explicit_tenant",
        scope: nil,
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
        {:ok, %Ash.Page.Offset{results: [], count: 0, limit: 25, offset: 0, more?: false}}
      end)

      QueryBuilder.build_and_execute(TestUser, options)

      assert_received {:ash_read_called, ash_opts}
      assert Keyword.get(ash_opts, :actor) == :explicit_actor
      assert Keyword.get(ash_opts, :tenant) == "explicit_tenant"
    end
  end
end
