defmodule Cinder.ActionColumnDemoTest do
  use ExUnit.Case, async: true

  # This test file demonstrates the new action column functionality
  # It shows how users can now create tables with action columns using the existing :col slot

  alias Cinder.Table

  # Mock Ash resource for testing
  defmodule DemoUser do
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
      attribute(:role, :string)
      attribute(:active, :boolean)
      attribute(:created_at, :utc_datetime)
    end

    actions do
      defaults([:create, :read, :update, :destroy])
    end
  end

  describe "action column API demonstration" do
    test "basic action column usage" do
      # This demonstrates the simplest action column usage
      # Before this feature, you would need a field attribute
      # Now, you can omit the field for action columns

      columns = [
        # Regular data columns - require field attribute
        %{field: "name", filter: true, sort: true, label: "Name"},
        %{field: "email", filter: true, label: "Email"},
        %{field: "role", filter: :select, label: "Role"},

        # Action column - no field required!
        %{
          label: "Actions",
          class: "text-right w-32",
          inner_block: fn user ->
            "<a href='/users/#{user.id}'>Edit</a> | <a href='/users/#{user.id}' method='delete'>Delete</a>"
          end
        }
      ]

      processed = Table.process_columns(columns, DemoUser)

      # Verify we have all columns
      assert length(processed) == 4

      # Verify data columns work as before
      name_col = Enum.at(processed, 0)
      assert name_col.field == "name"
      assert name_col.filterable == true
      assert name_col.sortable == true

      # Verify action column
      action_col = Enum.at(processed, 3)
      assert action_col.field == nil
      assert action_col.label == "Actions"
      assert action_col.class == "text-right w-32"
      assert action_col.filterable == false
      assert action_col.sortable == false
    end

    test "multiple action columns example" do
      # This shows how you can have multiple action columns
      # Useful when you want separate columns for different types of actions

      columns = [
        %{field: "name", filter: true, sort: true, label: "Name"},
        %{field: "email", filter: true, label: "Email"},

        # Separate action columns
        %{
          label: "Edit",
          class: "w-20",
          inner_block: fn user -> "<a href='/users/#{user.id}/edit'>Edit</a>" end
        },
        %{
          label: "Delete",
          class: "w-20",
          inner_block: fn user -> "<button onclick='deleteUser(#{user.id})'>Delete</button>" end
        },
        %{
          label: "More",
          class: "w-16",
          inner_block: fn _user -> "<div class='dropdown'>...</div>" end
        }
      ]

      processed = Table.process_columns(columns, DemoUser)

      assert length(processed) == 5

      # All action columns should have no field
      action_cols = Enum.slice(processed, 2, 3)
      assert Enum.all?(action_cols, fn col -> col.field == nil end)
      assert Enum.all?(action_cols, fn col -> col.filterable == false end)
      assert Enum.all?(action_cols, fn col -> col.sortable == false end)
    end

    test "mixed positioning of action columns" do
      # This shows that action columns can be positioned anywhere,
      # not just at the end of the table

      columns = [
        %{field: "name", filter: true, sort: true, label: "Name"},

        # Action column in the middle
        %{
          label: "Quick Actions",
          class: "w-24",
          inner_block: fn _user -> "<button>👁️</button> <button>✏️</button>" end
        },
        %{field: "email", filter: true, label: "Email"},
        %{field: "role", filter: :select, label: "Role"},

        # Another action column at the end
        %{
          label: "Admin",
          class: "w-20",
          inner_block: fn user ->
            if user.role == "admin", do: "<button>Manage</button>", else: ""
          end
        }
      ]

      processed = Table.process_columns(columns, DemoUser)

      assert length(processed) == 5

      # Verify positioning
      # data
      assert Enum.at(processed, 0).field == "name"
      # action
      assert Enum.at(processed, 1).field == nil
      # data
      assert Enum.at(processed, 2).field == "email"
      # data
      assert Enum.at(processed, 3).field == "role"
      # action
      assert Enum.at(processed, 4).field == nil
    end

    test "validation prevents common mistakes" do
      # This shows how the validation catches common user errors

      # Mistake 1: Trying to filter an action column
      invalid_filter = %{
        label: "Actions",
        # This should cause an error
        filter: true
      }

      assert_raise ArgumentError,
                   ~r/column with filter attribute\(s\) requires a 'field' attribute/,
                   fn ->
                     Table.process_columns([invalid_filter], DemoUser)
                   end

      # Mistake 2: Trying to sort an action column
      invalid_sort = %{
        label: "Actions",
        # This should cause an error
        sort: true
      }

      assert_raise ArgumentError,
                   ~r/column with sort attribute\(s\) requires a 'field' attribute/,
                   fn ->
                     Table.process_columns([invalid_sort], DemoUser)
                   end
    end

    test "helpful error messages guide users" do
      # This demonstrates that error messages are helpful and actionable

      invalid_column = %{
        label: "User Actions",
        filter: :select,
        sort: true
      }

      try do
        Table.process_columns([invalid_column], DemoUser)
      rescue
        error in ArgumentError ->
          message = Exception.message(error)

          # Error message should mention both problematic attributes
          assert String.contains?(message, "filter")
          assert String.contains?(message, "sort")

          # Error message should provide solutions
          assert String.contains?(message, "Add a field:")
          assert String.contains?(message, "Remove")
          assert String.contains?(message, "action columns")
      end
    end

    test "backward compatibility is maintained" do
      # This verifies that existing tables continue to work exactly as before

      # Old-style table definition (every column has a field)
      old_style_columns = [
        %{field: "name", filter: true, sort: true, label: "Name"},
        %{field: "email", filter: true, label: "Email Address"},
        %{field: "active", filter: :boolean, label: "Status"},
        %{field: "created_at", sort: true, label: "Created"}
      ]

      processed = Table.process_columns(old_style_columns, DemoUser)

      # Should work exactly as before
      assert length(processed) == 4
      assert Enum.all?(processed, fn col -> col.field != nil end)

      # First column should be fully configured
      name_col = Enum.at(processed, 0)
      assert name_col.field == "name"
      assert name_col.label == "Name"
      assert name_col.filterable == true
      assert name_col.sortable == true
    end

    test "realistic table configuration example" do
      # This shows a realistic table that might be used in a real application

      columns = [
        # User info columns
        %{field: "name", filter: true, sort: true, label: "Full Name", class: "font-medium"},
        %{field: "email", filter: true, label: "Email", class: "text-gray-600"},
        %{field: "role", filter: :select, sort: true, label: "Role", class: "capitalize"},
        %{field: "active", filter: :boolean, label: "Status", class: "text-center"},
        %{field: "created_at", sort: true, label: "Joined", class: "text-sm text-gray-500"},

        # Action column with multiple actions
        %{
          label: "Actions",
          class: "text-right pr-4 w-32",
          inner_block: fn user ->
            """
            <div class="flex space-x-2">
              <a href="/users/#{user.id}" class="text-blue-600 hover:text-blue-800">View</a>
              <a href="/users/#{user.id}/edit" class="text-green-600 hover:text-green-800">Edit</a>
              <button onclick="deleteUser('#{user.id}')" class="text-red-600 hover:text-red-800">Delete</button>
            </div>
            """
          end
        }
      ]

      processed = Table.process_columns(columns, DemoUser)

      assert length(processed) == 6

      # Verify data columns are filterable/sortable as expected
      filterable_count = Enum.count(processed, & &1.filterable)
      sortable_count = Enum.count(processed, & &1.sortable)

      # name, email, role, active
      assert filterable_count == 4
      # name, role, created_at
      assert sortable_count == 3

      # Verify action column
      action_col = List.last(processed)
      assert action_col.field == nil
      assert action_col.label == "Actions"
      assert action_col.class == "text-right pr-4 w-32"
      assert action_col.filterable == false
      assert action_col.sortable == false
    end
  end
end
