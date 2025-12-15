defmodule Cinder.Collection.CustomFilterFnNonexistentFieldTest do
  use ExUnit.Case

  alias Cinder.Collection

  describe "custom filter_fn with non-existent field" do
    test "allows filtering when filter_fn is provided even if field doesn't exist on resource" do
      custom_filter_fn = fn query, %{value: value} ->
        Map.put(query, :custom_filter_applied, value)
      end

      col_slots = [
        %{
          field: "nonexistent.virtual_field",
          label: "Virtual Filter",
          sort: false,
          filter: [type: :text, fn: custom_filter_fn],
          inner_block: fn -> "Virtual Filter" end
        }
      ]

      processed = Collection.process_columns(col_slots, TestResourceForVirtualField)
      column = List.first(processed)

      # The column should be filterable because it has a custom filter_fn
      assert column.filterable == true
      assert column.filter_type == :text
      assert is_function(column.filter_fn, 2)
    end

    test "filter_fn is called by QueryBuilder even for non-existent fields" do
      mock_query = %{resource: TestResourceForVirtualField, filters: []}

      custom_filter_fn = fn query, filter_config ->
        Map.update(query, :filters, [filter_config], &[filter_config | &1])
      end

      col_slots = [
        %{
          field: "virtual.filter_field",
          label: "Virtual",
          sort: false,
          filter: [type: :text, fn: custom_filter_fn],
          inner_block: fn -> "Virtual" end
        }
      ]

      processed_columns = Collection.process_columns(col_slots, TestResourceForVirtualField)

      columns =
        Enum.map(processed_columns, fn col ->
          %{field: col.field, filter_fn: col.filter_fn}
        end)

      filters = %{"virtual.filter_field" => %{type: :text, value: "test_value", operator: :eq}}
      result = Cinder.QueryBuilder.apply_filters(mock_query, filters, columns)

      # Verify the custom filter function was called
      assert length(result.filters) == 1
      [applied_filter] = result.filters
      assert applied_filter.value == "test_value"
    end

    test "non-existent field without filter_fn remains non-filterable" do
      # Without a custom filter_fn, non-existent fields should not be filterable
      col_slots = [
        %{
          field: "nonexistent.field",
          label: "Non-existent",
          sort: false,
          filter: [type: :text],
          inner_block: fn -> "Non-existent" end
        }
      ]

      processed = Collection.process_columns(col_slots, TestResourceForVirtualField)
      column = List.first(processed)

      # Should NOT be filterable because field doesn't exist and no custom filter_fn
      assert column.filterable == false
      assert column.filter_fn == nil
    end

    test "relationship field with calculation and custom filter_fn is filterable" do
      custom_filter_fn = fn query, %{value: npc_id} ->
        Map.put(query, :npc_filter, npc_id)
      end

      col_slots = [
        %{
          field: "responses.valid_for_npc?",
          label: "NPC",
          sort: false,
          filter: [type: :text, fn: custom_filter_fn],
          inner_block: fn -> "NPC" end
        }
      ]

      processed = Collection.process_columns(col_slots, TestResourceForVirtualField)
      column = List.first(processed)

      assert column.field == "responses.valid_for_npc?"
      assert column.label == "NPC"
      assert column.filterable == true
      assert column.filter_type == :text
      assert is_function(column.filter_fn, 2)
    end
  end
end

# Test resource that intentionally doesn't have the fields we're testing
defmodule TestResourceForVirtualField do
  use Ash.Resource, domain: nil

  resource do
    require_primary_key?(false)
  end

  attributes do
    attribute(:id, :string)
    attribute(:name, :string)
  end

  actions do
    defaults([:read])
  end
end
