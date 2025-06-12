defmodule Cinder.ColumnTest do
  use ExUnit.Case, async: true

  alias Cinder.Column

  describe "parse_column/2" do
    test "parses basic column with defaults" do
      slot = %{key: "name", label: "Name"}
      resource = nil

      column = Column.parse_column(slot, resource)

      assert column.key == "name"
      assert column.label == "Name"
      assert column.sortable == true
      assert column.filterable == false
      assert column.filter_type == :text
      assert column.class == ""
      assert column.slot == slot
    end

    test "respects filterable attribute when false" do
      slot = %{key: "name", label: "Name", filterable: false}
      resource = nil

      column = Column.parse_column(slot, resource)

      assert column.filterable == false
      assert column.filter_type == :text
    end

    test "respects filterable attribute when true" do
      slot = %{key: "name", label: "Name", filterable: true}
      resource = nil

      column = Column.parse_column(slot, resource)

      assert column.filterable == true
      assert column.filter_type == :text
    end

    test "preserves slot configuration over defaults" do
      slot = %{
        key: "email",
        label: "Email Address",
        sortable: false,
        filterable: true,
        filter_type: :text,
        class: "w-1/4"
      }

      resource = nil

      column = Column.parse_column(slot, resource)

      assert column.key == "email"
      assert column.label == "Email Address"
      assert column.sortable == false
      assert column.filterable == true
      assert column.filter_type == :text
      assert column.class == "w-1/4"
    end

    test "generates label from key when not provided" do
      slot = %{key: "user_name"}
      resource = nil

      column = Column.parse_column(slot, resource)

      assert column.label == "User Name"
    end

    test "handles relationship keys with dot notation" do
      slot = %{key: "user.name", label: "User Name"}
      resource = nil

      column = Column.parse_column(slot, resource)

      assert column.key == "user.name"
      assert column.relationship == "user"
      assert column.display_field == "name"
      assert column.label == "User Name"
    end
  end

  describe "parse_columns/2" do
    test "parses multiple columns" do
      slots = [
        %{key: "id", label: "ID"},
        %{key: "name", label: "Name"},
        %{key: "email", label: "Email"}
      ]

      resource = nil

      columns = Column.parse_columns(slots, resource)

      assert length(columns) == 3
      assert Enum.map(columns, & &1.key) == ["id", "name", "email"]
      assert Enum.map(columns, & &1.label) == ["ID", "Name", "Email"]
    end
  end

  describe "validate/1" do
    test "validates valid column" do
      column = %Column{
        key: "name",
        label: "Name",
        sortable: true,
        filterable: true,
        filter_type: :text,
        filter_options: []
      }

      assert {:ok, ^column} = Column.validate(column)
    end

    test "rejects column with empty key" do
      column = %Column{
        key: "",
        label: "Name",
        filter_type: :text
      }

      assert {:error, errors} = Column.validate(column)
      assert "Key cannot be empty" in errors
    end

    test "rejects column with empty label" do
      column = %Column{
        key: "name",
        label: "",
        filter_type: :text
      }

      assert {:error, errors} = Column.validate(column)
      assert "Label cannot be empty" in errors
    end

    test "rejects column with invalid filter type" do
      column = %Column{
        key: "name",
        label: "Name",
        filter_type: :invalid_type
      }

      assert {:error, errors} = Column.validate(column)
      assert "Invalid filter type: invalid_type" in errors
    end

    test "returns multiple errors" do
      column = %Column{
        key: "",
        label: "",
        filter_type: :invalid
      }

      assert {:error, errors} = Column.validate(column)
      assert "Key cannot be empty" in errors
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
      slot = %{key: "user.email"}
      resource = nil

      column = Column.parse_column(slot, resource)

      assert column.key == "user.email"
      assert column.relationship == "user"
      assert column.display_field == "email"
    end

    test "handles non-relationship keys" do
      slot = %{key: "simple_field"}
      resource = nil

      column = Column.parse_column(slot, resource)

      assert column.key == "simple_field"
      assert column.relationship == nil
      assert column.display_field == nil
    end

    test "generates proper label for relationship fields" do
      slot = %{key: "user.profile.avatar"}
      resource = nil

      column = Column.parse_column(slot, resource)

      assert column.label == "User > Profile > Avatar"
    end
  end

  describe "type inference without Ash resource" do
    test "returns default config when no resource provided" do
      slot = %{key: "test_field"}
      resource = nil

      column = Column.parse_column(slot, resource)

      assert column.sortable == true
      assert column.filterable == false
      assert column.filter_type == :text
      assert column.filter_options == []
    end

    test "returns default config for non-Ash resource" do
      slot = %{key: "test_field"}
      resource = %{not: "an_ash_resource"}

      column = Column.parse_column(slot, resource)

      assert column.sortable == true
      assert column.filterable == false
      assert column.filter_type == :text
      assert column.filter_options == []
    end
  end

  describe "humanization" do
    test "humanizes snake_case keys" do
      slot = %{key: "user_name"}
      resource = nil

      column = Column.parse_column(slot, resource)

      assert column.label == "User Name"
    end

    test "humanizes dot notation keys" do
      slot = %{key: "user.profile.first_name"}
      resource = nil

      column = Column.parse_column(slot, resource)

      assert column.label == "User > Profile > First Name"
    end

    test "capitalizes single words" do
      slot = %{key: "email"}
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

    test "handles empty slot" do
      slot = %{}
      resource = nil

      column = Column.parse_column(slot, resource)

      # Should have reasonable defaults
      assert column.key == nil
      assert column.sortable == true
      assert column.filterable == false
    end

    test "handles integer keys" do
      slot = %{key: 123}
      resource = nil

      column = Column.parse_column(slot, resource)

      assert column.key == 123
      assert column.label == "123"
    end

    test "handles atom keys" do
      slot = %{key: :test_field}
      resource = nil

      column = Column.parse_column(slot, resource)

      assert column.key == :test_field
      assert column.label == "Test Field"
    end
  end

  describe "complex configurations" do
    test "handles full configuration with all options" do
      slot = %{
        key: "status",
        label: "Status",
        sortable: true,
        filterable: true,
        filter_type: :select,
        filter_options: [options: [{"Active", :active}, {"Inactive", :inactive}]],
        class: "w-32 text-center",
        sort_fn: &custom_sort/2,
        filter_fn: &custom_filter/2,
        search_fn: &custom_search/2,
        searchable: true,
        options: [custom: "option"]
      }

      resource = nil

      column = Column.parse_column(slot, resource)

      assert column.key == "status"
      assert column.label == "Status"
      assert column.sortable == true
      assert column.filterable == true
      assert column.filter_type == :select
      assert column.filter_options == [options: [{"Active", :active}, {"Inactive", :inactive}]]
      assert column.class == "w-32 text-center"
      assert is_function(column.sort_fn)
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
        %{key: "id", label: "ID"},
        %{key: "name", label: "Name"},
        %{key: "email", label: "Email", filterable: true}
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
        %{key: "id", label: "ID", filterable: false},
        %{key: "secret", label: "Secret", filterable: false, sortable: false}
      ]

      resource = nil

      columns = Column.parse_columns(slots, resource)

      [id_col, secret_col] = columns

      assert id_col.filterable == false
      # sortable defaults to true
      assert id_col.sortable == true

      assert secret_col.filterable == false
      # explicitly set to false
      assert secret_col.sortable == false
    end

    test "mixed filterable configuration in single table" do
      slots = [
        # not filterable (default)
        %{key: "id", label: "ID"},
        # filterable
        %{key: "name", label: "Name", filterable: true},
        # explicitly not filterable
        %{key: "email", label: "Email", filterable: false},
        # filterable
        %{key: "status", label: "Status", filterable: true}
      ]

      resource = nil

      columns = Column.parse_columns(slots, resource)

      filterable_columns = Enum.filter(columns, & &1.filterable)
      non_filterable_columns = Enum.reject(columns, & &1.filterable)

      # Should have exactly 2 filterable columns
      assert length(filterable_columns) == 2
      assert Enum.map(filterable_columns, & &1.key) == ["name", "status"]

      # Should have exactly 2 non-filterable columns
      assert length(non_filterable_columns) == 2
      assert Enum.map(non_filterable_columns, & &1.key) == ["id", "email"]
    end
  end

  # Mock functions for testing
  defp custom_sort(_a, _b), do: :eq
  defp custom_filter(_query, _value), do: nil
  defp custom_search(_query, _value), do: nil
end
