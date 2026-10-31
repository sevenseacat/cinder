defmodule Cinder.RangeFilterIntegrationTest do
  use ExUnit.Case, async: true

  alias Cinder.FilterManager

  describe "Range Filter Integration" do
    test "number range filter processes min/max inputs correctly" do
      # Test the exact filter_change params that user reported
      filter_params = %{
        "_unused_name" => "",
        "name" => "",
        "type" => "",
        "value_max" => "200",
        "value_min" => "100"
      }

      columns = [
        %{
          field: "value",
          label: "Value",
          sortable: false,
          searchable: false,
          filterable: true,
          filter_type: :number_range,
          filter_options: [],
          filter_fn: nil,
          options: [],
          display_field: nil,
          search_fn: nil,
          class: ""
        }
      ]

      # Test the FilterManager.params_to_filters function directly
      result = FilterManager.params_to_filters(filter_params, columns)

      # Verify the filters were processed correctly
      assert Map.has_key?(result, "value")

      value_filter = result["value"]
      assert value_filter.type == :number_range
      assert value_filter.value == %{min: "100", max: "200"}
      assert value_filter.operator == :between
    end

    test "date range filter processes from/to inputs correctly" do
      filter_params = %{
        "created_at_from" => "2024-01-01",
        "created_at_to" => "2024-12-31"
      }

      columns = [
        %{
          field: "created_at",
          label: "Created At",
          sortable: false,
          searchable: false,
          filterable: true,
          filter_type: :date_range,
          filter_options: [],
          filter_fn: nil,
          options: [],
          display_field: nil,
          search_fn: nil,
          class: ""
        }
      ]

      result = FilterManager.params_to_filters(filter_params, columns)

      assert Map.has_key?(result, "created_at")

      date_filter = result["created_at"]
      assert date_filter.type == :date_range
      assert date_filter.value == %{from: "2024-01-01", to: "2024-12-31"}
      assert date_filter.operator == :between
    end

    test "filter values are properly formatted for form display" do
      # Test that build_filter_values creates the right structure for range inputs
      filters = %{
        "value" => %{
          type: :number_range,
          value: %{min: "100", max: "200"},
          operator: :between
        },
        "created_at" => %{
          type: :date_range,
          value: %{from: "2024-01-01", to: "2024-12-31"},
          operator: :between
        }
      }

      columns = [
        %{field: "value", filterable: true, filter_type: :number_range},
        %{field: "created_at", filterable: true, filter_type: :date_range}
      ]

      result = FilterManager.build_filter_values(columns, filters)

      # Number range should create structured map for form rendering
      assert result["value"] == %{min: "100", max: "200"}

      # Date range should create structured map for form rendering
      assert result["created_at"] == %{from: "2024-01-01", to: "2024-12-31"}
    end
  end

  describe "FilterManager process_filter_params/2 step by step" do
    test "correctly combines number range inputs like user's scenario" do
      # Exact scenario from user's debug log
      filter_params = %{
        "_unused_name" => "",
        "name" => "",
        "type" => "",
        "value_max" => "200",
        "value_min" => "100"
      }

      columns = [
        %{field: "value", filterable: true, filter_type: :number_range, filter_options: []}
      ]

      # Step 1: Test process_filter_params (should combine min/max)
      processed = FilterManager.process_filter_params(filter_params, columns)

      # Should combine value_min and value_max into value
      assert processed["value"] == "100,200"
      assert processed["_unused_name"] == ""
      assert processed["name"] == ""
      assert processed["type"] == ""

      # Original _min and _max keys should be removed
      refute Map.has_key?(processed, "value_min")
      refute Map.has_key?(processed, "value_max")
    end

    test "correctly combines date range inputs" do
      filter_params = %{
        "title" => "test",
        "created_at_from" => "2024-01-01",
        "created_at_to" => "2024-12-31"
      }

      columns = [
        %{field: "created_at", filterable: true, filter_type: :date_range, filter_options: []}
      ]

      processed = FilterManager.process_filter_params(filter_params, columns)

      assert processed["created_at"] == "2024-01-01,2024-12-31"
      assert processed["title"] == "test"
      refute Map.has_key?(processed, "created_at_from")
      refute Map.has_key?(processed, "created_at_to")
    end

    test "handles mixed range and regular fields" do
      filter_params = %{
        "name" => "weapon",
        "value_min" => "100",
        "value_max" => "200",
        "created_at_from" => "2024-01-01",
        "created_at_to" => "2024-12-31",
        "status" => "active"
      }

      columns = [
        %{field: "value", filterable: true, filter_type: :number_range},
        %{field: "created_at", filterable: true, filter_type: :date_range}
      ]

      processed = FilterManager.process_filter_params(filter_params, columns)

      # Range fields should be combined
      assert processed["value"] == "100,200"
      assert processed["created_at"] == "2024-01-01,2024-12-31"

      # Regular fields should pass through unchanged
      assert processed["name"] == "weapon"
      assert processed["status"] == "active"

      # Range component keys should be removed
      refute Map.has_key?(processed, "value_min")
      refute Map.has_key?(processed, "value_max")
      refute Map.has_key?(processed, "created_at_from")
      refute Map.has_key?(processed, "created_at_to")
    end
  end

  describe "Boolean Filter Integration" do
    test "boolean filter processes radio button values correctly" do
      filter_params = %{
        "active" => "true",
        "featured" => "false",
        "visible" => ""
      }

      columns = [
        %{field: "active", filterable: true, filter_type: :boolean, filter_options: []},
        %{field: "featured", filterable: true, filter_type: :boolean, filter_options: []},
        %{field: "visible", filterable: true, filter_type: :boolean, filter_options: []}
      ]

      result = FilterManager.params_to_filters(filter_params, columns)

      # True value
      assert result["active"].type == :boolean
      assert result["active"].value == true
      assert result["active"].operator == :equals

      # False value
      assert result["featured"].type == :boolean
      assert result["featured"].value == false
      assert result["featured"].operator == :equals

      # Empty/all value should not create filter
      refute Map.has_key?(result, "visible")
    end

    test "boolean filter build_filter_values handles boolean filters correctly" do
      filters = %{
        "active" => %{
          type: :boolean,
          value: true,
          operator: :equals
        },
        "featured" => %{
          type: :boolean,
          value: false,
          operator: :equals
        }
      }

      columns = [
        %{field: "active", filterable: true, filter_type: :boolean},
        %{field: "featured", filterable: true, filter_type: :boolean},
        %{field: "visible", filterable: true, filter_type: :boolean}
      ]

      result = FilterManager.build_filter_values(columns, filters)

      # Should return string values for form display to match radio button values
      assert result["active"] == "true"
      assert result["featured"] == "false"
      # Should return default empty string for unset filters
      assert result["visible"] == ""
    end

    test "range filter HTML contains correct field names" do
      # Test that number range filter generates correct HTML field names
      alias Cinder.Filters.NumberRange

      column = %{field: "value", filter_type: :number_range}
      current_value = %{min: "100", max: "200"}
      theme = Cinder.Theme.merge("default")
      assigns = %{}

      # Render the filter and check it contains correct field names
      html = NumberRange.render(column, current_value, theme, assigns)

      # Convert to string for inspection
      html_string = Phoenix.HTML.Safe.to_iodata(html) |> IO.iodata_to_binary()

      # Verify the HTML contains the correct field names
      assert html_string =~ ~s(name="filters[value_min]")
      assert html_string =~ ~s(name="filters[value_max]")
      assert html_string =~ ~s(value="100")
      assert html_string =~ ~s(value="200")
    end

    test "full range filter flow from form submission to filter creation" do
      # This test simulates the complete flow that happens in a real app:
      # 1. User types in range filter inputs
      # 2. Form submits with filter_params containing separate min/max fields
      # 3. FilterManager.params_to_filters processes them
      # 4. FilterManager.build_filter_values formats them back for display

      # Step 1: Simulate form submission with range inputs
      raw_form_params = %{
        "filters" => %{
          "name" => "weapon",
          "value_min" => "100",
          "value_max" => "200",
          "created_at_from" => "2024-01-01",
          "created_at_to" => "2024-12-31",
          "active" => "true"
        }
      }

      columns = [
        %{field: "name", filterable: true, filter_type: :text, filter_options: []},
        %{field: "value", filterable: true, filter_type: :number_range, filter_options: []},
        %{field: "created_at", filterable: true, filter_type: :date_range, filter_options: []},
        %{field: "active", filterable: true, filter_type: :boolean, filter_options: []}
      ]

      # Step 2: Process the form params (like the handle_event does)
      filter_params = raw_form_params["filters"]
      processed_filters = FilterManager.params_to_filters(filter_params, columns)

      # Step 3: Verify filters were created correctly
      assert processed_filters["name"].type == :text
      assert processed_filters["name"].value == "weapon"

      assert processed_filters["value"].type == :number_range
      assert processed_filters["value"].value == %{min: "100", max: "200"}
      assert processed_filters["value"].operator == :between

      assert processed_filters["created_at"].type == :date_range
      assert processed_filters["created_at"].value == %{from: "2024-01-01", to: "2024-12-31"}
      assert processed_filters["created_at"].operator == :between

      assert processed_filters["active"].type == :boolean
      assert processed_filters["active"].value == true
      assert processed_filters["active"].operator == :equals

      # Step 4: Build filter values for form display (like update/2 does)
      filter_values = FilterManager.build_filter_values(columns, processed_filters)

      # Step 5: Verify the values are formatted correctly for form display
      assert filter_values["name"] == "weapon"
      assert filter_values["value"] == %{min: "100", max: "200"}
      assert filter_values["created_at"] == %{from: "2024-01-01", to: "2024-12-31"}
      # Should be string for radio buttons
      assert filter_values["active"] == "true"

      # Step 6: Simulate a second form submission to ensure state persistence
      # This simulates user changing just one field while others remain
      updated_form_params = %{
        "filters" => %{
          # Changed
          "name" => "sword",
          # Same
          "value_min" => "100",
          # Same
          "value_max" => "200",
          # Same
          "created_at_from" => "2024-01-01",
          # Same
          "created_at_to" => "2024-12-31",
          # Changed
          "active" => "false"
        }
      }

      updated_filter_params = updated_form_params["filters"]
      updated_processed_filters = FilterManager.params_to_filters(updated_filter_params, columns)

      # Verify changes are reflected while preserving unchanged filters
      assert updated_processed_filters["name"].value == "sword"
      # Unchanged
      assert updated_processed_filters["value"].value == %{min: "100", max: "200"}
      # Unchanged
      assert updated_processed_filters["created_at"].value == %{
               from: "2024-01-01",
               to: "2024-12-31"
             }

      # Changed
      assert updated_processed_filters["active"].value == false
    end

    test "range filter edge cases that might cause real-world issues" do
      columns = [
        %{field: "value", filterable: true, filter_type: :number_range, filter_options: []}
      ]

      # Test 1: Empty form submission (initial state)
      empty_params = %{"filters" => %{}}
      result = FilterManager.params_to_filters(empty_params["filters"], columns)
      assert result == %{}

      # Test 2: Partial range values (only min provided)
      partial_params = %{"filters" => %{"value_min" => "100", "value_max" => ""}}
      result = FilterManager.params_to_filters(partial_params["filters"], columns)
      assert result["value"].value == %{min: "100", max: ""}

      # Only max provided
      partial_params = %{"filters" => %{"value_min" => "", "value_max" => "200"}}
      result = FilterManager.params_to_filters(partial_params["filters"], columns)
      assert result["value"].value == %{min: "", max: "200"}

      # Negative and zero bounds
      signed_params = %{"filters" => %{"value_min" => "-10", "value_max" => "0"}}
      result = FilterManager.params_to_filters(signed_params["filters"], columns)
      assert result["value"].value == %{min: "-10", max: "0"}

      # Test 3: Invalid/whitespace values
      whitespace_params = %{"filters" => %{"value_min" => "  ", "value_max" => "  "}}
      result = FilterManager.params_to_filters(whitespace_params["filters"], columns)
      # Should not create a filter for whitespace-only values
      refute Map.has_key?(result, "value")

      # Test 4: Form contains extra fields not in columns
      extra_params = %{
        "filters" => %{"value_min" => "100", "value_max" => "200", "unknown_field" => "test"}
      }

      result = FilterManager.params_to_filters(extra_params["filters"], columns)
      # Should only process known filterable columns
      assert map_size(result) == 1
      assert result["value"].value == %{min: "100", max: "200"}

      # Test 5: Clearing a range filter by submitting empty values
      clear_params = %{"filters" => %{"value_min" => "", "value_max" => ""}}
      result = FilterManager.params_to_filters(clear_params["filters"], columns)
      # Should not create a filter when both values are empty
      refute Map.has_key?(result, "value")
    end

    test "filter state preservation during form re-rendering (boolean flicker issue)" do
      # This test checks if filter state is preserved when the form re-renders
      # This could be the cause of the "flickering" issue with boolean filters

      columns = [
        %{field: "active", filterable: true, filter_type: :boolean, filter_options: []},
        %{field: "value", filterable: true, filter_type: :number_range, filter_options: []}
      ]

      # Step 1: Initial state - no filters
      initial_filters = %{}
      initial_filter_values = FilterManager.build_filter_values(columns, initial_filters)

      # Verify initial state
      assert initial_filter_values["active"] == ""
      assert initial_filter_values["value"] == %{min: "", max: ""}

      # Step 2: User selects boolean filter value
      boolean_form_params = %{
        "active" => "true",
        "value_min" => "",
        "value_max" => ""
      }

      filters_after_boolean = FilterManager.params_to_filters(boolean_form_params, columns)

      filter_values_after_boolean =
        FilterManager.build_filter_values(columns, filters_after_boolean)

      # Verify boolean is set correctly
      assert filters_after_boolean["active"].value == true
      assert filter_values_after_boolean["active"] == "true"
      # Range should still be empty/default
      assert filter_values_after_boolean["value"] == %{min: "", max: ""}

      # Step 3: User then changes range filter while boolean is still selected
      mixed_form_params = %{
        "active" => "true",
        "value_min" => "100",
        "value_max" => "200"
      }

      filters_after_mixed = FilterManager.params_to_filters(mixed_form_params, columns)
      filter_values_after_mixed = FilterManager.build_filter_values(columns, filters_after_mixed)

      # Verify both filters are preserved
      assert filters_after_mixed["active"].value == true
      assert filter_values_after_mixed["active"] == "true"
      assert filters_after_mixed["value"].value == %{min: "100", max: "200"}
      assert filter_values_after_mixed["value"] == %{min: "100", max: "200"}

      # Step 4: User clears boolean filter (empty)
      clear_boolean_params = %{
        "active" => "",
        "value_min" => "100",
        "value_max" => "200"
      }

      filters_after_clear = FilterManager.params_to_filters(clear_boolean_params, columns)
      filter_values_after_clear = FilterManager.build_filter_values(columns, filters_after_clear)

      # Boolean should be cleared, range should remain
      refute Map.has_key?(filters_after_clear, "active")
      assert filter_values_after_clear["active"] == ""
      assert filters_after_clear["value"].value == %{min: "100", max: "200"}
      assert filter_values_after_clear["value"] == %{min: "100", max: "200"}
    end
  end
end
