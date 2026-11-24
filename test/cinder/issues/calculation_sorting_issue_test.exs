defmodule Cinder.Issues.CalculationSortingIssueTest do
  use ExUnit.Case, async: true
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

  defmodule TestDomain do
    use Ash.Domain, validate_config_inclusion?: false

    resources do
      resource(TestUser)
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
    assert message =~ "FullNameCalc is missing expression/2"

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
    assert page.results != []

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
    assert Enum.map(filtered_page.results, & &1.full_name_expr) == ["Alice Smith"]
  end

  test "a sort on a field that doesn't exist is an error, not a crash" do
    options = [
      actor: nil,
      filters: %{},
      sort_by: [{"completely_invalid_field_name", :asc}],
      page_size: 25,
      current_page: 1,
      columns: [],
      query_opts: []
    ]

    assert {:error, message} = QueryBuilder.build_and_execute(TestUser, options)
    assert message =~ "completely_invalid_field_name"
    assert message =~ "field does not exist"
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
