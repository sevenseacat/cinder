defmodule Cinder.Filters.SelectTest do
  use ExUnit.Case, async: true

  alias Cinder.Filters.Select
  alias Cinder.Test.FilterRecord
  alias TestResourceForInference

  describe "Select filter build_query/3 for array fields" do
    setup do
      query = Ash.Query.new(TestResourceForInference)
      %{query: query}
    end

    test "matches records whose array contains the value" do
      hit = FilterRecord.seed(tags: ["tag1", "tag2"])
      _miss = FilterRecord.seed(tags: ["tag2"])
      filter_value = %{type: :select, value: "tag1", operator: :equals}

      assert FilterRecord.matching_ids(Select, "tags", filter_value) == MapSet.new([hit.id])
    end

    test "matches a plain field by equality" do
      hit = FilterRecord.seed(name: "tag1")
      _miss = FilterRecord.seed(name: "tag10")
      filter_value = %{type: :select, value: "tag1", operator: :equals}

      assert FilterRecord.matching_ids(Select, "name", filter_value) == MapSet.new([hit.id])
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
