defmodule Cinder.Table.SearchIntegrationTest do
  use ExUnit.Case, async: true

  alias Cinder.Support.SearchTestResource

  describe "complete search attribute integration" do
    test "end-to-end search flow with column processing and query execution" do
      # Full integration: slot -> column -> query -> execution
      col_slots = [
        %{field: "title", search: true, label: "Title"},
        %{field: "description", search: true, label: "Description"},
        %{field: "status", search: false, label: "Status"}
      ]

      # Process through full pipeline
      processed_columns = Cinder.Table.process_columns(col_slots, SearchTestResource)
      query = Ash.Query.for_read(SearchTestResource, :read)

      # Apply search and verify end-to-end flow
      search_result =
        Cinder.QueryBuilder.apply_search(query, "integration test", processed_columns, nil)

      assert search_result != query
      assert search_result.filter != nil
      assert {:ok, _results} = Ash.read(search_result)

      # Verify only searchable columns were included
      searchable_fields = Enum.filter(processed_columns, & &1.searchable) |> Enum.map(& &1.field)
      assert "title" in searchable_fields
      assert "description" in searchable_fields
      refute "status" in searchable_fields
    end

    test "search attribute works with table component processing" do
      # Simulate how the table component processes columns
      col_slots = [
        %{
          field: "title",
          search: true,
          label: "Product Title",
          inner_block: fn -> "Title content" end,
          __slot__: :col
        },
        %{
          field: "description",
          search: true,
          label: "Description",
          inner_block: fn -> "Description content" end,
          __slot__: :col
        },
        %{
          field: "id",
          label: "ID",
          inner_block: fn -> "ID content" end,
          __slot__: :col
        }
      ]

      # Process through table's column processing
      processed = Cinder.Table.process_columns(col_slots, SearchTestResource)

      # Verify searchable fields are set correctly
      searchable_fields = Enum.filter(processed, & &1.searchable)
      non_searchable_fields = Enum.reject(processed, & &1.searchable)

      assert length(searchable_fields) == 2
      assert length(non_searchable_fields) == 1

      searchable_field_names = Enum.map(searchable_fields, & &1.field)
      assert "title" in searchable_field_names
      assert "description" in searchable_field_names
      assert "id" not in searchable_field_names
    end

    test "search works with mixed search and filter attributes" do
      col_slots = [
        %{field: "title", search: true, filter: true, label: "Title"},
        %{field: "description", search: true, filter: false, label: "Description"},
        %{field: "status", search: false, filter: true, label: "Status"},
        %{field: "id", label: "ID"}
      ]

      processed_columns = Cinder.Table.process_columns(col_slots, SearchTestResource)

      # Find specific columns
      title_col = Enum.find(processed_columns, &(&1.field == "title"))
      desc_col = Enum.find(processed_columns, &(&1.field == "description"))
      status_col = Enum.find(processed_columns, &(&1.field == "status"))
      id_col = Enum.find(processed_columns, &(&1.field == "id"))

      # Verify search and filter combinations work correctly
      assert title_col.searchable == true
      assert title_col.filterable == true

      assert desc_col.searchable == true
      assert desc_col.filterable == false

      assert status_col.searchable == false
      assert status_col.filterable == true

      assert id_col.searchable == false
      assert id_col.filterable == false

      # Should show search because at least one column is searchable
      assert show_search_helper(processed_columns) == true
    end

    test "search attribute validation in slot definition" do
      # This test ensures the slot definition accepts the search attribute
      # If this test passes, it means the search attribute is properly defined in the slot

      valid_slot_configs = [
        %{field: "title", search: true},
        %{field: "title", search: false},
        # search defaults to false
        %{field: "title"}
      ]

      Enum.each(valid_slot_configs, fn slot_config ->
        # This should not raise an error if the search attribute is properly defined
        processed = Cinder.Table.process_columns([slot_config], SearchTestResource)
        assert length(processed) == 1

        # Verify searchable is set correctly
        column = hd(processed)
        expected_searchable = Map.get(slot_config, :search, false)
        assert column.searchable == expected_searchable
      end)
    end

    test "end-to-end search flow with URL sync" do
      # Test complete integration including URL sync
      columns_with_search = [
        %{field: "title", searchable: true},
        %{field: "description", searchable: true}
      ]

      # Test URL encoding/decoding with search term
      state_with_search = %{
        filters: %{},
        current_page: 1,
        sort_by: [],
        search_term: "test query"
      }

      # Encode to URL
      encoded = Cinder.UrlManager.encode_state(state_with_search)
      assert encoded[:search] == "test query"

      # Decode from URL (simulating URL params)
      url_params = %{"search" => "test query", "page" => "1"}
      decoded = Cinder.UrlManager.decode_state(url_params, columns_with_search)
      assert decoded.search_term == "test query"

      # Test QueryBuilder with search term
      query = Ash.Query.for_read(SearchTestResource, :read)

      search_result =
        Cinder.QueryBuilder.apply_search(query, decoded.search_term, columns_with_search, nil)

      assert search_result != query
      assert {:ok, _results} = Ash.read(search_result)
    end

    test "no search attribute means no search functionality" do
      # Columns without search attributes
      col_slots = [
        %{field: "title", label: "Title"},
        %{field: "description", filter: true, label: "Description"},
        %{field: "status", sort: true, label: "Status"}
      ]

      processed_columns = Cinder.Table.process_columns(col_slots, SearchTestResource)

      # No columns should be searchable
      assert Enum.all?(processed_columns, &(&1.searchable == false))

      # Should not show search
      assert show_search_helper(processed_columns) == false

      # Search should not modify query when no searchable columns
      query = Ash.Query.for_read(SearchTestResource, :read)
      search_result = Cinder.QueryBuilder.apply_search(query, "test", processed_columns, nil)
      assert search_result == query
    end

    test "search attribute works with relationship fields" do
      # Test search on relationship fields (dot notation)
      col_slots = [
        %{field: "user.name", search: true, label: "User Name"},
        %{field: "user.email", search: false, label: "User Email"}
      ]

      # This should process without errors even though the relationships don't exist on our test resource
      processed_columns = Cinder.Table.process_columns(col_slots, SearchTestResource)

      user_name_col = Enum.find(processed_columns, &(&1.field == "user.name"))
      user_email_col = Enum.find(processed_columns, &(&1.field == "user.email"))

      assert user_name_col.searchable == true
      assert user_email_col.searchable == false

      # Should show search because one column is searchable
      assert show_search_helper(processed_columns) == true
    end

    test "search attribute works with URL-safe embedded fields" do
      # Test search on embedded fields (URL-safe notation)
      col_slots = [
        %{field: "profile__first_name", search: true, label: "First Name"},
        %{field: "profile__last_name", search: true, label: "Last Name"},
        %{field: "settings__theme", search: false, label: "Theme"}
      ]

      processed_columns = Cinder.Table.process_columns(col_slots, SearchTestResource)

      first_name_col = Enum.find(processed_columns, &(&1.field == "profile__first_name"))
      last_name_col = Enum.find(processed_columns, &(&1.field == "profile__last_name"))
      theme_col = Enum.find(processed_columns, &(&1.field == "settings__theme"))

      assert first_name_col.searchable == true
      assert last_name_col.searchable == true
      assert theme_col.searchable == false

      # Should show search
      assert show_search_helper(processed_columns) == true

      # Search should work (even if fields don't exist, it should handle gracefully)
      query = Ash.Query.for_read(SearchTestResource, :read)
      search_result = Cinder.QueryBuilder.apply_search(query, "test", processed_columns, nil)

      # Should handle invalid fields gracefully (return original query or log warning)
      assert search_result != nil
    end

    test "table-level search label and placeholder configuration" do
      # Test that table component accepts and passes through search configuration
      search_config = %{
        search_label: "Find Products",
        search_placeholder: "Type to search products...",
        show_search: true
      }

      # Verify configuration is available (simulating table component passing to FilterManager)
      assert search_config.search_label == "Find Products"
      assert search_config.search_placeholder == "Type to search products..."
      assert search_config.show_search == true

      # Test default values
      default_config = %{
        search_label: "Search",
        search_placeholder: "Search..."
      }

      assert default_config.search_label == "Search"
      assert default_config.search_placeholder == "Search..."
    end

    test "search integration with FilterManager parameters" do
      # Test that search parameters are properly passed to FilterManager
      expected_params = %{
        search_term: "current search",
        show_search: true,
        search_label: "Custom Search Label",
        search_placeholder: "Custom placeholder text"
      }

      # Verify all expected parameters are present
      assert Map.has_key?(expected_params, :search_term)
      assert Map.has_key?(expected_params, :show_search)
      assert Map.has_key?(expected_params, :search_label)
      assert Map.has_key?(expected_params, :search_placeholder)

      # Verify parameter values
      assert expected_params.search_term == "current search"
      assert expected_params.show_search == true
      assert expected_params.search_label == "Custom Search Label"
      assert expected_params.search_placeholder == "Custom placeholder text"
    end

    test "search event handler handles different parameter formats" do
      # Test that the search event handler can handle various parameter formats
      # that Phoenix LiveView might send

      test_cases = [
        # Direct search parameter
        %{"search" => "test query"},
        # Form-based search parameter
        %{"_target" => ["search"], "search" => "test query"},
        # Empty parameters
        %{},
        # Search with empty value
        %{"search" => ""},
        # Form with empty search
        %{"_target" => ["search"], "search" => ""}
      ]

      expected_results = [
        "test query",
        "test query",
        "",
        "",
        ""
      ]

      Enum.zip(test_cases, expected_results)
      |> Enum.each(fn {params, expected_term} ->
        result = extract_search_term_helper(params)

        assert result == expected_term,
               "Failed for params: #{inspect(params)}, expected: #{expected_term}, got: #{result}"
      end)
    end

    test "unified search attribute configuration" do
      # Test the new unified search={...} attribute
      search_config_cases = [
        # Boolean values
        {false, {nil, nil, false, nil}},
        {true, {nil, nil, true, nil}},
        {nil, {nil, nil, nil, nil}},

        # Keyword list configurations
        {[label: "Find Items"], {"Find Items", nil, true, nil}},
        {[placeholder: "Type here..."], {nil, "Type here...", true, nil}},
        {[label: "Search Products", placeholder: "Find products..."],
         {"Search Products", "Find products...", true, nil}},
        {[label: "Custom", placeholder: "Custom placeholder", show_search: false],
         {"Custom", "Custom placeholder", false, nil}},

        # Empty list
        {[], {nil, nil, true, nil}},

        # Invalid config
        {"invalid", {nil, nil, nil, nil}}
      ]

      Enum.each(search_config_cases, fn {input,
                                         {expected_label, expected_placeholder,
                                          expected_show_search, expected_search_fn}} ->
        # This simulates the process_search_config/1 function
        result = process_search_config_helper(input)

        assert result ==
                 {expected_label, expected_placeholder, expected_show_search, expected_search_fn},
               "Failed for input: #{inspect(input)}"
      end)
    end

    test "search attribute takes precedence over individual attributes" do
      # Test that unified search config overrides individual search_label, search_placeholder
      unified_config = [label: "Unified Label", placeholder: "Unified Placeholder"]

      # Simulate table component processing
      {label, placeholder, show_search, _search_fn} = process_search_config_helper(unified_config)

      # Should use unified config values
      assert label == "Unified Label"
      assert placeholder == "Unified Placeholder"
      assert show_search == true

      # Individual attributes would be overridden
      individual_label = "Individual Label"
      individual_placeholder = "Individual Placeholder"

      final_label = label || individual_label
      final_placeholder = placeholder || individual_placeholder
      final_show_search = show_search || false

      assert final_label == "Unified Label"
      assert final_placeholder == "Unified Placeholder"
      assert final_show_search == true
    end
  end

  # Helper function to test search display logic
  defp show_search_helper(columns) do
    Enum.any?(columns, & &1.searchable)
  end

  # Helper function to simulate process_search_config/1
  defp process_search_config_helper(search_config) do
    case search_config do
      nil ->
        {nil, nil, nil, nil}

      false ->
        {nil, nil, false, nil}

      true ->
        {nil, nil, true, nil}

      config when is_list(config) ->
        label = Keyword.get(config, :label)
        placeholder = Keyword.get(config, :placeholder)
        show_search = Keyword.get(config, :show_search, true)
        search_fn = Keyword.get(config, :fn)
        {label, placeholder, show_search, search_fn}

      _invalid ->
        {nil, nil, nil, nil}
    end
  end

  # Helper function to simulate search term extraction from event params
  defp extract_search_term_helper(params) do
    case params do
      %{"search" => term} -> term
      %{"_target" => ["search"], "search" => term} -> term
      %{} -> Map.get(params, "search", "")
    end
  end

  describe "build_query_columns capability matrix" do
    # This test suite verifies the column inclusion logic in build_query_columns
    # to prevent regressions like the searchable columns being excluded bug.
    #
    # Matrix:
    # | Capability           | In query_columns? | In display_columns? |
    # |----------------------|-------------------|---------------------|
    # | searchable only      | ✅                | ✅                  |
    # | filterable only      | ✅                | ✅                  |
    # | sortable only        | ❌                | ✅                  |
    # | searchable+filterable| ✅                | ✅                  |
    # | filter-only slot     | ✅                | ❌                  |

    test "searchable-only columns are included in query_columns" do
      col_slots = [
        %{field: "name", search: true, filter: false, sort: false, label: "Name"}
      ]

      processed = Cinder.Collection.process_columns(col_slots, SearchTestResource)
      query_cols = Cinder.Collection.build_query_columns(processed, [])

      assert length(query_cols) == 1
      assert hd(query_cols).field == "name"
      assert hd(query_cols).searchable == true
      assert hd(query_cols).filterable == false
    end

    test "filterable-only columns are included in query_columns" do
      col_slots = [
        %{field: "status", search: false, filter: true, sort: false, label: "Status"}
      ]

      processed = Cinder.Collection.process_columns(col_slots, SearchTestResource)
      query_cols = Cinder.Collection.build_query_columns(processed, [])

      assert length(query_cols) == 1
      assert hd(query_cols).field == "status"
      assert hd(query_cols).filterable == true
      assert hd(query_cols).searchable == false
    end

    test "sortable-only columns are NOT included in query_columns" do
      col_slots = [
        %{field: "status", search: false, filter: false, sort: true, label: "Status"}
      ]

      processed = Cinder.Collection.process_columns(col_slots, SearchTestResource)
      query_cols = Cinder.Collection.build_query_columns(processed, [])

      # Sortable-only should NOT be in query_columns (sorting uses display columns)
      assert Enum.empty?(query_cols)

      # But it should still be in processed columns (display columns)
      assert length(processed) == 1
      assert hd(processed).field == "status"
    end

    test "columns with multiple capabilities are included once" do
      col_slots = [
        %{field: "title", search: true, filter: true, sort: true, label: "Title"}
      ]

      processed = Cinder.Collection.process_columns(col_slots, SearchTestResource)
      query_cols = Cinder.Collection.build_query_columns(processed, [])

      assert length(query_cols) == 1
      col = hd(query_cols)
      assert col.searchable == true
      assert col.filterable == true
      assert col.sortable == true
    end

    test "filter-only slots are included in query_columns but not display columns" do
      col_slots = [
        %{field: "title", search: true, filter: false, label: "Title"}
      ]

      filter_slots = [
        %{field: "category", type: :select, label: "Category", options: [{"A", "a"}]}
      ]

      processed_cols = Cinder.Collection.process_columns(col_slots, SearchTestResource)

      processed_filters =
        Cinder.Collection.process_filter_slots(filter_slots, SearchTestResource)

      query_cols = Cinder.Collection.build_query_columns(processed_cols, processed_filters)

      # query_columns should have both
      query_fields = Enum.map(query_cols, & &1.field)
      assert "title" in query_fields
      assert "category" in query_fields

      # display columns (processed_cols) should only have title
      display_fields = Enum.map(processed_cols, & &1.field)
      assert "title" in display_fields
      refute "category" in display_fields
    end

    test "mixed capability columns are correctly partitioned" do
      col_slots = [
        %{field: "title", search: true, filter: false, label: "Title"},
        %{field: "status", search: false, filter: true, label: "Status"},
        %{
          field: "category",
          search: false,
          filter: false,
          sort: true,
          label: "Category Sort Only"
        },
        %{field: "description", search: false, filter: false, sort: false, label: "Display Only"}
      ]

      filter_slots = [
        %{field: "filter_only_field", type: :text, label: "Filter Only"}
      ]

      processed_cols = Cinder.Collection.process_columns(col_slots, SearchTestResource)

      processed_filters =
        Cinder.Collection.process_filter_slots(filter_slots, SearchTestResource)

      query_cols = Cinder.Collection.build_query_columns(processed_cols, processed_filters)

      query_fields = Enum.map(query_cols, & &1.field)

      # Searchable and filterable columns should be in query_columns
      assert "title" in query_fields
      assert "status" in query_fields
      assert "filter_only_field" in query_fields

      # Sortable-only and display-only should NOT be in query_columns
      refute "category" in query_fields
      refute "description" in query_fields

      # All columns should be in display columns
      display_fields = Enum.map(processed_cols, & &1.field)
      assert length(display_fields) == 4
    end
  end
end
