defmodule Cinder.Integration.UserInteractionWithQuerySortsTest do
  use ExUnit.Case, async: true

  # Mock Ash resources for testing
  defmodule TestUser do
    use Ash.Resource,
      domain: nil,
      data_layer: Ash.DataLayer.Ets,
      validate_domain_inclusion?: false

    ets do
      private?(true)
    end

    attributes do
      uuid_primary_key(:id)
      attribute(:name, :string, public?: true)
      attribute(:email, :string, public?: true)
      attribute(:created_at, :utc_datetime, public?: true)
    end

    actions do
      defaults([:read, :update, :destroy])

      create :create do
        accept([:name, :email])
      end
    end
  end

  defmodule TestDomain do
    use Ash.Domain, validate_config_inclusion?: false

    resources do
      resource(TestUser)
    end
  end

  describe "user interaction with query sorts and URL state" do
    test "multiple column sorting works correctly with user interaction" do
      # Test that the interaction logic works with multiple sorted columns

      initial_sorts = [{"name", :desc}, {"email", :asc}]

      # User toggles name column: desc -> remove
      after_name_toggle = Cinder.QueryBuilder.toggle_sort_direction(initial_sorts, "name")
      assert after_name_toggle == [{"email", :asc}]

      # User toggles email column: asc -> desc
      after_email_toggle = Cinder.QueryBuilder.toggle_sort_direction(after_name_toggle, "email")
      assert after_email_toggle == [{"email", :desc}]

      # User adds sort on name: none -> asc (with email still desc)
      after_add_name = Cinder.QueryBuilder.toggle_sort_direction(after_email_toggle, "name")
      assert after_add_name == [{"name", :asc}, {"email", :desc}]
    end

    test "atom field names work correctly in user interaction flow" do
      # Test the fix for atom vs string field names in columns

      query =
        TestUser
        |> Ash.Query.for_read(:read, %{}, domain: TestDomain)
        |> Ash.Query.sort([{:name, :desc}])

      # Columns with atom field names (as they appear in real table slots)
      columns = [%{field: :name}, %{field: :email}]

      # Should correctly extract sorts despite atom field names
      extracted_sorts = Cinder.QueryBuilder.extract_query_sorts(query, columns)
      assert extracted_sorts == [{"name", :desc}]

      # Toggle should work normally
      toggled_sorts = Cinder.QueryBuilder.toggle_sort_direction(extracted_sorts, "name")
      assert toggled_sorts == []
    end
  end

  describe "edge cases and error conditions" do
    test "handles empty column list gracefully" do
      # When no columns are defined, should handle gracefully

      query =
        TestUser
        |> Ash.Query.for_read(:read, %{}, domain: TestDomain)
        |> Ash.Query.sort([{:name, :desc}])

      empty_columns = []

      # Should return empty list when no columns to match against
      result = Cinder.QueryBuilder.extract_query_sorts(query, empty_columns)
      # No filtering when no columns provided
      assert result == [{"name", :desc}]
    end

    test "handles mixed field name types in columns" do
      # Test columns with both atom and string field names

      query =
        TestUser
        |> Ash.Query.for_read(:read, %{}, domain: TestDomain)
        |> Ash.Query.sort([{:name, :desc}, {:email, :asc}])

      mixed_columns = [
        # atom
        %{field: :name},
        # string
        %{field: "email"},
        # atom
        %{field: :created_at}
      ]

      result = Cinder.QueryBuilder.extract_query_sorts(query, mixed_columns)
      assert result == [{"name", :desc}, {"email", :asc}]
    end
  end
end
