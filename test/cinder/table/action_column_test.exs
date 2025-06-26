defmodule Cinder.ActionColumnTest do
  use ExUnit.Case, async: true

  alias Cinder.Table

  # Mock Ash resource for testing
  defmodule TestUser do
    use Ash.Resource,
      domain: nil,
      data_layer: Ash.DataLayer.Ets

    ets do
      private?(true)
    end

    attributes do
      uuid_primary_key(:id)
      attribute(:name, :string)
      attribute(:email, :string)
      attribute(:active, :boolean)
    end

    actions do
      defaults([:create, :read, :update, :destroy])
    end
  end

  describe "action column support" do
    test "action column without field is processed correctly" do
      action_column = %{
        label: "Actions",
        inner_block: fn _item -> "Edit | Delete" end
      }

      [column] = Table.process_columns([action_column], TestUser)

      assert column.field == nil
      assert column.label == "Actions"
      assert column.filterable == false
      assert column.sortable == false
      assert column.__slot__ == :col
    end

    test "action column with empty field is processed correctly" do
      action_column = %{
        field: "",
        label: "Actions",
        inner_block: fn _item -> "Edit | Delete" end
      }

      [column] = Table.process_columns([action_column], TestUser)

      assert column.field == ""
      assert column.label == "Actions"
      assert column.filterable == false
      assert column.sortable == false
    end

    test "action column with nil field is processed correctly" do
      action_column = %{
        field: nil,
        label: "Actions",
        inner_block: fn _item -> "Edit | Delete" end
      }

      [column] = Table.process_columns([action_column], TestUser)

      assert column.field == nil
      assert column.label == "Actions"
      assert column.filterable == false
      assert column.sortable == false
    end

    test "action column with custom class is processed correctly" do
      action_column = %{
        label: "Actions",
        class: "text-right w-32",
        inner_block: fn _item -> "Edit | Delete" end
      }

      [column] = Table.process_columns([action_column], TestUser)

      assert column.field == nil
      assert column.label == "Actions"
      assert column.class == "text-right w-32"
      assert column.filterable == false
      assert column.sortable == false
    end

    test "multiple action columns are supported" do
      columns = [
        %{field: "name", filter: true, sort: true, inner_block: fn item -> item.name end},
        %{label: "Edit", inner_block: fn _item -> "Edit" end},
        %{label: "Delete", inner_block: fn _item -> "Delete" end}
      ]

      processed = Table.process_columns(columns, TestUser)

      assert length(processed) == 3

      # Data column
      data_column = Enum.at(processed, 0)
      assert data_column.field == "name"
      assert data_column.filterable == true
      assert data_column.sortable == true

      # First action column
      edit_column = Enum.at(processed, 1)
      assert edit_column.field == nil
      assert edit_column.label == "Edit"
      assert edit_column.filterable == false
      assert edit_column.sortable == false

      # Second action column
      delete_column = Enum.at(processed, 2)
      assert delete_column.field == nil
      assert delete_column.label == "Delete"
      assert delete_column.filterable == false
      assert delete_column.sortable == false
    end

    test "mixed data and action columns maintain correct order" do
      columns = [
        %{field: "name", filter: true, inner_block: fn item -> item.name end},
        %{label: "Actions", inner_block: fn _item -> "Edit" end},
        %{field: "email", filter: true, inner_block: fn item -> item.email end},
        %{label: "More Actions", inner_block: fn _item -> "Delete" end}
      ]

      processed = Table.process_columns(columns, TestUser)

      assert length(processed) == 4
      assert Enum.at(processed, 0).field == "name"
      assert Enum.at(processed, 1).field == nil
      assert Enum.at(processed, 1).label == "Actions"
      assert Enum.at(processed, 2).field == "email"
      assert Enum.at(processed, 3).field == nil
      assert Enum.at(processed, 3).label == "More Actions"
    end
  end

  describe "action column validation" do
    test "action column with filter raises validation error" do
      invalid_column = %{
        label: "Actions",
        filter: true,
        inner_block: fn _item -> "Edit" end
      }

      assert_raise ArgumentError,
                   ~r/column with filter attribute\(s\) requires a 'field' attribute/,
                   fn ->
                     Table.process_columns([invalid_column], TestUser)
                   end
    end

    test "action column with sort raises validation error" do
      invalid_column = %{
        label: "Actions",
        sort: true,
        inner_block: fn _item -> "Edit" end
      }

      assert_raise ArgumentError,
                   ~r/column with sort attribute\(s\) requires a 'field' attribute/,
                   fn ->
                     Table.process_columns([invalid_column], TestUser)
                   end
    end

    test "action column with both filter and sort raises validation error" do
      invalid_column = %{
        label: "Actions",
        filter: true,
        sort: true,
        inner_block: fn _item -> "Edit" end
      }

      assert_raise ArgumentError,
                   ~r/column with filter sort attribute\(s\) requires a 'field' attribute/,
                   fn ->
                     Table.process_columns([invalid_column], TestUser)
                   end
    end

    test "error message is helpful and actionable" do
      invalid_column = %{
        label: "Actions",
        filter: :select,
        inner_block: fn _item -> "Edit" end
      }

      try do
        Table.process_columns([invalid_column], TestUser)
      rescue
        error in ArgumentError ->
          message = Exception.message(error)
          assert String.contains?(message, "requires a 'field' attribute")
          assert String.contains?(message, "Add a field: <:col field=\"field_name\" filter>")
          assert String.contains?(message, "Remove filter attribute(s) for action columns")
      end
    end
  end

  describe "table rendering with action columns" do
    test "table component accepts action columns without field" do
      # This test verifies that the full table component works with action columns
      # We can't easily test the full LiveView rendering without a more complex setup,
      # but we can test that the component processes the slots correctly

      assigns = %{
        col: [
          %{field: "name", filter: true, sort: true},
          %{label: "Actions"}
        ]
      }

      processed_columns = Table.process_columns(assigns.col, TestUser)

      # Should have both columns processed without error
      assert length(processed_columns) == 2
      assert Enum.at(processed_columns, 0).field == "name"
      assert Enum.at(processed_columns, 1).field == nil
      assert Enum.at(processed_columns, 1).label == "Actions"
    end

    test "action columns don't affect filter display logic" do
      # Action columns should not trigger filter display since they're not filterable
      action_only_columns = [
        %{label: "Edit"},
        %{label: "Delete"}
      ]

      processed = Table.process_columns(action_only_columns, TestUser)

      # Simulate the determine_show_filters logic
      any_filterable = Enum.any?(processed, & &1.filterable)
      assert any_filterable == false

      # Mix with filterable column
      mixed_columns = [
        %{field: "name", filter: true},
        %{label: "Actions"}
      ]

      processed_mixed = Table.process_columns(mixed_columns, TestUser)
      any_filterable_mixed = Enum.any?(processed_mixed, & &1.filterable)
      assert any_filterable_mixed == true
    end
  end

  describe "backward compatibility" do
    test "existing data columns continue to work unchanged" do
      data_column = %{
        field: "name",
        filter: true,
        sort: true,
        label: "Name",
        class: "w-32"
      }

      [column] = Table.process_columns([data_column], TestUser)

      assert column.field == "name"
      assert column.label == "Name"
      assert column.class == "w-32"
      assert column.filterable == true
      assert column.sortable == true
    end

    test "tables with only data columns work as before" do
      data_columns = [
        %{field: "name", filter: true, sort: true},
        %{field: "email", filter: true},
        %{field: "active", filter: :boolean}
      ]

      processed = Table.process_columns(data_columns, TestUser)

      assert length(processed) == 3
      assert Enum.all?(processed, fn col -> col.field != nil end)
      assert Enum.at(processed, 0).filterable == true
      assert Enum.at(processed, 1).filterable == true
      assert Enum.at(processed, 2).filterable == true
    end
  end

  describe "edge cases" do
    test "empty label action column works" do
      action_column = %{
        inner_block: fn _item -> "..." end
      }

      [column] = Table.process_columns([action_column], TestUser)

      assert column.field == nil
      assert column.label == ""
      assert column.filterable == false
      assert column.sortable == false
    end

    test "action column without inner_block gets default" do
      action_column = %{
        label: "Actions"
      }

      [column] = Table.process_columns([action_column], TestUser)

      assert column.field == nil
      assert column.label == "Actions"
      assert is_function(column.inner_block)
      # Default inner block should return nil for action columns
      assert column.inner_block.(%{}) == nil
    end

    test "false filter attribute doesn't require field" do
      # filter: false should not require a field (this is for action columns)
      action_column = %{
        label: "Actions",
        filter: false
      }

      [column] = Table.process_columns([action_column], TestUser)

      assert column.field == nil
      assert column.label == "Actions"
      assert column.filterable == false
    end

    test "nil sort attribute doesn't require field" do
      # sort: nil should not require a field
      action_column = %{
        label: "Actions",
        sort: nil
      }

      [column] = Table.process_columns([action_column], TestUser)

      assert column.field == nil
      assert column.label == "Actions"
      assert column.sortable == false
    end
  end
end
