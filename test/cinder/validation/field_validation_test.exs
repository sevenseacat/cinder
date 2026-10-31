defmodule Cinder.FieldValidationTest do
  use ExUnit.Case, async: true

  alias Cinder.Column

  describe "field attribute validation" do
    test "correct usage with field attribute works" do
      # This is what the user should have used
      correct_column = %{
        # Correct attribute name
        field: "scroll",
        label: "Type",
        filter: true
      }

      # Should work without error
      [column] = Cinder.Collection.process_columns([correct_column], nil)

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
        Cinder.Collection.process_columns([missing_field_column], nil)
      end

      # Verify the error message is helpful and actionable
      try do
        Cinder.Collection.process_columns([missing_field_column], nil)
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
      [column] = Cinder.Collection.process_columns([empty_field_column], nil)
      assert column.field == ""
      assert column.label == "Actions"
      assert column.filterable == false
      assert column.sortable == false
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
                     Cinder.Collection.process_columns([invalid_column], nil)
                   end
    end

    test "action columns work without field attribute" do
      # This documents the new action column functionality
      action_column = %{
        label: "Actions"
        # No field, filter, or sort - this is an action column
      }

      [column] = Cinder.Collection.process_columns([action_column], nil)
      assert column.field == nil
      assert column.label == "Actions"
      assert column.filterable == false
      assert column.sortable == false
    end
  end

  describe "form field name generation" do
    test "handles relationship fields correctly" do
      column = %{
        field: "artist.name",
        filterable: true,
        filter_type: :text
      }

      parsed_column = Column.parse_column(column, Music.Album)

      assert parsed_column.field == "artist.name"
      assert parsed_column.relationship == "artist"
      assert parsed_column.display_field == "name"
    end
  end

  describe "embedded field validation" do
    @tag :capture_log
    test "column validation uses comprehensive field validation" do
      # Test that Column module properly validates embedded fields
      column_config = %{
        field: "profile__first_name",
        filterable: true
      }

      column = Column.parse_column(column_config, TestResourceForInference)

      # Should not have warnings for valid embedded field
      assert column.filterable == true
      assert is_nil(column.filter_warning)

      # Test invalid embedded field generates warning
      invalid_column_config = %{
        field: "profile__nonexistent",
        filterable: true
      }

      invalid_column = Column.parse_column(invalid_column_config, TestResourceForInference)

      # Should have warning for invalid embedded field
      assert invalid_column.filterable == false
      assert not is_nil(invalid_column.filter_warning)
    end

    test "sort validation handles embedded fields" do
      # Valid embedded field should be sortable (if not in-memory calc)
      valid_sort = [{"profile__first_name", :asc}]

      assert Cinder.QueryBuilder.validate_sortable_fields(valid_sort, TestResourceForInference) ==
               :ok

      # Invalid embedded field should fail validation
      invalid_sort = [{"profile__nonexistent", :asc}]

      result =
        Cinder.QueryBuilder.validate_sortable_fields(invalid_sort, TestResourceForInference)

      assert match?({:error, _}, result)
    end
  end
end
