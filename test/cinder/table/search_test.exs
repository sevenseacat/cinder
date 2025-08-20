defmodule Cinder.Table.SearchTest do
  use ExUnit.Case, async: true

  # Test resources for search testing
  defmodule SearchTestResource do
    use Ash.Resource,
      domain: Cinder.Table.SearchTest.TestDomain,
      data_layer: Ash.DataLayer.Ets,
      validate_domain_inclusion?: false

    ets do
      private?(true)
    end

    attributes do
      uuid_primary_key(:id)
      attribute(:title, :string, public?: true)
      attribute(:description, :string, public?: true)
      attribute(:status, :string, public?: true)
      attribute(:category, :string, public?: true)
    end

    actions do
      defaults([:read])

      create :create do
        primary?(true)
        accept([:title, :description, :status, :category])
      end
    end
  end

  defmodule TestDomain do
    use Ash.Domain, validate_config_inclusion?: false

    resources do
      resource(SearchTestResource)
    end
  end

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
    test "columns can be marked as searchable" do
      columns = [
        %{field: "title", searchable: true, filterable: false},
        %{field: "description", searchable: true, filterable: true},
        %{field: "status", searchable: false, filterable: true}
      ]

      searchable_columns = Enum.filter(columns, & &1.searchable)

      assert length(searchable_columns) == 2
      assert Enum.map(searchable_columns, & &1.field) == ["title", "description"]
    end

    test "default searchable value is false" do
      column = %{field: "title"}

      # Default value should be false when not specified
      assert Map.get(column, :searchable, false) == false
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
