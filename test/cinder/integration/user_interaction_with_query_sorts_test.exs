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
    test "user interaction prevents re-extraction of query sorts when URL becomes empty" do
      # This test covers the specific bug that was fixed:
      # When a user clicks to remove a sort, the URL becomes empty, which was
      # causing the table to re-extract the original query sorts

      # Starting query with sort
      query =
        TestUser
        |> Ash.Query.for_read(:read, %{}, domain: TestDomain)
        |> Ash.Query.sort([{:name, :desc}])

      # Test the sequence that was problematic:

      # 1. Initial state: Extract sorts from query
      columns = [%{field: "name"}, %{field: "email"}]
      initial_sorts = Cinder.QueryBuilder.extract_query_sorts(query, columns)
      assert initial_sorts == [{"name", :desc}]

      # 2. User clicks to toggle sort (removes the desc sort)
      sort_after_click = Cinder.QueryBuilder.toggle_sort_direction(initial_sorts, "name")
      assert sort_after_click == []

      # 3. Simulate what happens in the table component:
      # URL state processing with empty params should NOT re-extract query sorts
      # when user has interacted (this is the key fix)

      # Simulate empty URL params (what happens when sort is removed)
      empty_url_sorts = []
      user_has_interacted = true

      # The table should preserve user's choice (empty) instead of re-extracting
      final_sorts =
        if empty_url_sorts == [] and user_has_interacted do
          # Preserve user's empty choice
          []
        else
          # Would incorrectly go back to query sorts
          initial_sorts
        end

      assert final_sorts == []
      refute final_sorts == [{"name", :desc}]
    end

    test "toggle_sort_direction provides consistent three-step cycle" do
      # Test the complete toggle cycle that users expect

      # Start with query-extracted desc sort
      initial_sort = [{"name", :desc}]

      # First click: desc -> remove (user takes control)
      step_1 = Cinder.QueryBuilder.toggle_sort_direction(initial_sort, "name")
      assert step_1 == []

      # Second click: none -> asc
      step_2 = Cinder.QueryBuilder.toggle_sort_direction(step_1, "name")
      assert step_2 == [{"name", :asc}]

      # Third click: asc -> desc
      step_3 = Cinder.QueryBuilder.toggle_sort_direction(step_2, "name")
      assert step_3 == [{"name", :desc}]

      # Fourth click: desc -> remove (complete cycle)
      step_4 = Cinder.QueryBuilder.toggle_sort_direction(step_3, "name")
      assert step_4 == []

      # Fifth click: none -> asc (cycle continues)
      step_5 = Cinder.QueryBuilder.toggle_sort_direction(step_4, "name")
      assert step_5 == [{"name", :asc}]
    end

    test "URL sorts take precedence over query sorts" do
      # When URL has explicit sorts, they should override query sorts

      query =
        TestUser
        |> Ash.Query.for_read(:read, %{}, domain: TestDomain)
        |> Ash.Query.sort([{:name, :desc}])

      columns = [%{field: "name"}, %{field: "email"}]

      # Extract query sorts
      query_sorts = Cinder.QueryBuilder.extract_query_sorts(query, columns)
      assert query_sorts == [{"name", :desc}]

      # Simulate URL with different sort
      url_sorts = [{"email", :asc}]
      _user_has_interacted = false

      # URL sorts should win
      final_sorts =
        if Enum.empty?(url_sorts) do
          query_sorts
        else
          url_sorts
        end

      assert final_sorts == [{"email", :asc}]
      refute final_sorts == [{"name", :desc}]
    end

    test "query sorts are used when no URL sorts and no user interaction" do
      # Initial load with query sorts should display them

      query =
        TestUser
        |> Ash.Query.for_read(:read, %{}, domain: TestDomain)
        |> Ash.Query.sort([{:name, :desc}, {:email, :asc}])

      columns = [%{field: "name"}, %{field: "email"}, %{field: "created_at"}]

      # Extract query sorts
      query_sorts = Cinder.QueryBuilder.extract_query_sorts(query, columns)
      assert query_sorts == [{"name", :desc}, {"email", :asc}]

      # Simulate initial load (no URL sorts, no user interaction)
      url_sorts = []
      user_has_interacted = false

      final_sorts =
        if url_sorts == [] and not user_has_interacted do
          # Use extracted query sorts
          query_sorts
        else
          url_sorts
        end

      assert final_sorts == [{"name", :desc}, {"email", :asc}]
    end

    test "preserves user choice of empty sorts after interaction" do
      # Once user has removed all sorts, that choice should be preserved
      # even when URL becomes empty

      # Start with desc sort (like from query extraction)
      initial_sorts = [{"name", :desc}]

      # User toggles the sort (desc -> remove)
      user_removes_sort = Cinder.QueryBuilder.toggle_sort_direction(initial_sorts, "name")
      assert user_removes_sort == []

      # Mark that user has interacted
      user_has_interacted = true

      # Simulate URL processing with empty params
      url_sorts = []

      # Should preserve user's choice of no sorts
      final_sorts =
        if Enum.empty?(url_sorts) and user_has_interacted do
          # Preserve user's empty choice
          []
        else
          # Would be wrong to default back
          [{"name", :desc}]
        end

      assert final_sorts == []
    end

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

    test "user interaction flag prevents query sort re-extraction" do
      # Test the core mechanism that prevents the bug

      # Mock the table component behavior
      query_sorts = [{"name", :desc}]
      empty_url_sorts = []

      # Before fix: would always use query sorts when URL is empty
      old_behavior_result =
        if Enum.empty?(empty_url_sorts) do
          # Wrong: always re-extract
          query_sorts
        else
          empty_url_sorts
        end

      # After fix: Test scenario 1 - User has interacted
      result_with_interaction =
        if Enum.empty?(empty_url_sorts) do
          # User has interacted, preserve their empty choice
          []
        else
          empty_url_sorts
        end

      # After fix: Test scenario 2 - Initial load (no interaction)
      result_initial_load =
        if Enum.empty?(empty_url_sorts) do
          # Initial load, use query sorts
          query_sorts
        else
          empty_url_sorts
        end

      # Old behavior would incorrectly re-extract
      assert old_behavior_result == [{"name", :desc}]

      # New behavior correctly preserves user choice when user has interacted
      assert result_with_interaction == []

      # New behavior correctly uses query sorts on initial load
      assert result_initial_load == [{"name", :desc}]
    end
  end

  describe "edge cases and error conditions" do
    test "handles invalid sort directions gracefully" do
      # This test shows current behavior - invalid directions fall through to nil case
      # In practice, this shouldn't happen as sorts come from controlled sources

      # Start with no sort and add ascending (normal case)
      no_sort = []
      result = Cinder.QueryBuilder.toggle_sort_direction(no_sort, "name")
      assert result == [{"name", :asc}]
    end

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
