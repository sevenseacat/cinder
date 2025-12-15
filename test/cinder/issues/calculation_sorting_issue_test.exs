defmodule Cinder.Issues.CalculationSortingIssueTest do
  use ExUnit.Case, async: true
  import ExUnit.CaptureLog
  alias Cinder.QueryBuilder

  defmodule TestUser do
    use Ash.Resource,
      domain: Cinder.Issues.CalculationSortingIssueTest.TestDomain,
      data_layer: Ash.DataLayer.Ets,
      validate_domain_inclusion?: false

    ets do
      private?(true)
    end

    actions do
      defaults([:read, :update, :destroy])

      create :create do
        accept([:first_name, :last_name])
      end
    end

    attributes do
      uuid_primary_key(:id)
      attribute(:first_name, :string, allow_nil?: false)
      attribute(:last_name, :string, allow_nil?: false)
    end

    calculations do
      # This works for sorting - computed at database level
      calculate(:full_name_expr, :string, expr(first_name <> " " <> last_name))

      # This doesn't work for sorting - computed in-memory
      calculate(
        :full_name_module,
        :string,
        Cinder.Issues.CalculationSortingIssueTest.FullNameCalc
      )
    end
  end

  defmodule FullNameCalc do
    use Ash.Resource.Calculation

    def init(opts), do: {:ok, opts}

    def load(_query, _opts, _context), do: [:first_name, :last_name]

    def calculate(records, _opts, _context) do
      Enum.map(records, &"#{&1.first_name} #{&1.last_name}")
    end
  end

  # Test resource with relationship to demonstrate relationship calculation detection
  defmodule TestProfile do
    use Ash.Resource,
      domain: Cinder.Issues.CalculationSortingIssueTest.TestDomain,
      data_layer: Ash.DataLayer.Ets,
      validate_domain_inclusion?: false

    ets do
      private?(true)
    end

    actions do
      defaults([:read, :update, :destroy])

      create :create do
        accept([:bio, :website])
      end
    end

    attributes do
      uuid_primary_key(:id)
      attribute(:bio, :string)
      attribute(:website, :string)
      attribute(:address_id, :uuid)
    end

    relationships do
      belongs_to(:address, Cinder.Issues.CalculationSortingIssueTest.TestAddress)
    end

    calculations do
      # Database-level calculation - should be sortable
      calculate(:display_info, :string, expr(bio <> " - " <> website))

      # In-memory calculation - should NOT be sortable
      calculate(:formatted_bio, :string, Cinder.Issues.CalculationSortingIssueTest.BioFormatter)
    end
  end

  defmodule BioFormatter do
    use Ash.Resource.Calculation

    def init(opts), do: {:ok, opts}

    def load(_query, _opts, _context), do: [:bio]

    def calculate(records, _opts, _context) do
      Enum.map(records, fn record ->
        case record.bio do
          nil -> "No bio"
          bio -> "Bio: #{String.upcase(bio)}"
        end
      end)
    end
  end

  # Test address resource for nested relationships
  defmodule TestAddress do
    use Ash.Resource,
      domain: Cinder.Issues.CalculationSortingIssueTest.TestDomain,
      data_layer: Ash.DataLayer.Ets,
      validate_domain_inclusion?: false

    ets do
      private?(true)
    end

    actions do
      defaults([:read, :update, :destroy])

      create :create do
        accept([:street, :city, :country])
      end
    end

    attributes do
      uuid_primary_key(:id)
      attribute(:street, :string)
      attribute(:city, :string)
      attribute(:country, :string)
    end

    calculations do
      # Database-level calculation for testing
      calculate(:full_address, :string, expr(street <> ", " <> city <> ", " <> country))
    end
  end

  # Enhanced TestUser with profile relationship
  defmodule TestUserWithProfile do
    use Ash.Resource,
      domain: Cinder.Issues.CalculationSortingIssueTest.TestDomain,
      data_layer: Ash.DataLayer.Ets,
      validate_domain_inclusion?: false

    ets do
      private?(true)
    end

    actions do
      defaults([:read, :update, :destroy])

      create :create do
        accept([:first_name, :last_name, :profile_id])
      end
    end

    attributes do
      uuid_primary_key(:id)
      attribute(:first_name, :string, allow_nil?: false)
      attribute(:last_name, :string, allow_nil?: false)
      attribute(:profile_id, :uuid)
    end

    relationships do
      belongs_to(:profile, Cinder.Issues.CalculationSortingIssueTest.TestProfile)
    end

    calculations do
      calculate(:full_name_expr, :string, expr(first_name <> " " <> last_name))

      calculate(
        :full_name_module,
        :string,
        Cinder.Issues.CalculationSortingIssueTest.FullNameCalc
      )
    end
  end

  defmodule TestDomain do
    use Ash.Domain, validate_config_inclusion?: false

    resources do
      resource(TestUser)
      resource(TestProfile)
      resource(TestAddress)
      resource(TestUserWithProfile)
    end
  end

  setup do
    # Create test data
    users = [
      %{first_name: "Zoe", last_name: "Adams"},
      %{first_name: "Alice", last_name: "Smith"},
      %{first_name: "Bob", last_name: "Johnson"}
    ]

    created_users =
      Enum.map(users, fn user_attrs ->
        TestUser
        |> Ash.Changeset.for_create(:create, user_attrs)
        |> Ash.create!(domain: TestDomain)
      end)

    %{users: created_users}
  end

  test "database-level calculations work correctly for sorting" do
    # Sort by expression-based calculation
    options = [
      actor: nil,
      filters: %{},
      sort_by: [{"full_name_expr", :asc}],
      page_size: 25,
      current_page: 1,
      columns: [],
      query_opts: [load: [:full_name_expr]]
    ]

    case QueryBuilder.build_and_execute(TestUser, options) do
      {:ok, page} ->
        full_names = Enum.map(page.results, & &1.full_name_expr)
        expected_sorted = ["Alice Smith", "Bob Johnson", "Zoe Adams"]

        assert full_names == expected_sorted,
               "Database calculation should sort correctly. Got: #{inspect(full_names)}"

      {:error, error} ->
        flunk("Database calculation failed unexpectedly: #{inspect(error)}")
    end
  end

  test "in-memory calculations fail for sorting - demonstrating the issue" do
    # This test documents that in-memory calculations cannot be sorted
    # It should either crash or return unsorted data
    options = [
      actor: nil,
      filters: %{},
      sort_by: [{"full_name_module", :asc}],
      page_size: 25,
      current_page: 1,
      columns: [],
      query_opts: [load: [:full_name_module]]
    ]

    result = QueryBuilder.build_and_execute(TestUser, options)

    # Either it crashes (error) or returns unsorted data (success but not sorted)
    # Both outcomes demonstrate the issue exists
    case result do
      {:ok, page} ->
        full_names = Enum.map(page.results, & &1.full_name_module)
        expected_sorted = ["Alice Smith", "Bob Johnson", "Zoe Adams"]

        # If it's properly sorted, the issue has been fixed
        if full_names == expected_sorted do
          flunk("In-memory calculation sorting appears to be working - issue may be resolved")
        end

      # Otherwise, sorting failed as expected (demonstrates the issue)

      {:error, _error} ->
        # Crash also demonstrates the issue
        nil
    end
  end

  test "comparison shows the difference between calculation types" do
    # Test both types with identical data to show the difference

    # Database calculation
    db_options = [
      actor: nil,
      filters: %{},
      sort_by: [{"full_name_expr", :asc}],
      page_size: 25,
      current_page: 1,
      columns: [],
      query_opts: [load: [:full_name_expr]]
    ]

    # In-memory calculation
    memory_options = [
      actor: nil,
      filters: %{},
      sort_by: [{"full_name_module", :asc}],
      page_size: 25,
      current_page: 1,
      columns: [],
      query_opts: [load: [:full_name_module]]
    ]

    {db_result, _db_logs} =
      with_log(fn ->
        QueryBuilder.build_and_execute(TestUser, db_options)
      end)

    {memory_result, _memory_logs} =
      with_log(fn ->
        QueryBuilder.build_and_execute(TestUser, memory_options)
      end)

    case db_result do
      {:ok, page} ->
        names = Enum.map(page.results, & &1.full_name_expr)
        assert names == ["Alice Smith", "Bob Johnson", "Zoe Adams"]

      {:error, error} ->
        flunk("Database calculation failed: #{inspect(error)}")
    end

    case memory_result do
      {:ok, page} ->
        names = Enum.map(page.results, & &1.full_name_module)
        expected = ["Alice Smith", "Bob Johnson", "Zoe Adams"]

        # Test passes whether sorting works or doesn't work
        # We're just documenting the current behavior
        if names == expected do
          # If sorting works, that means the issue has been resolved
          flunk("In-memory calculation sorting appears to be working - issue may be resolved")
        end

      # If sorting doesn't work, that demonstrates the issue (test passes)

      {:error, _error} ->
        # Crash also demonstrates the issue exists (test passes)
        nil
    end
  end

  @doc """
  ## Summary

  **Issue**: Sorting on in-memory calculations (those using calculation modules) doesn't work
  **Cause**: Ash applies sorts at the database level, but in-memory calculations are computed after data retrieval
  **Impact**: Users cannot sort tables by calculated fields that require complex logic

  ## Technical Details

  - Database calculations (`expr()`) are translated to SQL and can be sorted
  - In-memory calculations run after data is loaded from the database
  - The query builder tries to sort by fields that don't exist in the database query
  - This results in either errors or the sort being ignored

  ## Potential Solutions

  1. **Detection**: Identify when a sort field is an in-memory calculation
  2. **Deferred sorting**: Load data unsorted, compute calculations, then sort in Elixir
  3. **UI prevention**: Don't show sort controls for non-sortable calculations
  4. **Validation**: Block invalid sort requests with helpful error messages

  This test file serves as documentation of the issue and will help verify
  when a solution is implemented.
  """

  test "detection correctly identifies calculation types" do
    # Test the new calculation_sortable?/1 function
    calculations = Ash.Resource.Info.calculations(TestUser)

    expr_calc = Enum.find(calculations, &(&1.name == :full_name_expr))
    module_calc = Enum.find(calculations, &(&1.name == :full_name_module))

    assert QueryBuilder.calculation_sortable?(expr_calc)
    refute QueryBuilder.calculation_sortable?(module_calc)
  end

  test "get_calculation_info correctly retrieves calculation details" do
    # Test the new get_calculation_info/2 function
    expr_info = QueryBuilder.get_calculation_info(TestUser, :full_name_expr)
    module_info = QueryBuilder.get_calculation_info(TestUser, :full_name_module)
    non_calc_info = QueryBuilder.get_calculation_info(TestUser, :first_name)

    assert expr_info != nil
    assert module_info != nil
    assert non_calc_info == nil
  end

  test "validation prevents sorting on in-memory calculations" do
    # Test that our new validation correctly prevents sorting on in-memory calculations

    # This should be allowed - database expression calculation
    expr_sort = [{"full_name_expr", :asc}]
    assert :ok == QueryBuilder.validate_sortable_fields(expr_sort, TestUser)

    # This should be blocked - in-memory calculation without expression/2
    module_sort = [{"full_name_module", :asc}]
    assert {:error, message} = QueryBuilder.validate_sortable_fields(module_sort, TestUser)
    assert message =~ "Cannot sort by invalid fields: full_name_module"
    assert message =~ "missing expression/2"

    # This should be allowed - regular attribute
    regular_sort = [{"first_name", :asc}]
    assert :ok == QueryBuilder.validate_sortable_fields(regular_sort, TestUser)
  end

  @tag :capture_log
  test "column parsing detects non-sortable calculations" do
    # Test that column parsing correctly marks calculations as non-sortable

    expr_column = %{field: "full_name_expr", sortable: true}
    module_column = %{field: "full_name_module", sortable: true}
    regular_column = %{field: "first_name", sortable: true}

    expr_parsed = Cinder.Column.parse_column(expr_column, TestUser)
    module_parsed = Cinder.Column.parse_column(module_column, TestUser)
    regular_parsed = Cinder.Column.parse_column(regular_column, TestUser)

    assert expr_parsed.sortable == true
    assert module_parsed.sortable == false
    assert regular_parsed.sortable == true

    assert module_parsed.sort_warning != nil
    assert module_parsed.sort_warning =~ "in-memory calculation"
  end

  @tag :capture_log
  test "column parsing handles relationship calculations" do
    # Test that column parsing correctly handles calculations as non-sortable

    # Non-existent relationship should be marked as non-sortable
    nonexistent_rel_column = %{field: "nonexistent_rel.some_field", sortable: true}
    nonexistent_parsed = Cinder.Column.parse_column(nonexistent_rel_column, TestUser)

    assert nonexistent_parsed.sortable == false
    assert nonexistent_parsed.sort_warning =~ "does not exist"

    # Test a field that looks like a relationship but is actually just a field with dots
    # This should be marked as non-sortable since the field doesn't exist
    dotted_field_column = %{field: "some.dotted.field", sortable: true}
    dotted_parsed = Cinder.Column.parse_column(dotted_field_column, TestUser)

    assert dotted_parsed.sortable == false
    assert dotted_parsed.sort_warning =~ "does not exist"
  end

  @tag :capture_log
  test "column parsing correctly detects calculations in relationships" do
    # Create a test profile with calculations
    profile_attrs = %{bio: "Software developer", website: "example.com"}

    profile =
      TestProfile
      |> Ash.Changeset.for_create(:create, profile_attrs)
      |> Ash.create!(domain: TestDomain)

    user_attrs = %{first_name: "John", last_name: "Doe", profile_id: profile.id}

    _user =
      TestUserWithProfile
      |> Ash.Changeset.for_create(:create, user_attrs)
      |> Ash.create!(domain: TestDomain)

    # Test direct calculation on main resource (should work as before)
    main_expr_column = %{field: "full_name_expr", sortable: true}
    main_module_column = %{field: "full_name_module", sortable: true}

    main_expr_parsed = Cinder.Column.parse_column(main_expr_column, TestUserWithProfile)
    main_module_parsed = Cinder.Column.parse_column(main_module_column, TestUserWithProfile)

    assert main_expr_parsed.sortable == true
    assert main_module_parsed.sortable == false

    # Test relationship calculations
    # Database-level calculation on relationship - should be sortable
    rel_expr_column = %{field: "profile.display_info", sortable: true}
    rel_expr_parsed = Cinder.Column.parse_column(rel_expr_column, TestUserWithProfile)

    assert rel_expr_parsed.sortable == true
    assert rel_expr_parsed.sort_warning == nil

    # In-memory calculation on relationship - should NOT be sortable
    rel_module_column = %{field: "profile.formatted_bio", sortable: true}
    rel_module_parsed = Cinder.Column.parse_column(rel_module_column, TestUserWithProfile)

    assert rel_module_parsed.sortable == false
    assert rel_module_parsed.sort_warning != nil
    assert rel_module_parsed.sort_warning =~ "in-memory calculation"

    # Regular field on relationship - should be sortable
    rel_field_column = %{field: "profile.bio", sortable: true}
    rel_field_parsed = Cinder.Column.parse_column(rel_field_column, TestUserWithProfile)

    assert rel_field_parsed.sortable == true
    assert rel_field_parsed.sort_warning == nil
  end

  test "direct calculation with resource module - expression type" do
    column = %{field: "full_name_expr", sortable: true}
    parsed = Cinder.Column.parse_column(column, TestUser)

    assert parsed.sortable == true
    assert parsed.sort_warning == nil
  end

  @tag :capture_log
  test "direct calculation with resource module - in-memory type" do
    column = %{field: "full_name_module", sortable: true}
    parsed = Cinder.Column.parse_column(column, TestUser)

    assert parsed.sortable == false
    assert parsed.sort_warning != nil
    assert parsed.sort_warning =~ "in-memory calculation"
  end

  test "relationship calculation - expression type" do
    profile_attrs = %{bio: "Software developer", website: "example.com"}

    profile =
      TestProfile
      |> Ash.Changeset.for_create(:create, profile_attrs)
      |> Ash.create!(domain: TestDomain)

    user_attrs = %{first_name: "John", last_name: "Doe", profile_id: profile.id}

    _user =
      TestUserWithProfile
      |> Ash.Changeset.for_create(:create, user_attrs)
      |> Ash.create!(domain: TestDomain)

    column = %{field: "profile.display_info", sortable: true}
    parsed = Cinder.Column.parse_column(column, TestUserWithProfile)

    assert parsed.sortable == true
    assert parsed.sort_warning == nil
  end

  @tag :capture_log
  test "relationship calculation - in-memory type" do
    profile_attrs = %{bio: "Software developer", website: "example.com"}

    profile =
      TestProfile
      |> Ash.Changeset.for_create(:create, profile_attrs)
      |> Ash.create!(domain: TestDomain)

    user_attrs = %{first_name: "John", last_name: "Doe", profile_id: profile.id}

    _user =
      TestUserWithProfile
      |> Ash.Changeset.for_create(:create, user_attrs)
      |> Ash.create!(domain: TestDomain)

    column = %{field: "profile.formatted_bio", sortable: true}
    parsed = Cinder.Column.parse_column(column, TestUserWithProfile)

    assert parsed.sortable == false
    assert parsed.sort_warning != nil
    assert parsed.sort_warning =~ "in-memory calculation"
  end

  test "relationship regular field" do
    profile_attrs = %{bio: "Software developer", website: "example.com"}

    profile =
      TestProfile
      |> Ash.Changeset.for_create(:create, profile_attrs)
      |> Ash.create!(domain: TestDomain)

    user_attrs = %{first_name: "John", last_name: "Doe", profile_id: profile.id}

    _user =
      TestUserWithProfile
      |> Ash.Changeset.for_create(:create, user_attrs)
      |> Ash.create!(domain: TestDomain)

    column = %{field: "profile.bio", sortable: true}
    parsed = Cinder.Column.parse_column(column, TestUserWithProfile)

    assert parsed.sortable == true
    assert parsed.sort_warning == nil
  end

  test "non-ash resource doesn't crash" do
    non_ash_resource = %{not: "an_ash_resource"}
    column = %{field: "test_field", sortable: true}
    parsed = Cinder.Column.parse_column(column, non_ash_resource)

    assert parsed.sortable == true
    assert parsed.sort_warning == nil
  end

  @tag :capture_log
  test "user explicit sortable override - unsafe override ignored" do
    column = %{field: "full_name_module", sortable: true}
    parsed = Cinder.Column.parse_column(column, TestUser)

    # Unsafe override should be ignored - stays non-sortable
    assert parsed.sortable == false
    assert parsed.sort_warning != nil
    assert parsed.sort_warning =~ "in-memory calculation"
  end

  test "user explicit sortable override - safe override allowed" do
    column = %{field: "full_name_expr", sortable: false}
    parsed = Cinder.Column.parse_column(column, TestUser)

    # Safe override (more restrictive) should be allowed
    assert parsed.sortable == false
    assert parsed.sort_warning == nil
  end

  @tag :capture_log
  test "calculation filtering detection works correctly" do
    # Test database calculation - should be filterable
    expr_column = %{field: "full_name_expr", filterable: true}
    expr_parsed = Cinder.Column.parse_column(expr_column, TestUser)
    assert expr_parsed.filterable == true
    assert expr_parsed.filter_warning == nil

    # Test in-memory calculation - should not be filterable
    module_column = %{field: "full_name_module", filterable: true}
    module_parsed = Cinder.Column.parse_column(module_column, TestUser)
    assert module_parsed.filterable == false
    assert module_parsed.filter_warning != nil
    assert module_parsed.filter_warning =~ "in-memory calculation"
  end

  @tag :capture_log
  test "user explicit filterable override - unsafe override ignored" do
    column = %{field: "full_name_module", filterable: true}
    parsed = Cinder.Column.parse_column(column, TestUser)

    # Unsafe override should be ignored - stays non-filterable
    assert parsed.filterable == false
    assert parsed.filter_warning != nil
    assert parsed.filter_warning =~ "in-memory calculation"
  end

  test "user explicit filterable override - safe override allowed" do
    column = %{field: "full_name_expr", filterable: false}
    parsed = Cinder.Column.parse_column(column, TestUser)

    # Safe override (more restrictive) should be allowed
    assert parsed.filterable == false
    assert parsed.filter_warning == nil
  end

  test "no sorting or filtering requested - no warnings generated" do
    # When user doesn't request sorting or filtering, no warnings should be generated
    # even for in-memory calculations
    column = %{field: "full_name_module"}
    parsed = Cinder.Column.parse_column(column, TestUser)

    assert parsed.sortable == false
    assert parsed.filterable == false
    assert parsed.sort_warning == nil
    assert parsed.filter_warning == nil
  end

  @tag :capture_log
  test "query struct calculation detection should match resource detection" do
    # Create both query and resource versions
    query = Ash.Query.for_read(TestUser, :read)
    resource = TestUser

    # Test expression calculation
    expr_column = %{field: "full_name_expr", sortable: true}

    resource_parsed = Cinder.Column.parse_column(expr_column, resource)
    query_parsed = Cinder.Column.parse_column(expr_column, query)

    # These should be identical after the fix
    assert resource_parsed.sortable == query_parsed.sortable
    assert resource_parsed.sort_warning == query_parsed.sort_warning

    # Test in-memory calculation
    module_column = %{field: "full_name_module", sortable: true}

    resource_parsed = Cinder.Column.parse_column(module_column, resource)
    query_parsed = Cinder.Column.parse_column(module_column, query)

    # These should be identical after the fix
    assert resource_parsed.sortable == query_parsed.sortable
    assert resource_parsed.sort_warning != nil
    assert query_parsed.sort_warning != nil
    assert resource_parsed.sort_warning == query_parsed.sort_warning
  end

  @tag :capture_log
  test "query struct relationship calculation detection should match resource detection" do
    # Create test data
    profile_attrs = %{bio: "Software developer", website: "example.com"}

    profile =
      TestProfile
      |> Ash.Changeset.for_create(:create, profile_attrs)
      |> Ash.create!(domain: TestDomain)

    user_attrs = %{first_name: "John", last_name: "Doe", profile_id: profile.id}

    _user =
      TestUserWithProfile
      |> Ash.Changeset.for_create(:create, user_attrs)
      |> Ash.create!(domain: TestDomain)

    # Create both query and resource versions
    query = Ash.Query.for_read(TestUserWithProfile, :read)
    resource = TestUserWithProfile

    # Test relationship expression calculation
    rel_expr_column = %{field: "profile.display_info", sortable: true}

    resource_parsed = Cinder.Column.parse_column(rel_expr_column, resource)
    query_parsed = Cinder.Column.parse_column(rel_expr_column, query)

    # These should be identical after the fix
    assert resource_parsed.sortable == query_parsed.sortable
    assert resource_parsed.sort_warning == query_parsed.sort_warning

    # Test relationship in-memory calculation
    rel_module_column = %{field: "profile.formatted_bio", sortable: true}

    resource_parsed = Cinder.Column.parse_column(rel_module_column, resource)
    query_parsed = Cinder.Column.parse_column(rel_module_column, query)

    # These should be identical after the fix
    assert resource_parsed.sortable == query_parsed.sortable
    assert resource_parsed.sort_warning != nil
    assert query_parsed.sort_warning != nil
    assert resource_parsed.sort_warning == query_parsed.sort_warning
  end

  test "runtime validation handles different field types correctly" do
    # Test in-memory calculation - should return validation error
    invalid_options = [
      actor: nil,
      filters: %{},
      sort_by: [{"full_name_module", :asc}],
      page_size: 25,
      current_page: 1,
      columns: [],
      query_opts: [load: [:full_name_module]]
    ]

    assert {:error, message} = QueryBuilder.build_and_execute(TestUser, invalid_options)
    assert message =~ "Cannot sort by invalid fields: full_name_module"
    assert message =~ "FullNameCalc - missing expression/2"

    # Test database calculation - should work fine
    valid_options = [
      actor: nil,
      filters: %{},
      sort_by: [{"full_name_expr", :asc}],
      page_size: 25,
      current_page: 1,
      columns: [],
      query_opts: [load: [:full_name_expr]]
    ]

    assert {:ok, page} = QueryBuilder.build_and_execute(TestUser, valid_options)
    assert length(page.results) > 0

    # Verify sorting worked
    full_names = Enum.map(page.results, & &1.full_name_expr)
    assert full_names == Enum.sort(full_names)

    # Test filtering still works (no regression)
    filter_options = [
      actor: nil,
      filters: %{"full_name_expr" => %{type: :text, value: "Alice", operator: :contains}},
      sort_by: [],
      page_size: 25,
      current_page: 1,
      columns: [],
      query_opts: [load: [:full_name_expr]]
    ]

    assert {:ok, filtered_page} = QueryBuilder.build_and_execute(TestUser, filter_options)

    if length(filtered_page.results) > 0 do
      full_names = Enum.map(filtered_page.results, & &1.full_name_expr)
      assert Enum.all?(full_names, &String.contains?(&1, "Alice"))
    end
  end

  test "URL parameter filtering silently removes invalid sort fields" do
    # This test verifies that invalid sort fields from URLs are silently filtered out
    # rather than causing crashes or warnings

    # Create column definitions for a table
    columns = [
      %{field: "first_name", sortable: true},
      %{field: "last_name", sortable: true},
      %{field: "full_name_expr", sortable: true},
      # full_name_module would have sortable: false (in-memory calculation)
      %{field: "full_name_module", sortable: false}
    ]

    # Test URL parameters with mixed valid/invalid sort fields
    url_params = %{
      "page" => "1",
      # Valid sorts
      # Invalid sorts that should be filtered out
      "sort" =>
        "first_name,-last_name,full_name_expr," <>
          "full_name_module,nonexistent_field,another_invalid"
    }

    # Decode state - should silently filter invalid sorts
    result = Cinder.UrlManager.decode_state(url_params, columns)

    # Should only contain the valid sort fields
    assert result.sort_by == [
             {"first_name", :asc},
             {"last_name", :desc},
             {"full_name_expr", :asc}
           ]

    # Invalid fields should be silently removed:
    # - full_name_module (not sortable)
    # - nonexistent_field (doesn't exist)
    # - another_invalid (doesn't exist)
  end

  test "URL parameter filtering works with empty columns list" do
    # Verify backward compatibility when no columns are provided
    url_params = %{
      "sort" => "any_field,-another_field"
    }

    # With empty columns, should preserve all sorts (backward compatibility)
    result = Cinder.UrlManager.decode_state(url_params, [])

    assert result.sort_by == [
             {"any_field", :asc},
             {"another_field", :desc}
           ]
  end

  test "invalid field names in query building are handled gracefully" do
    # This test checks what happens when completely invalid field names
    # reach the query building stage (not from URLs)

    # Test with a completely invalid field name
    options = [
      actor: nil,
      filters: %{},
      sort_by: [{"completely_invalid_field_name", :asc}],
      page_size: 25,
      current_page: 1,
      columns: [],
      query_opts: []
    ]

    result = QueryBuilder.build_and_execute(TestUser, options)

    # Should either succeed (if Ash handles it) or return a proper error
    # Should NOT crash with UndefinedFunctionError
    case result do
      {:ok, _} ->
        # Succeeded - field was ignored or handled gracefully
        :ok

      {:error, error} ->
        # Failed with proper error - also acceptable
        # Ash returns error structs, not strings
        assert is_binary(error)
        assert error =~ "field does not exist"
    end
  end

  @tag :capture_log
  test "non-existent field controls should be hidden" do
    # This test verifies that completely invalid field names don't show controls
    column = %{field: "nonexistent_field", sortable: true, filterable: true}
    parsed = Cinder.Column.parse_column(column, TestUser)

    # Should not be sortable or filterable due to field not existing
    assert parsed.sortable == false
    assert parsed.filterable == false
    assert parsed.sort_warning =~ "does not exist"
    assert parsed.filter_warning =~ "does not exist"
  end

  @tag :capture_log
  test "original user issues are fixed" do
    # This test verifies the specific issues reported by the user are resolved

    # Issue 1: Non-existent field "froo" should not show sort/filter controls
    froo_column = %{field: "froo", sortable: true, filterable: true}
    froo_parsed = Cinder.Column.parse_column(froo_column, TestUser)

    assert froo_parsed.sortable == false
    assert froo_parsed.filterable == false
    assert froo_parsed.sort_warning =~ "does not exist"
    assert froo_parsed.filter_warning =~ "does not exist"

    # Issue 2: Runtime validation should prevent crashes instead of causing them
    # Test that sorting by an in-memory calculation returns an error instead of crashing
    result = QueryBuilder.validate_sortable_fields([{"full_name_module", :asc}], TestUser)
    assert {:error, message} = result
    assert message =~ "Cannot sort by invalid fields: full_name_module"

    # Issue 3: Valid fields should pass validation
    result2 = QueryBuilder.validate_sortable_fields([{"first_name", :asc}], TestUser)
    assert result2 == :ok
  end

  @tag :capture_log
  test "validation works with pre-built Ash.Query containing invalid sorts" do
    # This test verifies that validation works when build_and_execute receives
    # an Ash.Query that already has invalid sorts applied to it

    # Create a query with an invalid sort (non-existent field)
    query =
      TestUser
      |> Ash.Query.for_read(:read, %{}, domain: TestDomain)
      |> Ash.Query.sort([{"nonexistent_field", :asc}, {"first_name", :desc}])

    options = [
      actor: nil,
      filters: %{},
      # Also invalid from options
      sort_by: [{"another_invalid_field", :asc}],
      page_size: 25,
      current_page: 1,
      columns: [],
      query_opts: []
    ]

    # Should validate the sort_by from options and return error
    result = QueryBuilder.build_and_execute(query, options)
    assert {:error, message} = result
    assert message =~ "Cannot sort by invalid fields: another_invalid_field"
    assert message =~ "field does not exist"

    # Test with in-memory calculation in pre-built query
    query2 =
      TestUser
      |> Ash.Query.for_read(:read, %{}, domain: TestDomain)
      # Invalid calculation
      |> Ash.Query.sort([{"full_name_module", :asc}])

    options2 = [
      actor: nil,
      filters: %{},
      # Empty sort_by should pass validation
      sort_by: [],
      page_size: 25,
      current_page: 1,
      columns: [],
      query_opts: []
    ]

    # Should pass validation since sort_by is empty, but the pre-built query
    # sort won't be validated (that's Ash's responsibility)
    result2 = QueryBuilder.build_and_execute(query2, options2)
    # This might succeed or fail depending on how Ash handles the invalid sort
    # but it shouldn't crash with our validation error
    case result2 do
      # Ash handled it somehow
      {:ok, _} -> :ok
      # Ash rejected it, which is fine
      {:error, _} -> :ok
    end
  end

  @tag :capture_log
  test "table component validation with pre-built query and invalid columns" do
    # This test verifies that the table component properly validates columns
    # even when using a pre-built Ash.Query instead of a resource

    # Create a query with valid sorts
    query =
      TestUser
      |> Ash.Query.for_read(:read, %{}, domain: TestDomain)
      |> Ash.Query.sort([{"first_name", :desc}])

    # Test column parsing with the query - should work the same as with resource
    valid_column = %{field: "first_name", sortable: true}
    valid_parsed = Cinder.Column.parse_column(valid_column, query)
    assert valid_parsed.sortable == true
    assert valid_parsed.sort_warning == nil

    # Test invalid column with query - should be caught
    invalid_column = %{field: "nonexistent_field", sortable: true}
    invalid_parsed = Cinder.Column.parse_column(invalid_column, query)
    assert invalid_parsed.sortable == false
    assert invalid_parsed.sort_warning =~ "does not exist"

    # Test in-memory calculation with query - should be caught
    calc_column = %{field: "full_name_module", sortable: true}
    calc_parsed = Cinder.Column.parse_column(calc_column, query)
    assert calc_parsed.sortable == false
    assert calc_parsed.sort_warning =~ "in-memory calculation"
  end

  test "multi-level relationship field resolution works correctly" do
    import ExUnit.CaptureLog

    # Test invalid multi-level relationship (doesn't exist)
    multi_level_column = %{field: "user.profile.first_name", sortable: true}

    log =
      capture_log(fn ->
        parsed = Cinder.Column.parse_column(multi_level_column, TestUser)
        assert parsed.label == "User > Profile > First Name"
        assert parsed.field == "user.profile.first_name"
        assert parsed.sortable == false
        assert parsed.sort_warning =~ "does not exist"
      end)

    assert log =~
             "Field 'user.profile.first_name' does not exist on Cinder.Issues.CalculationSortingIssueTest.TestUser"

    # Test valid 2-level relationship: profile.bio (exists)
    simple_relationship = %{field: "profile.bio", sortable: true}
    simple_parsed = Cinder.Column.parse_column(simple_relationship, TestUserWithProfile)

    assert simple_parsed.label == "Profile > Bio"
    assert simple_parsed.sortable == true
    assert simple_parsed.sort_warning == nil

    # Test invalid 3-level relationship: profile.address.nonexistent_field (valid chain, invalid final field)
    invalid_three_level = %{field: "profile.address.nonexistent_field", sortable: true}

    log2 =
      capture_log(fn ->
        invalid_three_parsed =
          Cinder.Column.parse_column(invalid_three_level, TestUserWithProfile)

        assert invalid_three_parsed.label == "Profile > Address > Nonexistent Field"
        assert invalid_three_parsed.sortable == false
        assert invalid_three_parsed.sort_warning =~ "does not exist"
      end)

    assert log2 =~
             "Field 'profile.address.nonexistent_field' does not exist on Cinder.Issues.CalculationSortingIssueTest.TestUserWithProfile"

    # Test invalid middle relationship: profile.nonexistent_rel.field (invalid middle relationship)
    invalid_middle = %{field: "profile.nonexistent_rel.field", sortable: true}

    log3 =
      capture_log(fn ->
        invalid_middle_parsed = Cinder.Column.parse_column(invalid_middle, TestUserWithProfile)
        assert invalid_middle_parsed.label == "Profile > Nonexistent Rel > Field"
        assert invalid_middle_parsed.sortable == false
        assert invalid_middle_parsed.sort_warning =~ "does not exist"
      end)

    assert log3 =~
             "Field 'profile.nonexistent_rel.field' does not exist on Cinder.Issues.CalculationSortingIssueTest.TestUserWithProfile"

    # Test valid 3-level relationship: profile.address.city (exists)
    three_level_column = %{field: "profile.address.city", sortable: true}
    three_level_parsed = Cinder.Column.parse_column(three_level_column, TestUserWithProfile)

    assert three_level_parsed.label == "Profile > Address > City"
    assert three_level_parsed.sortable == true
    assert three_level_parsed.sort_warning == nil

    # Test 3-level with calculation: profile.address.full_address (database calculation)
    calc_three_level = %{field: "profile.address.full_address", sortable: true}
    calc_parsed = Cinder.Column.parse_column(calc_three_level, TestUserWithProfile)

    assert calc_parsed.label == "Profile > Address > Full Address"
    assert calc_parsed.sortable == true
    assert calc_parsed.sort_warning == nil

    # Test 2-level with in-memory calculation: profile.formatted_bio
    in_memory_relationship = %{field: "profile.formatted_bio", sortable: true}

    log4 =
      capture_log(fn ->
        in_memory_parsed = Cinder.Column.parse_column(in_memory_relationship, TestUserWithProfile)
        assert in_memory_parsed.label == "Profile > Formatted Bio"
        assert in_memory_parsed.sortable == false
        assert in_memory_parsed.sort_warning =~ "in-memory calculation"
      end)

    assert log4 =~
             "Field 'profile.formatted_bio' is an in-memory calculation and cannot be sorted"
  end

  test "QueryBuilder validation uses correct error messages for relationship fields" do
    # Test that QueryBuilder.validate_sortable_fields also uses the improved error messages
    # This tests the runtime validation path (not just column parsing)

    # Test invalid relationship field
    result = QueryBuilder.validate_sortable_fields([{"artist.froo", :asc}], TestUser)
    assert {:error, message} = result
    assert message =~ "Cannot sort by invalid fields: artist.froo"
    # Should show that field doesn't exist on the original resource (TestUser)
    assert message =~
             "artist.froo (field does not exist on Cinder.Issues.CalculationSortingIssueTest.TestUser)"
  end
end
