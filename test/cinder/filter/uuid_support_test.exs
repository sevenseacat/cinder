defmodule Cinder.Filter.UuidSupportTest do
  use ExUnit.Case, async: true

  alias Cinder.Filter.Helpers

  # Import test resources from support directory
  alias TestUuidResource
  alias TestUserResource

  describe "universal string casting approach" do
    test "string casting is applied to all text operators" do
      # With the simplified approach, we always cast to string for text operations
      # This eliminates the need for field type detection complexity

      query = Ash.Query.new(TestUuidResource)

      # All text operators should work with string casting
      text_operators = [:contains, :starts_with, :ends_with]

      for operator <- text_operators do
        # UUID field - should work without errors
        result = Helpers.build_ash_filter(query, "user_id", "123e4567", operator)
        assert %Ash.Query{} = result
        refute result == query

        # String field - should work as before
        result = Helpers.build_ash_filter(query, "name", "test", operator)
        assert %Ash.Query{} = result
        refute result == query

        # Integer field - casting to string should work for text operations
        result = Helpers.build_ash_filter(query, "count", "42", operator)
        assert %Ash.Query{} = result
      end
    end

    test "equals operator does not use string casting" do
      # Equals should work with original field types to preserve proper comparisons
      query = Ash.Query.new(TestUuidResource)

      # UUID field equals
      result =
        Helpers.build_ash_filter(
          query,
          "user_id",
          "123e4567-e89b-12d3-a456-426614174000",
          :equals
        )

      assert %Ash.Query{} = result

      # String field equals
      result = Helpers.build_ash_filter(query, "name", "test", :equals)
      assert %Ash.Query{} = result

      # Integer field equals
      result = Helpers.build_ash_filter(query, "count", 42, :equals)
      assert %Ash.Query{} = result
    end

    test "non-text operators work with original field types" do
      query = Ash.Query.new(TestUuidResource)

      # These operators should work with original field types
      non_text_operators = [:greater_than, :less_than, :in]

      for operator <- non_text_operators do
        case operator do
          :in ->
            result = Helpers.build_ash_filter(query, "count", [1, 2, 3], operator)
            assert %Ash.Query{} = result

          _ ->
            result = Helpers.build_ash_filter(query, "count", 10, operator)
            assert %Ash.Query{} = result
        end
      end
    end
  end

  describe "build_ash_filter/4 with universal string casting" do
    test "builds correct filter for UUID field with text operators" do
      query = Ash.Query.new(TestUuidResource)

      # Test all text operators on UUID fields
      text_cases = [
        {"user_id", "123e4567", :contains},
        {"id", "123e4567-e89b", :starts_with},
        {"organization_id", "000", :ends_with}
      ]

      for {field, value, operator} <- text_cases do
        result_query = Helpers.build_ash_filter(query, field, value, operator)
        assert %Ash.Query{} = result_query
        refute result_query == query
      end
    end

    test "builds correct filter for UUID field with equals operator" do
      query = Ash.Query.new(TestUuidResource)
      field = "id"
      value = "123e4567-e89b-12d3-a456-426614174000"
      operator = :equals

      result_query = Helpers.build_ash_filter(query, field, value, operator)

      refute result_query == query
      assert %Ash.Query{} = result_query
    end

    test "builds filters for all field types with text operators" do
      query = Ash.Query.new(TestUuidResource)

      # With universal casting, all field types should work with text operators
      field_cases = [
        # string
        {"name", "test"},
        # uuid
        {"user_id", "123e4567"},
        # integer (as string for text search)
        {"count", "42"},
        # string
        {"status", "active"}
      ]

      for {field, value} <- field_cases do
        for operator <- [:contains, :starts_with, :ends_with] do
          result_query = Helpers.build_ash_filter(query, field, value, operator)
          assert %Ash.Query{} = result_query
          refute result_query == query
        end
      end
    end

    test "handles relationship fields with text operators" do
      query = Ash.Query.new(TestUuidResource)

      relationship_cases = [
        # uuid in relationship
        {"user.id", "123e4567", :contains},
        # string in relationship
        {"user.email", "test@example.com", :contains}
      ]

      for {field, value, operator} <- relationship_cases do
        result_query = Helpers.build_ash_filter(query, field, value, operator)
        assert %Ash.Query{} = result_query
        refute result_query == query
      end
    end

    test "handles non-text operators without string casting" do
      query = Ash.Query.new(TestUuidResource)

      # Non-text operators should work with original field types
      non_text_cases = [
        {"count", 42, :greater_than},
        {"count", 10, :less_than},
        {"count", [1, 2, 3], :in}
      ]

      for {field, value, operator} <- non_text_cases do
        result_query = Helpers.build_ash_filter(query, field, value, operator)
        assert %Ash.Query{} = result_query
      end
    end

    test "handles invalid field references gracefully" do
      query = Ash.Query.new(TestUuidResource)
      field = "non_existent_field"
      value = "test"
      operator = :contains

      result_query = Helpers.build_ash_filter(query, field, value, operator)
      assert %Ash.Query{} = result_query
    end
  end

  describe "integration with text filter processing" do
    test "UUID field filtering should work end-to-end" do
      # Simulate how the text filter would process a UUID field
      query = Ash.Query.new(TestUuidResource)

      # This simulates what happens when a text filter processes a UUID field
      filter_value = %{
        type: :text,
        value: "123e4567",
        operator: :contains,
        case_sensitive: false
      }

      # The build_query function from text filter would call our helper
      field = "user_id"

      result_query =
        Helpers.build_ash_filter(
          query,
          field,
          Ash.CiString.new(filter_value.value),
          filter_value.operator
        )

      assert %Ash.Query{} = result_query
      refute result_query == query
    end

    test "mixed UUID and non-UUID field filtering" do
      query = Ash.Query.new(TestUuidResource)

      # Apply UUID field filter
      query_with_uuid_filter =
        Helpers.build_ash_filter(
          query,
          "user_id",
          "123e4567",
          :contains
        )

      # Apply string field filter to the same query
      final_query =
        Helpers.build_ash_filter(
          query_with_uuid_filter,
          "name",
          "test",
          :contains
        )

      assert %Ash.Query{} = final_query
      refute final_query == query
      refute final_query == query_with_uuid_filter
    end
  end

  describe "error handling and edge cases" do
    test "handles empty string values" do
      query = Ash.Query.new(TestUuidResource)

      result_query = Helpers.build_ash_filter(query, "user_id", "", :contains)

      assert %Ash.Query{} = result_query
    end

    test "handles nil values" do
      query = Ash.Query.new(TestUuidResource)

      result_query = Helpers.build_ash_filter(query, "user_id", nil, :contains)

      assert %Ash.Query{} = result_query
    end

    test "handles very long UUID-like strings" do
      query = Ash.Query.new(TestUuidResource)
      long_value = String.duplicate("a", 1000)

      result_query = Helpers.build_ash_filter(query, "user_id", long_value, :contains)

      assert %Ash.Query{} = result_query
    end

    test "handles partial UUID strings" do
      query = Ash.Query.new(TestUuidResource)

      # Test various partial UUID patterns
      partial_uuids = [
        "123e4567",
        "123e4567-e89b",
        "123e4567-e89b-12d3",
        "123e4567-e89b-12d3-a456",
        "e89b-12d3-a456-426614174000"
      ]

      for partial_uuid <- partial_uuids do
        result_query = Helpers.build_ash_filter(query, "user_id", partial_uuid, :contains)
        assert %Ash.Query{} = result_query
      end
    end
  end

  describe "comprehensive field type compatibility" do
    test "string casting works for all common field types" do
      # Test that universal string casting works for various field types
      query = Ash.Query.new(TestResourceForInference)

      # Test all field types with text operators
      field_cases = [
        # string
        {"name", "test"},
        # integer
        {"count", "123"},
        # boolean
        {"active", "true"},
        # date
        {"created_at", "2024"},
        # decimal
        {"price", "99"},
        # uuid
        {"id", "123e4567"}
      ]

      for {field, value} <- field_cases do
        for operator <- [:contains, :starts_with, :ends_with] do
          result = Helpers.build_ash_filter(query, field, value, operator)
          assert %Ash.Query{} = result
          refute result == query
        end
      end
    end

    test "mixed field types in single query" do
      query = Ash.Query.new(TestUuidResource)

      # Apply multiple filters with different field types
      query_with_uuid_filter =
        Helpers.build_ash_filter(query, "user_id", "123e4567", :contains)

      query_with_string_filter =
        Helpers.build_ash_filter(query_with_uuid_filter, "name", "test", :contains)

      final_query =
        Helpers.build_ash_filter(query_with_string_filter, "count", "42", :contains)

      assert %Ash.Query{} = final_query
      refute final_query == query
    end
  end
end
