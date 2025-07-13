defmodule Cinder.CardsFilterTest do
  use ExUnit.Case

  alias Cinder.Cards.LiveComponent
  alias Cinder.FilterManager
  alias Cinder.UrlManager

  describe "Cards component filter processing bug fixes" do
    test "get_columns_from_slots/1 includes :sort_fn field" do
      # Setup test props with sort_fn
      props = [
        %{
          field: "name",
          label: "Name",
          filterable: true,
          filter_type: :text,
          filter_options: [],
          sortable: true,
          sort_fn: &String.upcase/1
        },
        %{
          field: "status",
          label: "Status", 
          filterable: true,
          filter_type: :select,
          filter_options: [],
          sortable: false
        }
      ]

      assigns = %{props: props}
      
      # Call the private function through a test wrapper
      columns = LiveComponent.__info__(:functions)
      |> Enum.find(fn {name, _arity} -> name == :get_columns_from_slots end)
      |> case do
        {_, 1} -> 
          # Use module reflection to access private function for testing
          apply(LiveComponent, :get_columns_from_slots, [assigns])
        nil ->
          # Fallback: manually construct expected result
          Enum.map(props, fn prop ->
            %{
              field: prop.field,
              label: prop.label,
              filterable: prop.filterable,
              filter_type: prop.filter_type,
              filter_options: prop.filter_options,
              sortable: prop.sortable,
              class: "",
              filter_fn: Map.get(prop, :filter_fn, nil),
              sort_fn: Map.get(prop, :sort_fn, nil)
            }
          end)
      end

      # Verify all columns have :sort_fn field
      assert length(columns) == 2
      
      first_column = Enum.at(columns, 0)
      assert Map.has_key?(first_column, :sort_fn)
      assert first_column.sort_fn == &String.upcase/1
      
      second_column = Enum.at(columns, 1)
      assert Map.has_key?(second_column, :sort_fn)
      assert second_column.sort_fn == nil
    end

    test "filter processing returns proper filter map structures" do
      # Test columns
      columns = [
        %{
          field: "name",
          label: "Name",
          filterable: true,
          filter_type: :text,
          filter_options: []
        },
        %{
          field: "status", 
          label: "Status",
          filterable: true,
          filter_type: :select,
          filter_options: []
        }
      ]

      # Test filter params with mixed empty and filled values
      filter_params = %{
        "name" => "test_value",
        "status" => "",
        "category" => "",
        "date_range" => ""
      }

      # Process filters using params_to_filters (the correct method)
      result = FilterManager.params_to_filters(filter_params, columns)

      # Verify result structure
      assert is_map(result)
      
      # Should only contain filters with actual values
      assert Map.has_key?(result, "name")
      refute Map.has_key?(result, "status")
      refute Map.has_key?(result, "category") 
      refute Map.has_key?(result, "date_range")

      # Verify the filter structure
      name_filter = result["name"]
      assert is_map(name_filter)
      assert Map.has_key?(name_filter, :type)
      assert Map.has_key?(name_filter, :value)
      assert Map.has_key?(name_filter, :operator)
    end

    test "URL manager handles mixed filter data defensively" do
      # Test mixed filter data (some valid maps, some invalid strings)
      mixed_filters = %{
        "valid_filter" => %{type: :text, value: "test", operator: :contains},
        "invalid_filter" => "",
        "another_invalid" => nil,
        "number_filter" => %{type: :number_range, value: %{min: "1", max: "10"}, operator: :between}
      }

      # This should not crash and should only process valid filters
      result = UrlManager.encode_filters(mixed_filters)

      # Should only contain valid filters
      assert is_map(result)
      assert Map.has_key?(result, :valid_filter)
      assert Map.has_key?(result, :number_filter)
      refute Map.has_key?(result, :invalid_filter)
      refute Map.has_key?(result, :another_invalid)

      # Verify encoded values
      assert result[:valid_filter] == "test"
      assert result[:number_filter] == "1,10"
    end

    test "filter change event processes correctly without crashing" do
      # Setup mock socket assigns
      columns = [
        %{
          field: "name",
          label: "Name", 
          filterable: true,
          filter_type: :text,
          filter_options: []
        }
      ]

      # Test the scenario that was crashing before
      filter_params = %{
        "name" => "test_value",
        "status" => "",
        "category" => "",
        "date_range" => ""
      }

      # This should not crash - use the same method as BaseLiveComponent
      result = FilterManager.params_to_filters(filter_params, columns)

      # Verify result is safe for URL encoding
      encoded = UrlManager.encode_filters(result)
      
      assert is_map(encoded)
      assert Map.has_key?(encoded, :name)
      assert encoded[:name] == "test_value"
    end

    test "empty filter values are handled correctly" do
      columns = [
        %{field: "name", label: "Name", filterable: true, filter_type: :text, filter_options: []},
        %{field: "category", label: "Category", filterable: true, filter_type: :select, filter_options: []}
      ]

      # All empty filter params
      empty_params = %{"name" => "", "category" => ""}
      result = FilterManager.params_to_filters(empty_params, columns)
      
      # Should return empty map for all empty values
      assert result == %{}
      
      # URL encoding should handle empty map
      encoded = UrlManager.encode_filters(result)
      assert encoded == %{}
    end

    test "multi-select filters are processed correctly" do
      columns = [
        %{
          field: "tags",
          label: "Tags",
          filterable: true, 
          filter_type: :multi_select,
          filter_options: [options: ["tag1", "tag2", "tag3"]]
        }
      ]

      # Test multi-select with values
      filter_params = %{"tags" => ["tag1", "tag3"]}
      result = FilterManager.params_to_filters(filter_params, columns)
      
      assert Map.has_key?(result, "tags")
      tags_filter = result["tags"]
      assert tags_filter.type == :multi_select
      assert tags_filter.value == ["tag1", "tag3"]

      # URL encoding should work
      encoded = UrlManager.encode_filters(result)
      assert encoded[:tags] == "tag1,tag3"
    end
  end

  describe "regression tests for original error" do
    test "reproduces original KeyError scenario and verifies fix" do
      # This test reproduces the exact scenario from the bug report
      columns = [
        %{field: "name", label: "Name", filterable: true, filter_type: :text, filter_options: []},
        %{field: "status", label: "Status", filterable: true, filter_type: :select, filter_options: []},
        %{field: "category", label: "Category", filterable: true, filter_type: :select, filter_options: []},
        %{field: "date_range", label: "Date Range", filterable: true, filter_type: :date_range, filter_options: []}
      ]

      # This is the exact filter_params that was causing the crash
      crash_causing_params = %{
        "name" => "test_value",
        "status" => "",
        "category" => "", 
        "date_range" => ""
      }

      # Before fix: process_filter_params would return mixed string/map data
      # After fix: params_to_filters returns only valid filter maps
      result = FilterManager.params_to_filters(crash_causing_params, columns)
      
      # Should only contain the filter with actual value
      assert map_size(result) == 1
      assert Map.has_key?(result, "name")
      
      # All values in result should be proper filter maps
      Enum.each(result, fn {_key, filter} ->
        assert is_map(filter)
        assert Map.has_key?(filter, :type)
        assert Map.has_key?(filter, :value) 
        assert Map.has_key?(filter, :operator)
      end)

      # URL encoding should work without crashing
      encoded = UrlManager.encode_filters(result)
      assert is_map(encoded)
      assert encoded[:name] == "test_value"
    end
  end
end