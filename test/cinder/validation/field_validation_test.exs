defmodule Cinder.FieldValidationTest do
  use ExUnit.Case, async: true

  alias Cinder.Column

  describe "field attribute validation" do
    test "reproduces original user error case - using key instead of field" do
      # This reproduces the exact error the user encountered
      # when they used key="scroll" instead of field="scroll"
      user_column = %{
        # This is what the user had
        key: "scroll",
        label: "Type",
        # This requires a field
        filter: true
      }

      # Should raise helpful error at table level when filter is used without field
      assert_raise ArgumentError,
                   ~r/column with filter attribute\(s\) requires a 'field' attribute/,
                   fn ->
                     Cinder.Table.process_columns([user_column], nil)
                   end
    end

    test "correct usage with field attribute works" do
      # This is what the user should have used
      correct_column = %{
        # Correct attribute name
        field: "scroll",
        label: "Type",
        filter: true
      }

      # Should work without error
      [column] = Cinder.Table.process_columns([correct_column], nil)

      assert column.field == "scroll"
      assert column.label == "Type"
      assert column.filterable == true
    end

    test "validates error message is actionable when filter is used without field" do
      missing_field_column = %{
        label: "Name",
        # This requires a field
        filter: true
        # missing field attribute entirely
      }

      assert_raise ArgumentError, fn ->
        Cinder.Table.process_columns([missing_field_column], nil)
      end

      # Verify the error message is helpful and actionable
      try do
        Cinder.Table.process_columns([missing_field_column], nil)
      rescue
        error in ArgumentError ->
          message = Exception.message(error)
          assert String.contains?(message, "requires a 'field' attribute")
          assert String.contains?(message, "Add a field: <:col field=\"field_name\" filter>")
          assert String.contains?(message, "Remove filter attribute(s) for action columns")
      end
    end

    test "empty field attribute works for action columns" do
      empty_field_column = %{
        field: "",
        label: "Actions"
      }

      # Should work for action columns (no filter/sort)
      [column] = Cinder.Table.process_columns([empty_field_column], nil)
      assert column.field == ""
      assert column.label == "Actions"
      assert column.filterable == false
      assert column.sortable == false
    end

    test "nil field attribute works for action columns" do
      nil_field_column = %{
        field: nil,
        label: "Actions"
      }

      # Should work for action columns (no filter/sort)
      [column] = Cinder.Table.process_columns([nil_field_column], nil)
      assert column.field == nil
      assert column.label == "Actions"
      assert column.filterable == false
      assert column.sortable == false
    end

    test "filter without field raises validation error at table level" do
      # This test documents that filtering requires a field attribute
      invalid_column = %{
        # Wrong attribute name - missing field
        # This should be field: "tags"
        key: "tags",
        filter: :multi_select
      }

      # Now fails immediately with helpful message at table level
      assert_raise ArgumentError,
                   ~r/column with filter attribute\(s\) requires a 'field' attribute/,
                   fn ->
                     Cinder.Table.process_columns([invalid_column], nil)
                   end
    end

    test "sort without field raises validation error at table level" do
      # This test documents that sorting requires a field attribute
      invalid_column = %{
        label: "Name",
        # This requires a field
        sort: true
        # missing field attribute
      }

      assert_raise ArgumentError,
                   ~r/column with sort attribute\(s\) requires a 'field' attribute/,
                   fn ->
                     Cinder.Table.process_columns([invalid_column], nil)
                   end
    end

    test "action columns work without field attribute" do
      # This documents the new action column functionality
      action_column = %{
        label: "Actions"
        # No field, filter, or sort - this is an action column
      }

      [column] = Cinder.Table.process_columns([action_column], nil)
      assert column.field == nil
      assert column.label == "Actions"
      assert column.filterable == false
      assert column.sortable == false
    end
  end

  describe "form field name generation" do
    test "generates correct form field names with field attribute" do
      column = %{
        field: "scroll",
        filterable: true,
        filter_type: :boolean
      }

      parsed_column = Column.parse_column(column, nil)

      # Verify the field name is used correctly
      assert parsed_column.field == "scroll"

      # This would generate proper form field names like filters[scroll]
      # instead of broken filters[] that the user was experiencing
    end

    test "handles relationship fields correctly" do
      column = %{
        field: "user.department",
        filterable: true,
        filter_type: :text
      }

      parsed_column = Column.parse_column(column, nil)

      assert parsed_column.field == "user.department"
      assert parsed_column.relationship == "user"
      assert parsed_column.display_field == "department"
    end
  end

  describe "consistency verification" do
    test "field attribute is used consistently throughout column struct" do
      column = %{
        field: "test_field",
        label: "Test Field",
        filterable: true,
        filter_type: :text
      }

      parsed_column = Column.parse_column(column, nil)

      # Verify field is stored consistently (not as key)
      assert parsed_column.field == "test_field"

      # Verify there's no confusing key attribute
      refute Map.has_key?(parsed_column, :key)
    end
  end
end
