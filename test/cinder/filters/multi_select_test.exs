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
                   left: :tag1,
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

    test "handles three or more values", %{query: query} do
      filter_value = %{
        type: :multi_select,
        value: ["tag1", "tag2", "tag3"],
        operator: :in
      }

      result_query = MultiSelect.build_query(query, "tags", filter_value)

      # Should create nested OR conditions for 3 values:
      # (("tag1" in tags) OR ("tag2" in tags)) OR ("tag3" in tags)
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
        value: ["tag2"],
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
                   left: :tag2,
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
  # Values come from the client (URLs and form events), and each one becomes part of
  # the query, so they're trimmed to what the filter could have offered
  for module <- [Cinder.Filters.MultiSelect, Cinder.Filters.MultiCheckboxes] do
    describe "#{inspect(module)}.process/2 trims client values" do
      @module module

      test "to unique values among the options, when there are options" do
        column = %{filter_options: [options: [{"Rock", :rock}, {"Jazz", "jazz"}, "pop"]]}

        assert %{value: ["rock", "jazz", "pop"]} =
                 @module.process(["rock", "zzz", "rock", "jazz", "pop", ""], column)

        assert @module.process(["zzz", "nope"], column) == nil
      end

      test "to a capped number of unique strings, when there are no options" do
        values = Enum.map(1..500, &"v#{&1}")

        assert %{value: kept} = @module.process(values ++ values, %{filter_options: []})
        assert kept == Enum.take(values, 100)
      end

      test "dropping anything that isn't a string" do
        assert %{value: ["a"]} =
                 @module.process(["a", %{"x" => "y"}, ["b"], 1], %{filter_options: []})
      end
    end
  end
end
