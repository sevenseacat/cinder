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
        filterable: true,
        filter_type: :boolean,
        filter_options: [labels: %{all: "Any", true: "Scrolls", false: "Books"}]
      }

      # Should raise helpful error instead of cryptic FunctionClauseError
      assert_raise ArgumentError, ~r/missing required 'field' attribute/, fn ->
        Column.parse_column(user_column, nil)
      end
    end

    test "correct usage with field attribute works" do
      # This is what the user should have used
      correct_column = %{
        # Correct attribute name
        field: "scroll",
        label: "Type",
        filterable: true,
        filter_type: :boolean,
        filter_options: [labels: %{all: "Any", true: "Scrolls", false: "Books"}]
      }

      # Should work without error
      column = Column.parse_column(correct_column, nil)

      assert column.field == "scroll"
      assert column.label == "Type"
      assert column.filterable == true
      assert column.filter_type == :boolean
    end

    test "validates error message is actionable" do
      missing_field_column = %{
        label: "Name"
        # missing field attribute entirely
      }

      assert_raise ArgumentError, fn ->
        Column.parse_column(missing_field_column, nil)
      end

      # Verify the error message is helpful and actionable
      try do
        Column.parse_column(missing_field_column, nil)
      rescue
        error in ArgumentError ->
          message = Exception.message(error)
          assert String.contains?(message, "missing required 'field' attribute")
          assert String.contains?(message, "<:col field=\"column_name\"")
          assert String.contains?(message, "Use:")
      end
    end

    test "empty field attribute raises validation error" do
      empty_field_column = %{
        field: "",
        label: "Name"
      }

      assert_raise ArgumentError, ~r/missing required 'field' attribute/, fn ->
        Column.parse_column(empty_field_column, nil)
      end
    end

    test "nil field attribute raises validation error" do
      nil_field_column = %{
        field: nil,
        label: "Name"
      }

      assert_raise ArgumentError, ~r/missing required 'field' attribute/, fn ->
        Column.parse_column(nil_field_column, nil)
      end
    end

    test "before fix would have caused FunctionClauseError in FilterManager" do
      # This test documents what would have happened before our fix
      # The user would have gotten a cryptic error in ensure_multiselect_fields/2
      # instead of a clear validation error

      # With our fix, this fails fast with clear message at column parsing
      invalid_column = %{
        # Wrong attribute name
        key: "tags",
        filterable: true,
        filter_type: :multi_select
      }

      # Now fails immediately with helpful message
      assert_raise ArgumentError, ~r/missing required 'field' attribute/, fn ->
        Column.parse_column(invalid_column, nil)
      end

      # Before the fix, this would have gotten through column parsing
      # and failed later in FilterManager with:
      # (FunctionClauseError) no function clause matching in
      # Cinder.UrlManager.ensure_multiselect_fields/2
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
