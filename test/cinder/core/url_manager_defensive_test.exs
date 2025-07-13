defmodule Cinder.UrlManagerDefensiveTest do
  use ExUnit.Case
  
  alias Cinder.UrlManager

  describe "encode_filters/1 defensive behavior" do
    test "filters out non-map values" do
      mixed_data = %{
        "valid" => %{type: :text, value: "test", operator: :contains},
        "empty_string" => "",
        "nil_value" => nil,
        "number" => 123,
        "list" => ["a", "b"],
        "another_valid" => %{type: :select, value: "option1", operator: :eq}
      }

      result = UrlManager.encode_filters(mixed_data)

      # Should only contain the valid map filters
      assert Map.has_key?(result, :valid)
      assert Map.has_key?(result, :another_valid)
      refute Map.has_key?(result, :empty_string)
      refute Map.has_key?(result, :nil_value)
      refute Map.has_key?(result, :number)
      refute Map.has_key?(result, :list)
    end

    test "filters out maps without :type key" do
      mixed_maps = %{
        "valid_filter" => %{type: :text, value: "test", operator: :contains},
        "invalid_map" => %{value: "test", operator: :contains}, # missing :type
        "another_invalid" => %{type: nil, value: "test"}, # nil :type  
        "empty_map" => %{},
        "valid_multi" => %{type: :multi_select, value: ["a", "b"], operator: :in}
      }

      result = UrlManager.encode_filters(mixed_maps)

      # Should only contain maps with proper non-nil :type key
      assert Map.has_key?(result, :valid_filter)
      assert Map.has_key?(result, :valid_multi)
      refute Map.has_key?(result, :invalid_map)
      refute Map.has_key?(result, :another_invalid) # nil :type should be filtered out
      refute Map.has_key?(result, :empty_map)
    end

    test "uses Map.get for safe access to filter.type" do
      # Test with map that has :type key
      valid_filter = %{type: :text, value: "test", operator: :contains}
      result = UrlManager.encode_filters(%{"test" => valid_filter})
      assert result[:test] == "test"

      # Test with map that looks like a filter but has string :type
      edge_case = %{"type" => "text", "value" => "test"}
      result2 = UrlManager.encode_filters(%{"edge" => edge_case})
      # Should be filtered out because "type" (string) != :type (atom)
      refute Map.has_key?(result2, :edge)
    end

    test "handles all filter types safely" do
      all_types = %{
        "text" => %{type: :text, value: "hello", operator: :contains},
        "select" => %{type: :select, value: "option1", operator: :eq},
        "multi_select" => %{type: :multi_select, value: ["a", "b"], operator: :in},
        "multi_checkboxes" => %{type: :multi_checkboxes, value: ["x", "y"], operator: :in},
        "date_range" => %{type: :date_range, value: %{from: "2023-01-01", to: "2023-12-31"}, operator: :between},
        "number_range" => %{type: :number_range, value: %{min: "1", max: "100"}, operator: :between},
        "boolean" => %{type: :boolean, value: true, operator: :eq}
      }

      result = UrlManager.encode_filters(all_types)

      # All should be encoded properly
      assert result[:text] == "hello"
      assert result[:select] == "option1"
      assert result[:multi_select] == "a,b"
      assert result[:multi_checkboxes] == "x,y"
      assert result[:date_range] == "2023-01-01,2023-12-31"
      assert result[:number_range] == "1,100"
      assert result[:boolean] == "true"
    end

    test "handles empty filters map" do
      result = UrlManager.encode_filters(%{})
      assert result == %{}
    end

    test "does not crash on malformed filter structures" do
      malformed = %{
        "no_value" => %{type: :text, operator: :contains},
        "bad_multi" => %{type: :multi_select, value: "not_a_list", operator: :in},
        "bad_range" => %{type: :date_range, value: "not_a_map", operator: :between}
      }

      # Should not crash, should handle malformed data gracefully
      result = UrlManager.encode_filters(malformed)
      
      # All should be processed without error
      assert Map.has_key?(result, :no_value)
      assert Map.has_key?(result, :bad_multi) 
      assert Map.has_key?(result, :bad_range)
      
      # Values should be safely converted to strings
      assert result[:no_value] == "" # missing value becomes empty string
      assert result[:bad_multi] == "not_a_list" # non-list becomes string
      assert result[:bad_range] == "not_a_map" # non-map becomes string
    end

    test "preserves key types correctly" do
      filters = %{
        "string_key" => %{type: :text, value: "test", operator: :contains},
        :atom_key => %{type: :select, value: "option", operator: :eq}
      }

      result = UrlManager.encode_filters(filters)

      # Keys should be converted to atoms
      assert Map.has_key?(result, :string_key)
      assert Map.has_key?(result, :atom_key)
    end
  end

  describe "integration with filter processing" do
    test "handles result from params_to_filters safely" do
      # Simulate what FilterManager.params_to_filters returns
      processed_filters = %{
        "name" => %{type: :text, value: "john", operator: :contains},
        "status" => %{type: :select, value: "active", operator: :eq}
      }

      # This should work seamlessly
      encoded = UrlManager.encode_filters(processed_filters)
      
      assert encoded[:name] == "john"
      assert encoded[:status] == "active"
    end

    test "gracefully handles mixed data from buggy processing" do
      # Simulate the buggy scenario that was happening before
      buggy_mixed = %{
        "valid_filter" => %{type: :text, value: "test", operator: :contains},
        "empty_filter" => "", # This was causing the crash
        "nil_filter" => nil,
        "another_valid" => %{type: :select, value: "option", operator: :eq}
      }

      # Should not crash and should filter out problematic entries
      result = UrlManager.encode_filters(buggy_mixed)
      
      assert Map.has_key?(result, :valid_filter)
      assert Map.has_key?(result, :another_valid)
      refute Map.has_key?(result, :empty_filter)
      refute Map.has_key?(result, :nil_filter)
    end
  end

end