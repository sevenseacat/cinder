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

  describe "toggle_sort_with_cycle/3 with no-nil cycles (#132)" do
    test "[:asc, :desc] wraps without injecting nil" do
      cycle = [:asc, :desc]

      # First click: not sorted -> :asc
      sort1 = QueryBuilder.toggle_sort_with_cycle([], "name", cycle)
      assert sort1 == [{"name", :asc}]

      # Second click: :asc -> :desc
      sort2 = QueryBuilder.toggle_sort_with_cycle(sort1, "name", cycle)
      assert sort2 == [{"name", :desc}]

      # Third click: :desc -> :asc (wrap), NOT nil
      sort3 = QueryBuilder.toggle_sort_with_cycle(sort2, "name", cycle)
      assert sort3 == [{"name", :asc}]

      # Fourth click: :asc -> :desc (continues wrapping)
      sort4 = QueryBuilder.toggle_sort_with_cycle(sort3, "name", cycle)
      assert sort4 == [{"name", :desc}]
    end

    test "[:desc, :asc] wraps without injecting nil" do
      cycle = [:desc, :asc]

      sort1 = QueryBuilder.toggle_sort_with_cycle([], "created_at", cycle)
      assert sort1 == [{"created_at", :desc}]

      sort2 = QueryBuilder.toggle_sort_with_cycle(sort1, "created_at", cycle)
      assert sort2 == [{"created_at", :asc}]

      # Wraps back to :desc
      sort3 = QueryBuilder.toggle_sort_with_cycle(sort2, "created_at", cycle)
      assert sort3 == [{"created_at", :desc}]
    end

    test "[:asc, :desc, nil] still supports explicit nil at end" do
      cycle = [:asc, :desc, nil]

      sort1 = QueryBuilder.toggle_sort_with_cycle([], "name", cycle)
      assert sort1 == [{"name", :asc}]

      sort2 = QueryBuilder.toggle_sort_with_cycle(sort1, "name", cycle)
      assert sort2 == [{"name", :desc}]

      # nil is explicit in cycle, so sort is removed
      sort3 = QueryBuilder.toggle_sort_with_cycle(sort2, "name", cycle)
      assert sort3 == []

      # Re-entering the cycle starts at first non-nil
      sort4 = QueryBuilder.toggle_sort_with_cycle(sort3, "name", cycle)
      assert sort4 == [{"name", :asc}]
    end

    test "[:desc_nils_last, :asc_nils_first] wraps without nil" do
      cycle = [:desc_nils_last, :asc_nils_first]

      sort1 = QueryBuilder.toggle_sort_with_cycle([], "date", cycle)
      assert sort1 == [{"date", :desc_nils_last}]

      sort2 = QueryBuilder.toggle_sort_with_cycle(sort1, "date", cycle)
      assert sort2 == [{"date", :asc_nils_first}]

      sort3 = QueryBuilder.toggle_sort_with_cycle(sort2, "date", cycle)
      assert sort3 == [{"date", :desc_nils_last}]
    end

    test "no-nil cycle with query-extracted sort wraps correctly" do
      # Simulates: query has sort(name: :asc), column has cycle: [:asc, :desc]
      # The query extraction sets initial state to [{"name", :asc}]
      cycle = [:asc, :desc]
      initial_sort = [{"name", :asc}]

      # First user click: asc -> desc
      sort1 = QueryBuilder.toggle_sort_with_cycle(initial_sort, "name", cycle)
      assert sort1 == [{"name", :desc}]

      # Second user click: desc -> asc (wrap), NOT nil
      sort2 = QueryBuilder.toggle_sort_with_cycle(sort1, "name", cycle)
      assert sort2 == [{"name", :asc}]
    end

    test "no-nil cycle preserves other sorts during wrap" do
      cycle = [:asc, :desc]
      current_sort = [{"name", :desc}, {"other", :asc}]

      # Wraps back to :asc, preserves other
      result = QueryBuilder.toggle_sort_with_cycle(current_sort, "name", cycle)
      assert result == [{"name", :asc}, {"other", :asc}]
    end
  end

  describe "toggle_sort_with_cycle/4 with sort_mode" do
    test "additive mode (default) preserves existing sorts when adding new column" do
      current_sort = [{"other_field", :desc}]

      # Explicit :additive mode should behave same as 3-arity version
      result = QueryBuilder.toggle_sort_with_cycle(current_sort, "name", nil, :additive)

      assert result == [{"name", :asc}, {"other_field", :desc}]
    end

    test "exclusive mode replaces existing sorts when adding new column" do
      current_sort = [{"other_field", :desc}, {"another_field", :asc}]

      result = QueryBuilder.toggle_sort_with_cycle(current_sort, "name", nil, :exclusive)

      # Only the new sort should remain
      assert result == [{"name", :asc}]
    end

    test "exclusive mode cycles through directions for same column" do
      # First click on column
      sort1 = QueryBuilder.toggle_sort_with_cycle([], "name", nil, :exclusive)
      assert sort1 == [{"name", :asc}]

      # Second click cycles to desc
      sort2 = QueryBuilder.toggle_sort_with_cycle(sort1, "name", nil, :exclusive)
      assert sort2 == [{"name", :desc}]

      # Third click removes sort
      sort3 = QueryBuilder.toggle_sort_with_cycle(sort2, "name", nil, :exclusive)
      assert sort3 == []
    end

    test "exclusive mode with custom cycle" do
      cycle = [nil, :desc_nils_last, :asc_nils_first]
      current_sort = [{"other_field", :desc}]

      # Click new column - should replace existing sort
      result = QueryBuilder.toggle_sort_with_cycle(current_sort, "created_at", cycle, :exclusive)

      assert result == [{"created_at", :desc_nils_last}]
    end

    test "exclusive mode clears all sorts when cycling to nil" do
      # Set up with multiple sorts (shouldn't happen in exclusive mode, but test edge case)
      current_sort = [{"name", :desc}, {"other", :asc}]

      # Cycling name to nil should clear everything in exclusive mode
      result = QueryBuilder.toggle_sort_with_cycle(current_sort, "name", nil, :exclusive)

      assert result == []
    end

    test "additive mode preserves behavior when cycling existing column" do
      current_sort = [{"name", :asc}, {"other", :desc}]

      # Cycling existing column should update in place
      result = QueryBuilder.toggle_sort_with_cycle(current_sort, "name", nil, :additive)

      assert result == [{"name", :desc}, {"other", :desc}]
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

  describe "default_sorts_from_cycles/2" do
    test "nil-less cycle applies first value as default sort" do
      columns = [
        %{field: "name", sort_cycle: [:asc, :desc], sortable: true}
      ]

      result = QueryBuilder.default_sorts_from_cycles(columns, [])
      assert result == [{"name", :asc}]
    end

    test "cycle containing nil does not apply default sort" do
      columns = [
        %{field: "name", sort_cycle: [nil, :asc, :desc], sortable: true}
      ]

      result = QueryBuilder.default_sorts_from_cycles(columns, [])
      assert result == []
    end

    test "does not override existing query sort" do
      columns = [
        %{field: "name", sort_cycle: [:asc, :desc], sortable: true}
      ]

      query_sorts = [{"name", :desc}]
      result = QueryBuilder.default_sorts_from_cycles(columns, query_sorts)
      assert result == [{"name", :desc}]
    end

    test "adds defaults only for unsorted nil-less columns" do
      columns = [
        %{field: "name", sort_cycle: [:asc, :desc], sortable: true},
        %{field: "age", sort_cycle: [:desc, :asc], sortable: true}
      ]

      query_sorts = [{"name", :asc}]
      result = QueryBuilder.default_sorts_from_cycles(columns, query_sorts)
      assert result == [{"name", :asc}, {"age", :desc}]
    end

    test "multiple nil-less columns all get defaults in declaration order" do
      columns = [
        %{field: "name", sort_cycle: [:asc, :desc], sortable: true},
        %{field: "created_at", sort_cycle: [:desc_nils_last, :asc_nils_first], sortable: true}
      ]

      result = QueryBuilder.default_sorts_from_cycles(columns, [])
      assert result == [{"name", :asc}, {"created_at", :desc_nils_last}]
    end

    test "mix of nil-less and default cycles" do
      columns = [
        %{field: "name", sort_cycle: [nil, :asc, :desc], sortable: true},
        %{field: "priority", sort_cycle: [:asc, :desc], sortable: true},
        %{field: "created_at", sort_cycle: [nil, :desc, :asc], sortable: true}
      ]

      result = QueryBuilder.default_sorts_from_cycles(columns, [])
      assert result == [{"priority", :asc}]
    end

    test "non-sortable columns are ignored" do
      columns = [
        %{field: "name", sort_cycle: [:asc, :desc], sortable: false}
      ]

      result = QueryBuilder.default_sorts_from_cycles(columns, [])
      assert result == []
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
