defmodule Cinder.Table.SortCycleTest do
  use ExUnit.Case

  alias Cinder.QueryBuilder
  alias Cinder.Table

  describe "process_columns/2 with sort cycles" do
    test "includes default sort cycle in processed columns" do
      col_slots = [
        %{
          field: "name",
          sort: true,
          filter: false,
          inner_block: fn -> "Name" end
        }
      ]

      processed = Table.process_columns(col_slots, SortCycleTestResource)
      column = List.first(processed)

      assert column.sortable == true
      # Default cycle
      assert column.sort_cycle == [nil, :asc, :desc]
    end

    test "includes custom sort cycle in processed columns" do
      col_slots = [
        %{
          field: "created_at",
          sort: [cycle: [nil, :desc_nils_last, :asc_nils_first]],
          filter: false,
          inner_block: fn -> "Created At" end
        }
      ]

      processed = Table.process_columns(col_slots, SortCycleTestResource)
      column = List.first(processed)

      assert column.sortable == true
      assert column.sort_cycle == [nil, :desc_nils_last, :asc_nils_first]
    end

    test "includes custom sort cycle from configuration" do
      col_slots = [
        %{
          field: "priority",
          sort: [cycle: [nil, :high, :low]],
          filter: false,
          inner_block: fn -> "Priority" end
        }
      ]

      processed = Table.process_columns(col_slots, SortCycleTestResource)
      column = List.first(processed)

      assert column.sortable == true
      assert column.sort_cycle == [nil, :high, :low]
    end
  end

  describe "toggle_sort_with_cycle/3" do
    test "follows default cycle when no custom cycle provided" do
      # Test standard behavior: nil -> :asc -> :desc -> nil
      current_sort = []

      # First click: nil -> :asc
      sort1 = QueryBuilder.toggle_sort_with_cycle(current_sort, "name", nil)
      assert sort1 == [{"name", :asc}]

      # Second click: :asc -> :desc
      sort2 = QueryBuilder.toggle_sort_with_cycle(sort1, "name", nil)
      assert sort2 == [{"name", :desc}]

      # Third click: :desc -> nil (remove)
      sort3 = QueryBuilder.toggle_sort_with_cycle(sort2, "name", nil)
      assert sort3 == []
    end

    test "follows custom cycle" do
      custom_cycle = [nil, :desc_nils_last, :asc_nils_first]
      current_sort = []

      # First click: nil -> :desc_nils_last
      sort1 = QueryBuilder.toggle_sort_with_cycle(current_sort, "created_at", custom_cycle)
      assert sort1 == [{"created_at", :desc_nils_last}]

      # Second click: :desc_nils_last -> :asc_nils_first
      sort2 = QueryBuilder.toggle_sort_with_cycle(sort1, "created_at", custom_cycle)
      assert sort2 == [{"created_at", :asc_nils_first}]

      # Third click: :asc_nils_first -> nil (remove)
      sort3 = QueryBuilder.toggle_sort_with_cycle(sort2, "created_at", custom_cycle)
      assert sort3 == []
    end

    test "handles custom business logic cycles" do
      business_cycle = [nil, :high_priority, :low_priority]
      current_sort = []

      # First click: nil -> :high_priority
      sort1 = QueryBuilder.toggle_sort_with_cycle(current_sort, "priority", business_cycle)
      assert sort1 == [{"priority", :high_priority}]

      # Second click: :high_priority -> :low_priority
      sort2 = QueryBuilder.toggle_sort_with_cycle(sort1, "priority", business_cycle)
      assert sort2 == [{"priority", :low_priority}]

      # Third click: :low_priority -> nil (remove)
      sort3 = QueryBuilder.toggle_sort_with_cycle(sort2, "priority", business_cycle)
      assert sort3 == []
    end

    test "handles cycles that start with nil" do
      cycle_with_nil_first = [nil, :desc, :asc]
      current_sort = []

      # First click should go to first non-nil value
      sort1 = QueryBuilder.toggle_sort_with_cycle(current_sort, "name", cycle_with_nil_first)
      assert sort1 == [{"name", :desc}]
    end

    test "handles malformed cycles gracefully" do
      empty_cycle = []
      current_sort = []

      # Should fall back to standard behavior
      sort1 = QueryBuilder.toggle_sort_with_cycle(current_sort, "name", empty_cycle)
      assert sort1 == [{"name", :asc}]

      nil_only_cycle = [nil]
      # Should fall back to standard behavior
      sort2 = QueryBuilder.toggle_sort_with_cycle(current_sort, "name", nil_only_cycle)
      assert sort2 == [{"name", :asc}]
    end

    test "preserves other sorts while cycling through one column" do
      current_sort = [{"other_field", :desc}]
      cycle = [nil, :desc_nils_last, :asc_nils_first]

      # Add new sort
      sort1 = QueryBuilder.toggle_sort_with_cycle(current_sort, "created_at", cycle)
      assert sort1 == [{"created_at", :desc_nils_last}, {"other_field", :desc}]

      # Cycle the new sort
      sort2 = QueryBuilder.toggle_sort_with_cycle(sort1, "created_at", cycle)
      assert sort2 == [{"created_at", :asc_nils_first}, {"other_field", :desc}]

      # Remove the cycled sort
      sort3 = QueryBuilder.toggle_sort_with_cycle(sort2, "created_at", cycle)
      assert sort3 == [{"other_field", :desc}]
    end

    test "handles unknown current direction in cycle" do
      # If current direction isn't in the cycle, start from beginning
      current_sort = [{"name", :some_unknown_direction}]
      cycle = [nil, :desc, :asc]

      # Should advance to next position after finding current (or start over)
      result = QueryBuilder.toggle_sort_with_cycle(current_sort, "name", cycle)

      # Since :some_unknown_direction isn't in cycle, find_index returns nil, so we go to position 1
      assert result == [{"name", :desc}]
    end
  end

  describe "URL encoding/decoding with custom sort directions" do
    test "encodes and decodes Ash built-in null handling directions" do
      # Test Ash built-in directions using elegant prefix syntax
      sort_data = [{"created_at", :desc_nils_last}, {"updated_at", :asc_nils_first}]
      encoded = Cinder.UrlManager.encode_sort(sort_data)

      # Should use elegant prefix syntax
      assert encoded == "--created_at,++updated_at"

      # Should decode back to original
      decoded = Cinder.UrlManager.decode_sort(encoded)
      assert decoded == sort_data
    end

    test "encodes standard directions using clean syntax" do
      # Standard :asc and :desc should use clean format
      sort_data = [{"title", :desc}, {"created_at", :asc}]
      encoded = Cinder.UrlManager.encode_sort(sort_data)

      # Should use clean format: field for asc, -field for desc
      assert encoded == "-title,created_at"

      decoded = Cinder.UrlManager.decode_sort(encoded)
      assert decoded == sort_data
    end

    test "rejects invalid sort directions gracefully" do
      # Test that invalid directions are handled gracefully
      import ExUnit.CaptureLog

      sort_data = [{"priority", :invalid_direction}]
      {encoded, _logs} = with_log(fn -> Cinder.UrlManager.encode_sort(sort_data) end)

      assert encoded == ""
    end

    test "handles mixed prefix types in URLs with standard directions only" do
      # Mix of standard and null-handling directions
      mixed_encoded = "--payment_date,++created_at,-title,status"
      decoded = Cinder.UrlManager.decode_sort(mixed_encoded)

      expected = [
        {"payment_date", :desc_nils_last},
        {"created_at", :asc_nils_first},
        {"title", :desc},
        {"status", :asc}
      ]

      assert decoded == expected
    end

    test "encodes and decodes all 4 Ash null-handling directions" do
      # Test all 4 null-handling directions with unique URL encoding
      sort_data = [
        # ++field1
        {"field1", :asc_nils_first},
        # +-field2
        {"field2", :desc_nils_first},
        # -+field3
        {"field3", :asc_nils_last},
        # --field4
        {"field4", :desc_nils_last}
      ]

      encoded = Cinder.UrlManager.encode_sort(sort_data)
      # Each direction gets its own encoding scheme
      assert encoded == "++field1,+-field2,-+field3,--field4"

      decoded = Cinder.UrlManager.decode_sort(encoded)
      assert decoded == sort_data
    end

    test "demonstrates clean URLs with elegant prefix syntax" do
      # Show how much cleaner the URLs are with prefix syntax
      sort_data = [
        {"payment_date", :desc_nils_last},
        {"created_at", :asc_nils_first},
        {"title", :asc},
        {"priority", :desc}
      ]

      encoded = Cinder.UrlManager.encode_sort(sort_data)
      assert encoded == "--payment_date,++created_at,title,-priority"

      decoded = Cinder.UrlManager.decode_sort(encoded)
      assert decoded == sort_data
    end
  end

  describe "end-to-end sort cycle demonstration" do
    test "demonstrates custom sort cycles working through the full stack" do
      # This test shows how sort cycles work from table configuration
      # all the way through to the QueryBuilder

      # Define columns with different sort cycles
      col_slots = [
        %{
          field: "name",
          # Standard cycle
          sort: true,
          filter: false,
          inner_block: fn -> "Name" end
        },
        %{
          field: "created_at",
          # Custom cycle: most recent first when clicked
          sort: [cycle: [nil, :desc_nils_last, :asc_nils_first]],
          filter: false,
          inner_block: fn -> "Created At" end
        },
        %{
          field: "priority",
          # Business logic cycle (just the cycle, no function)
          sort: [cycle: [nil, :high, :low]],
          filter: false,
          inner_block: fn -> "Priority" end
        }
      ]

      # Process columns (what Table.table/1 does internally)
      processed_columns = Table.process_columns(col_slots, SortCycleTestResource)

      # Verify columns have correct cycle configuration
      name_col = Enum.find(processed_columns, &(&1.field == "name"))
      created_col = Enum.find(processed_columns, &(&1.field == "created_at"))
      priority_col = Enum.find(processed_columns, &(&1.field == "priority"))

      assert name_col.sort_cycle == [nil, :asc, :desc]
      assert created_col.sort_cycle == [nil, :desc_nils_last, :asc_nils_first]
      assert priority_col.sort_cycle == [nil, :high, :low]

      # Simulate clicking through sort cycles
      current_sort = []

      # Click "Created At" column - should start with :desc_nils_last
      sort1 =
        QueryBuilder.toggle_sort_with_cycle(current_sort, "created_at", created_col.sort_cycle)

      assert sort1 == [{"created_at", :desc_nils_last}]

      # Click again - should move to :asc_nils_first
      sort2 = QueryBuilder.toggle_sort_with_cycle(sort1, "created_at", created_col.sort_cycle)
      assert sort2 == [{"created_at", :asc_nils_first}]

      # Click again - should remove sort (back to nil)
      sort3 = QueryBuilder.toggle_sort_with_cycle(sort2, "created_at", created_col.sort_cycle)
      assert sort3 == []

      # Click "Priority" column - should use business logic cycle
      sort4 = QueryBuilder.toggle_sort_with_cycle(sort3, "priority", priority_col.sort_cycle)
      assert sort4 == [{"priority", :high}]

      # Click again - should move to :low
      sort5 = QueryBuilder.toggle_sort_with_cycle(sort4, "priority", priority_col.sort_cycle)
      assert sort5 == [{"priority", :low}]

      # Click "Name" column while priority is sorted - should add standard sort
      sort6 = QueryBuilder.toggle_sort_with_cycle(sort5, "name", name_col.sort_cycle)
      assert sort6 == [{"name", :asc}, {"priority", :low}]

      # This demonstrates that custom cycles work alongside standard sorting
      # and that multiple columns can be sorted with different cycle behaviors
    end
  end
end

# Mock test resource
defmodule SortCycleTestResource do
  use Ash.Resource, domain: SortCycleTestDomain

  resource do
    require_primary_key?(false)
  end

  attributes do
    attribute(:name, :string)
    attribute(:created_at, :utc_datetime)
    attribute(:priority, :integer)
  end

  actions do
    defaults([:read])
  end
end

defmodule SortCycleTestDomain do
  use Ash.Domain, validate_config_inclusion?: false

  resources do
    resource(SortCycleTestResource)
  end
end
