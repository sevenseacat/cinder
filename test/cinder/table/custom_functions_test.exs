defmodule Cinder.Table.CustomFunctionsTest do
  use ExUnit.Case

  alias Cinder.Table

  # Mock functions for testing
  defp custom_filter_function(query, filter_config) do
    %{query | custom_filter: {filter_config, :applied}}
  end

  describe "custom function extraction" do
    test "extracts filter_fn from unified configuration" do
      col_slots = [
        %{
          field: "status",
          sort: false,
          filter: [type: :select, options: ["active", "inactive"], fn: &custom_filter_function/2],
          inner_block: fn -> "Status" end
        }
      ]

      processed = Table.process_columns(col_slots, TestResource)
      column = List.first(processed)

      assert column.sortable == false
      assert column.filterable == true
      assert column.filter_type == :select
      assert is_function(column.filter_fn, 2)
    end

    test "handles standard configurations without custom functions" do
      col_slots = [
        %{
          field: "name",
          sort: true,
          filter: :text,
          inner_block: fn -> "Name" end
        }
      ]

      processed = Table.process_columns(col_slots, TestResource)
      column = List.first(processed)

      assert column.sortable == true
      assert column.filterable == true
      assert column.filter_fn == nil
    end

    test "handles disabled sort and filter" do
      col_slots = [
        %{
          field: "description",
          sort: false,
          filter: false,
          inner_block: fn -> "Description" end
        }
      ]

      processed = Table.process_columns(col_slots, TestResource)
      column = List.first(processed)

      assert column.sortable == false
      assert column.filterable == false
      assert column.filter_fn == nil
    end
  end

  describe "integration with existing functionality" do
    test "custom filter functions work with existing Column struct fields" do
      col_slots = [
        %{
          field: "name",
          sort: true,
          filter: [type: :text, fn: &custom_filter_function/2],
          inner_block: fn -> "Name" end
        }
      ]

      processed = Table.process_columns(col_slots, TestResource)
      column = List.first(processed)

      # Verify the functions are preserved and could be passed to QueryBuilder
      assert column.sortable == true
      assert column.filterable == true
      assert is_function(column.filter_fn, 2)

      # Verify other column properties are still correct
      assert column.field == "name"
      assert column.filter_type == :text
    end

    test "backward compatibility with existing boolean sort syntax" do
      # Old syntax should continue to work
      col_slots = [
        %{
          field: "name",
          sort: true,
          filter: :select,
          inner_block: fn -> "Name" end
        }
      ]

      processed = Table.process_columns(col_slots, TestResource)
      column = List.first(processed)

      assert column.sortable == true
      assert column.filterable == true
      # No custom function
      assert column.filter_fn == nil
    end
  end

  describe "end-to-end integration with QueryBuilder" do
    test "custom filter functions are called by QueryBuilder" do
      # Mock query that tracks when custom filter is applied
      mock_query = %{resource: TestResource, custom_filter_applied: false}

      # Custom filter function that modifies the query to show it was called
      custom_filter_fn = fn query, filter_config ->
        Map.put(query, :custom_filter_applied, {filter_config, :called})
      end

      # Create processed column with custom filter function
      col_slots = [
        %{
          field: "status",
          sort: false,
          filter: [type: :select, fn: custom_filter_fn],
          inner_block: fn -> "Status" end
        }
      ]

      processed_columns = Table.process_columns(col_slots, TestResource)

      # Convert to QueryBuilder format
      columns =
        Enum.map(processed_columns, fn col ->
          %{field: col.field, filter_fn: col.filter_fn}
        end)

      # Apply filtering using QueryBuilder
      filters = %{"status" => %{type: :select, value: "active", operator: :eq}}
      result = Cinder.QueryBuilder.apply_filters(mock_query, filters, columns)

      # Verify our custom function was called with the correct filter config
      expected_filter_config = %{type: :select, value: "active", operator: :eq}
      assert result.custom_filter_applied == {expected_filter_config, :called}
    end
  end
end

# Mock test resource for testing
defmodule TestResource do
  use Ash.Resource, domain: TestDomain

  resource do
    require_primary_key?(false)
  end

  attributes do
    attribute(:name, :string)
    attribute(:status, :string)
    attribute(:priority, :integer)
    attribute(:created_at, :utc_datetime)
    attribute(:description, :string)
  end

  actions do
    defaults([:read])
  end
end

defmodule TestDomain do
  use Ash.Domain, validate_config_inclusion?: false

  resources do
    resource(TestResource)
  end
end
