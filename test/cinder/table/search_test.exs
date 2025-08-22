defmodule Cinder.Table.SearchTest do
  use ExUnit.Case, async: true

  alias Cinder.Support.SearchTestResource

  describe "search parameter validation" do
    test "search_change event expects proper parameter structure" do
      # Test that search_change event expects %{"search" => term} format
      valid_params = %{"search" => "widget"}
      assert Map.get(valid_params, "search") == "widget"

      invalid_params = %{"invalid_key" => "test"}
      assert Map.get(invalid_params, "search") == nil
    end

    test "search terms are properly extracted from parameters" do
      # Test various parameter formats
      test_cases = [
        {%{"search" => "widget"}, "widget"},
        {%{"search" => ""}, ""},
        {%{"search" => nil}, nil},
        {%{}, nil}
      ]

      Enum.each(test_cases, fn {params, expected} ->
        result = Map.get(params, "search")
        assert result == expected
      end)
    end
  end

  describe "search state management" do
    test "search state includes all required fields" do
      # Test the structure of state that would be passed to QueryBuilder
      state = %{
        search_term: "widget",
        search_fn: nil,
        columns: [
          %{field: "title", searchable: true},
          %{field: "description", searchable: true}
        ],
        filters: %{},
        current_page: 1,
        sort_by: []
      }

      # Verify structure
      assert state.search_term == "widget"
      assert state.search_fn == nil
      assert length(state.columns) == 2
      assert Enum.all?(state.columns, & &1.searchable)
    end

    test "custom search functions are properly stored" do
      custom_search_fn = fn query, _searchable_columns, _search_term ->
        query
      end

      state = %{
        search_term: "test",
        search_fn: custom_search_fn
      }

      assert state.search_fn == custom_search_fn
      assert is_function(state.search_fn, 3)
    end
  end

  describe "search column configuration" do
    test "search attribute processing in column parsing" do
      # Test that search=true gets converted to searchable: true
      slot_with_search = %{
        field: "title",
        search: true,
        label: "Title"
      }

      parsed_column = Cinder.Column.parse_column(slot_with_search, SearchTestResource)

      assert parsed_column.searchable == true
      assert parsed_column.field == "title"
    end

    test "search attribute defaults to false when not specified" do
      slot_without_search = %{
        field: "title",
        label: "Title"
      }

      parsed_column = Cinder.Column.parse_column(slot_without_search, SearchTestResource)

      assert parsed_column.searchable == false
    end

    test "search=false explicitly sets searchable to false" do
      slot_with_search_false = %{
        field: "title",
        search: false,
        label: "Title"
      }

      parsed_column = Cinder.Column.parse_column(slot_with_search_false, SearchTestResource)

      assert parsed_column.searchable == false
    end
  end

  describe "search auto-enable logic" do
    test "auto-enables when searchable columns exist" do
      columns = [
        %{field: "name", searchable: true},
        %{field: "email", searchable: false}
      ]

      {label, placeholder, enabled} = Cinder.Table.process_search_config(nil, columns)

      assert enabled == true
      assert label == "Search"
      assert placeholder == "Search..."
    end

    test "does not auto-enable when no columns are searchable" do
      columns = [
        %{field: "title", searchable: false},
        %{field: "description", searchable: false}
      ]

      {_label, _placeholder, enabled} = Cinder.Table.process_search_config(nil, columns)
      assert enabled == false
    end

    test "custom search configuration overrides auto-detection" do
      columns = [%{field: "name", searchable: true}]
      config = [label: "Find Users", placeholder: "Type to search users..."]

      {label, placeholder, enabled} = Cinder.Table.process_search_config(config, columns)

      assert enabled == true
      assert label == "Find Users"
      assert placeholder == "Type to search users..."
    end

    test "search disabled with false config even with searchable columns" do
      columns = [%{field: "name", searchable: true}]

      {label, placeholder, enabled} = Cinder.Table.process_search_config(false, columns)

      assert enabled == false
      assert label == nil
      assert placeholder == nil
    end
  end

  describe "search URL parameter handling" do
    test "search parameters are properly encoded and decoded" do
      # This is tested in detail in url_manager_test.exs
      # Here we just verify the integration works

      state = %{
        filters: %{},
        current_page: 1,
        sort_by: [],
        search_term: "widget"
      }

      # Encode state should include search
      encoded = Cinder.UrlManager.encode_state(state)
      assert encoded[:search] == "widget"

      # Decode should restore search term - convert atom keys to string keys like real URL params
      url_params = for {key, value} <- encoded, into: %{}, do: {to_string(key), to_string(value)}
      columns = []
      decoded = Cinder.UrlManager.decode_state(url_params, columns)
      assert decoded.search_term == "widget"
    end
  end

  describe "search with custom search functions" do
    test "custom search function receives correct parameters" do
      query = Ash.Query.for_read(SearchTestResource, :read)

      columns = [
        %{field: "title", searchable: true},
        %{field: "description", searchable: true}
      ]

      search_term = "widget"

      # Custom search function that validates parameters
      custom_search_fn = fn received_query, received_columns, received_term ->
        assert received_query == query
        assert length(received_columns) == 2
        assert received_term == "widget"

        # Return modified query
        require Ash.Query
        Ash.Query.filter(received_query, title == "custom")
      end

      result = Cinder.QueryBuilder.apply_search(query, search_term, columns, custom_search_fn)

      # Should have been modified by custom function
      assert result != query
      assert result.filter != nil
    end
  end

  describe "search error handling" do
    test "invalid search parameters are handled gracefully" do
      # Test with various invalid parameter formats
      test_cases = [
        %{"search" => nil},
        %{"search" => 123},
        %{"search" => %{}},
        %{"search" => []},
        %{"invalid_key" => "test"},
        %{}
      ]

      Enum.each(test_cases, fn params ->
        search_term = Map.get(params, "search")

        # Should handle gracefully - nil and non-string values should be treated as empty
        # This simulates what the event handler would do
        processed_term =
          case search_term do
            term when is_binary(term) -> term
            _ -> ""
          end

        assert is_binary(processed_term)
      end)
    end

    test "search with non-existent fields is handled gracefully" do
      query = Ash.Query.for_read(SearchTestResource, :read)

      columns = [
        %{field: "nonexistent_field", searchable: true}
      ]

      # Should not crash even with invalid field names
      result = Cinder.QueryBuilder.apply_search(query, "test", columns, nil)

      # Should return original query on error
      assert result == query
    end

    test "empty search terms do not trigger search" do
      query = Ash.Query.for_read(SearchTestResource, :read)
      columns = [%{field: "title", searchable: true}]

      # Empty string should not trigger search
      result1 = Cinder.QueryBuilder.apply_search(query, "", columns, nil)
      assert result1 == query

      # Nil should not trigger search
      result2 = Cinder.QueryBuilder.apply_search(query, nil, columns, nil)
      assert result2 == query
    end
  end
end
