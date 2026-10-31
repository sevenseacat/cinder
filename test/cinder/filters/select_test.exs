defmodule Cinder.Filters.SelectTest do
  use ExUnit.Case, async: true

  alias Cinder.Filters.Select
  alias TestResourceForInference

  describe "Select filter build_query/3 for array fields" do
    setup do
      query = Ash.Query.new(TestResourceForInference)
      %{query: query}
    end

    test "creates containment filter for array fields", %{query: query} do
      filter_value = %{
        type: :select,
        value: "tag1",
        operator: :equals
      }

      result_query = Select.build_query(query, "tags", filter_value)

      # Should create: "tag1" in tags (not tags == "tag1")
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

    test "returns unchanged query for empty values on array fields", %{query: query} do
      filter_value = %{
        type: :select,
        value: "",
        operator: :equals
      }

      result_query = Select.build_query(query, "tags", filter_value)

      # Empty values should not modify the query, even for array fields
      assert result_query == query
    end
  end
end
