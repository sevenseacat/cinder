defmodule Cinder.Filters.MultiSelectTest do
  use ExUnit.Case, async: true

  alias Cinder.Filters.MultiSelect
  alias TestResourceForInference

  describe "MultiSelect filter build_query/3 for array fields" do
    setup do
      query = Ash.Query.new(TestResourceForInference)
      %{query: query}
    end

    test "creates containment filter for single value", %{query: query} do
      filter_value = %{
        type: :multi_select,
        value: ["tag1"],
        operator: :in
      }

      result_query = MultiSelect.build_query(query, "tags", filter_value)

      # Should create: "tag1" in tags (not tags in ["tag1"])
      assert match?(
               %Ash.Filter{
                 expression: %Ash.Query.Operator.In{
                   left: "tag1",
                   operator: :in,
                   right: %{attribute: %{name: :tags}}
                 }
               },
               result_query.filter
             )
    end

    test "creates OR conditions for multiple values", %{query: query} do
      filter_value = %{
        type: :multi_select,
        value: ["tag1", "tag2"],
        operator: :in
      }

      result_query = MultiSelect.build_query(query, "tags", filter_value)

      # Should create: ("tag1" in tags) OR ("tag2" in tags)
      assert match?(
               %Ash.Filter{
                 expression: %Ash.Query.BooleanExpression{
                   op: :or,
                   left: %Ash.Query.Operator.In{right: %{attribute: %{name: :tags}}},
                   right: %Ash.Query.Operator.In{right: %{attribute: %{name: :tags}}}
                 }
               },
               result_query.filter
             )
    end

    test "handles multiple values with different types", %{query: query} do
      filter_value = %{
        type: :multi_select,
        value: ["Morrowind.esm", "Tribunal.esm", "Bloodmoon.esm"],
        operator: :in
      }

      result_query = MultiSelect.build_query(query, "tags", filter_value)

      # Should create nested OR conditions for 3 values:
      # (("Morrowind.esm" in tags) OR ("Tribunal.esm" in tags)) OR ("Bloodmoon.esm" in tags)
      assert match?(
               %Ash.Filter{
                 expression: %Ash.Query.BooleanExpression{
                   op: :or,
                   left: %Ash.Query.BooleanExpression{op: :or},
                   right: %Ash.Query.Operator.In{right: %{attribute: %{name: :tags}}}
                 }
               },
               result_query.filter
             )
    end

    test "returns unchanged query for empty values on array fields", %{query: query} do
      filter_value = %{
        type: :multi_select,
        value: [],
        operator: :in
      }

      result_query = MultiSelect.build_query(query, "tags", filter_value)

      # Empty values should not modify the query, even for array fields
      assert result_query == query
    end

    test "array vs non-array fields produce different query structures", %{query: query} do
      filter_value = %{
        type: :multi_select,
        value: ["test_value"],
        operator: :in
      }

      # Non-array field should use standard IN
      enum_query = MultiSelect.build_query(query, "status_enum", filter_value)

      # Array field should use containment
      array_query = MultiSelect.build_query(query, "tags", filter_value)

      # Should produce different filter structures
      refute enum_query.filter == array_query.filter

      # Array query should have containment structure
      assert match?(
               %Ash.Filter{
                 expression: %Ash.Query.Operator.In{
                   left: "test_value",
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
