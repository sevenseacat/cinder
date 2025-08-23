defmodule Cinder.ColumnTest do
  use ExUnit.Case, async: true

  alias Cinder.Column

  describe "parse_column/2" do
    test "parses basic column with defaults" do
      slot = %{field: "name", label: "Name"}
      resource = nil

      column = Column.parse_column(slot, resource)

      assert column.field == "name"
      assert column.label == "Name"
      assert column.sortable == false
      assert column.filterable == false
      assert column.filter_type == :text
      assert column.class == ""
      assert column.slot == slot
    end

    test "respects filterable attribute when false" do
      slot = %{field: "name", label: "Name", filterable: false}
      resource = nil

      column = Column.parse_column(slot, resource)

      assert column.filterable == false
      assert column.filter_type == :text
    end

    test "respects filterable attribute when true" do
      slot = %{field: "name", label: "Name", filterable: true}
      resource = nil

      column = Column.parse_column(slot, resource)

      assert column.filterable == true
      assert column.filter_type == :text
    end

    test "preserves slot configuration over defaults" do
      slot = %{
        field: "email",
        label: "Email Address",
        sortable: false,
        filterable: true,
        filter_type: :text,
        class: "w-1/4"
      }

      resource = nil

      column = Column.parse_column(slot, resource)

      assert column.field == "email"
      assert column.label == "Email Address"
      assert column.sortable == false
      assert column.filterable == true
      assert column.filter_type == :text
      assert column.class == "w-1/4"
    end

    test "generates label from field when not provided" do
      slot = %{field: "user_name"}
      resource = nil

      column = Column.parse_column(slot, resource)

      assert column.label == "User Name"
    end

    test "creates action column when field attribute is missing" do
      slot = %{label: "Actions"}
      resource = nil

      column = Column.parse_column(slot, resource)

      assert column.field == nil
      assert column.label == "Actions"
      assert column.sortable == false
      assert column.filterable == false
    end

    test "creates action column when field attribute is empty" do
      slot = %{field: "", label: "Actions"}
      resource = nil

      column = Column.parse_column(slot, resource)

      assert column.field == nil
      assert column.label == "Actions"
      assert column.sortable == false
      assert column.filterable == false
    end

    test "creates action column when field attribute is nil" do
      slot = %{field: nil, label: "Actions"}
      resource = nil

      column = Column.parse_column(slot, resource)

      assert column.field == nil
      assert column.label == "Actions"
      assert column.sortable == false
      assert column.filterable == false
    end

    test "handles relationship fields with dot notation" do
      slot = %{field: "user.name", label: "User Name"}
      resource = nil

      column = Column.parse_column(slot, resource)

      assert column.field == "user.name"
      assert column.relationship == "user"
      assert column.display_field == "name"
      assert column.label == "User Name"
    end
  end

  describe "parse_columns/2" do
    test "parses multiple columns" do
      slots = [
        %{field: "id", label: "ID"},
        %{field: "name", label: "Name"},
        %{field: "email", label: "Email"}
      ]

      resource = nil

      columns = Column.parse_columns(slots, resource)

      assert length(columns) == 3
      assert Enum.map(columns, & &1.field) == ["id", "name", "email"]
      assert Enum.map(columns, & &1.label) == ["ID", "Name", "Email"]
    end
  end

  describe "validate/1" do
    test "validates valid column" do
      column = %Column{
        field: "name",
        label: "Name",
        sortable: true,
        filterable: true,
        filter_type: :text,
        filter_options: []
      }

      assert {:ok, ^column} = Column.validate(column)
    end

    test "rejects column with empty field" do
      column = %Column{
        field: "",
        label: "Name",
        filter_type: :text
      }

      assert {:error, errors} = Column.validate(column)
      assert "Field cannot be empty" in errors
    end

    test "rejects column with empty label" do
      column = %Column{
        field: "name",
        label: "",
        filter_type: :text
      }

      assert {:error, errors} = Column.validate(column)
      assert "Label cannot be empty" in errors
    end

    test "rejects column with invalid filter type" do
      column = %Column{
        field: "name",
        label: "Name",
        filter_type: :invalid_type
      }

      assert {:error, errors} = Column.validate(column)
      assert "Invalid filter type: invalid_type" in errors
    end

    test "accepts checkbox filter type" do
      column = %Column{
        field: "published",
        label: "Published",
        filter_type: :checkbox
      }

      assert {:ok, _} = Column.validate(column)
    end

    test "returns multiple errors" do
      column = %Column{
        field: "",
        label: "",
        filter_type: :invalid
      }

      assert {:error, errors} = Column.validate(column)
      assert "Field cannot be empty" in errors
      assert "Label cannot be empty" in errors
      assert "Invalid filter type: invalid" in errors
    end
  end

  describe "merge_config/2" do
    test "merges slot config with inferred config" do
      slot = %{
        label: "Custom Label",
        sortable: false,
        class: "custom-class"
      }

      inferred = %{
        label: "Inferred Label",
        sortable: true,
        filterable: true,
        filter_type: :select,
        filter_options: [options: []]
      }

      result = Column.merge_config(slot, inferred)

      # Slot values should take precedence
      assert result.label == "Custom Label"
      assert result.sortable == false
      assert result.class == "custom-class"

      # Inferred values should be used when not in slot
      assert result.filterable == true
      assert result.filter_type == :select
      assert result.filter_options == [options: []]
    end

    test "preserves all inferred config when slot is empty" do
      slot = %{}

      inferred = %{
        sortable: true,
        filterable: true,
        filter_type: :number_range,
        filter_options: []
      }

      result = Column.merge_config(slot, inferred)

      assert result == inferred
    end
  end

  describe "relationship key parsing" do
    test "parses simple relationship" do
      slot = %{field: "user.email"}
      resource = nil

      column = Column.parse_column(slot, resource)

      assert column.field == "user.email"
      assert column.relationship == "user"
      assert column.display_field == "email"
    end

    test "handles non-relationship fields" do
      slot = %{field: "simple_field"}
      resource = nil

      column = Column.parse_column(slot, resource)

      assert column.field == "simple_field"
      assert column.relationship == nil
      assert column.display_field == nil
    end

    test "generates proper label for relationship fields" do
      slot = %{field: "user.profile.avatar"}
      resource = nil

      column = Column.parse_column(slot, resource)

      assert column.label == "User > Profile > Avatar"
    end
  end

  describe "type inference without Ash resource" do
    test "returns default config when no resource provided" do
      slot = %{field: "test_field"}
      resource = nil

      column = Column.parse_column(slot, resource)

      assert column.sortable == false
      assert column.filterable == false
      assert column.filter_type == :text
      assert column.filter_options == []
    end

    test "returns default config for non-Ash resource" do
      slot = %{field: "test_field"}
      resource = %{not: "an_ash_resource"}

      column = Column.parse_column(slot, resource)

      assert column.sortable == false
      assert column.filterable == false
      assert column.filter_type == :text
      assert column.filter_options == []
    end
  end

  describe "humanization" do
    test "humanizes snake_case fields" do
      slot = %{field: "user_name"}
      resource = nil

      column = Column.parse_column(slot, resource)

      assert column.label == "User Name"
    end

    test "humanizes dot notation fields" do
      slot = %{field: "user.profile.first_name"}
      resource = nil

      column = Column.parse_column(slot, resource)

      assert column.label == "User > Profile > First Name"
    end

    test "capitalizes single words" do
      slot = %{field: "email"}
      resource = nil

      column = Column.parse_column(slot, resource)

      assert column.label == "Email"
    end
  end

  describe "edge cases" do
    test "handles nil slot gracefully" do
      # This shouldn't happen in practice, but test robustness
      assert_raise(BadMapError, fn ->
        Column.parse_column(nil, nil)
      end)
    end

    test "handles empty slot creates action column" do
      slot = %{}
      resource = nil

      column = Column.parse_column(slot, resource)

      assert column.field == nil
      assert column.label == ""
      assert column.sortable == false
      assert column.filterable == false
    end

    test "handles integer fields" do
      slot = %{field: 123}
      resource = nil

      column = Column.parse_column(slot, resource)

      assert column.field == 123
      assert column.label == "123"
    end

    test "handles atom fields" do
      slot = %{field: :test_field}
      resource = nil

      column = Column.parse_column(slot, resource)

      assert column.field == :test_field
      assert column.label == "Test Field"
    end
  end

  describe "complex configurations" do
    test "handles full configuration with all options" do
      slot = %{
        field: "status",
        label: "Status",
        sortable: true,
        filterable: true,
        filter_type: :select,
        filter_options: [options: [{"Active", :active}, {"Inactive", :inactive}]],
        class: "w-32 text-center",
        filter_fn: &custom_filter/2,
        search_fn: &custom_search/2,
        searchable: true,
        options: [custom: "option"]
      }

      resource = nil

      column = Column.parse_column(slot, resource)

      assert column.field == "status"
      assert column.label == "Status"
      assert column.sortable == true
      assert column.filterable == true
      assert column.filter_type == :select
      assert column.filter_options == [options: [{"Active", :active}, {"Inactive", :inactive}]]
      assert column.class == "w-32 text-center"
      assert is_function(column.filter_fn)
      assert is_function(column.search_fn)
      assert column.searchable == true
      assert column.options == [custom: "option"]
      assert column.slot == slot
    end
  end

  describe "filterable attribute behavior" do
    test "columns default to non-filterable when filterable not specified" do
      slots = [
        %{field: "id", label: "ID"},
        %{field: "name", label: "Name"},
        %{field: "email", label: "Email", filterable: true}
      ]

      resource = nil

      columns = Column.parse_columns(slots, resource)

      # Only the email column should be filterable
      [id_col, name_col, email_col] = columns

      assert id_col.filterable == false
      assert name_col.filterable == false
      assert email_col.filterable == true
    end

    test "filterable: false is explicitly respected" do
      slots = [
        %{field: "id", label: "ID", filterable: false},
        %{field: "secret", label: "Secret", filterable: false, sortable: false}
      ]

      resource = nil

      columns = Column.parse_columns(slots, resource)

      [id_col, secret_col] = columns

      assert id_col.filterable == false
      assert id_col.sortable == false

      assert secret_col.filterable == false
      # explicitly set to false
      assert secret_col.sortable == false
    end

    test "mixed filterable configuration in single table" do
      slots = [
        # not filterable (default)
        %{field: "id", label: "ID"},
        # filterable
        %{field: "name", label: "Name", filterable: true},
        # explicitly not filterable
        %{field: "email", label: "Email", filterable: false},
        # filterable
        %{field: "status", label: "Status", filterable: true}
      ]

      resource = nil

      columns = Column.parse_columns(slots, resource)

      filterable_columns = Enum.filter(columns, & &1.filterable)
      non_filterable_columns = Enum.reject(columns, & &1.filterable)

      # Should have exactly 2 filterable columns
      assert length(filterable_columns) == 2
      assert Enum.map(filterable_columns, & &1.field) == ["name", "status"]

      # Should have exactly 2 non-filterable columns
      assert length(non_filterable_columns) == 2
      assert Enum.map(non_filterable_columns, & &1.field) == ["id", "email"]
    end
  end

  # Mock functions for testing

  defp custom_filter(_query, _value), do: nil
  defp custom_search(_query, _value), do: nil
end
