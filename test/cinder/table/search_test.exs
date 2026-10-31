defmodule Cinder.Table.SearchTest do
  use ExUnit.Case, async: true

  alias Cinder.Support.SearchTestResource

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

      {label, placeholder, enabled, search_fn} =
        Cinder.Collection.process_search_config(nil, columns)

      assert enabled == true
      assert label == "Search"
      assert placeholder == "Search..."
      assert search_fn == nil
    end

    test "does not auto-enable when no columns are searchable" do
      columns = [
        %{field: "title", searchable: false},
        %{field: "description", searchable: false}
      ]

      {_label, _placeholder, enabled, _search_fn} =
        Cinder.Collection.process_search_config(nil, columns)

      assert enabled == false
    end

    test "custom search configuration overrides auto-detection" do
      columns = [%{field: "name", searchable: true}]
      config = [label: "Find Users", placeholder: "Type to search users..."]

      {label, placeholder, enabled, search_fn} =
        Cinder.Collection.process_search_config(config, columns)

      assert enabled == true
      assert label == "Find Users"
      assert placeholder == "Type to search users..."
      assert search_fn == nil
    end

    test "search disabled with false config even with searchable columns" do
      columns = [%{field: "name", searchable: true}]

      {label, placeholder, enabled, search_fn} =
        Cinder.Collection.process_search_config(false, columns)

      assert enabled == false
      assert label == nil
      assert placeholder == nil
      assert search_fn == nil
    end

    test "custom search function configuration" do
      columns = [%{field: "name", searchable: true}]

      custom_search_fn = fn query, _columns, _term ->
        require Ash.Query
        Ash.Query.filter(query, name == "custom")
      end

      config = [fn: custom_search_fn]

      {label, placeholder, enabled, search_fn} =
        Cinder.Collection.process_search_config(config, columns)

      assert enabled == true
      assert label == "Search"
      assert placeholder == "Search..."
      assert search_fn == custom_search_fn
      assert is_function(search_fn, 3)
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
    @tag :capture_log
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
  end
end
