defmodule Cinder.Filters.BooleanTest do
  use ExUnit.Case, async: true

  alias Cinder.Filters.Boolean
  alias TestResourceForInference

  describe "Boolean filter build_query/3 for array fields" do
    setup do
      query = Ash.Query.new(TestResourceForInference)
      %{query: query}
    end

    test "creates containment filter for boolean array fields", %{query: query} do
      filter_value = %{
        type: :boolean,
        value: true,
        operator: :equals
      }

      result_query = Boolean.build_query(query, "tags", filter_value)

      # Should create: true in tags (not tags == true)
      assert match?(
               %Ash.Filter{
                 expression: %Ash.Query.Operator.In{
                   left: true,
                   operator: :in,
                   right: %{attribute: %{name: :tags}}
                 }
               },
               result_query.filter
             )
    end

    test "handles false values in array fields", %{query: query} do
      filter_value = %{
        type: :boolean,
        value: false,
        operator: :equals
      }

      result_query = Boolean.build_query(query, "tags", filter_value)

      # Should create: false in tags (not tags == false)
      assert match?(
               %Ash.Filter{
                 expression: %Ash.Query.Operator.In{
                   left: false,
                   operator: :in,
                   right: %{attribute: %{name: :tags}}
                 }
               },
               result_query.filter
             )
    end

    test "returns unchanged query for empty values on array fields", %{query: query} do
      filter_value = %{
        type: :boolean,
        value: nil,
        operator: :equals
      }

      result_query = Boolean.build_query(query, "tags", filter_value)

      # Empty values should not modify the query, even for array fields
      assert result_query == query
    end

    test "array vs non-array fields produce different query structures", %{query: query} do
      filter_value = %{
        type: :boolean,
        value: true,
        operator: :equals
      }

      # Non-array field should use equality
      bool_query = Boolean.build_query(query, "active", filter_value)

      # Array field should use containment
      array_query = Boolean.build_query(query, "tags", filter_value)

      # Should produce different filter structures
      refute bool_query.filter == array_query.filter

      # Array query should have containment structure
      assert match?(
               %Ash.Filter{
                 expression: %Ash.Query.Operator.In{
                   left: true,
                   operator: :in,
                   right: %{attribute: %{name: :tags}}
                 }
               },
               array_query.filter
             )
    end
  end

  # Note: Basic process/2, validate/1, empty?/1 functionality is tested in
  # test/cinder/configuration/filters_test.exs
end
