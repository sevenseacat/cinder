defmodule Cinder.UrlSyncTest do
  use ExUnit.Case, async: true

  alias Cinder.UrlSync

  describe "extract_collection_state/1" do
    test "extracts empty state from empty params" do
      state = UrlSync.extract_collection_state(%{})

      assert state.filters == %{}
      assert state.current_page == 1
      assert state.sort_by == []
    end

    test "falls back to the first page and no sort for malformed params" do
      state = UrlSync.extract_collection_state(%{"page" => "invalid", "sort" => ["a", "b"]})

      assert state.current_page == 1
      assert state.sort_by == []
    end

    test "extracts page state from params" do
      params = %{"page" => "3"}
      state = UrlSync.extract_collection_state(params)

      assert state.current_page == 3
    end

    test "extracts sort state from params" do
      params = %{"sort" => "name"}
      state = UrlSync.extract_collection_state(params)

      assert state.sort_by == [{"name", :asc}]

      state = UrlSync.extract_collection_state(%{"sort" => "name,-email"})
      assert state.sort_by == [{"name", :asc}, {"email", :desc}]
    end

    test "handles empty list for sort safely" do
      params = %{"sort" => []}
      state = UrlSync.extract_collection_state(params)

      assert state.sort_by == []
    end
  end

  describe "integration with UrlManager" do
    test "build_url uses the path from the provided URI" do
      # Atom keys in the encoded state are stringified for the query string
      encoded_state = %{name: "john", page: "2"}

      assert UrlSync.build_url(encoded_state, "http://localhost:4000/weapons") ==
               "/weapons?name=john&page=2"
    end

    test "build_url uses the URI from the socket's url_state when current_uri is nil" do
      socket = %{assigns: %{url_state: %{uri: "http://localhost:4000/albums"}}}

      assert UrlSync.build_url(%{"artist.name" => "za"}, nil, socket) == "/albums?artist.name=za"
    end

    test "build_url falls back to a rooted path when no URI is available" do
      # Regression: a bare "?artist.name=za" makes push_patch/2 raise, since :to needs a path
      for socket <- [%{assigns: %{}}, %{assigns: %{url_state: %{}}}, nil] do
        assert UrlSync.build_url(%{"artist.name" => "za"}, nil, socket) == "/?artist.name=za"
      end
    end

    test "filter-only slots are properly decoded from URL parameters (regression test)" do
      # This tests the specific bug where filter-only slots (like <:filter field="track_count" .../>)
      # were lost during URL state decoding because decode_url_state was using display columns
      # instead of query_columns for filter decoding

      # Simulate filter-only slot configuration
      query_columns = [
        %{field: "name", filterable: true, filter_type: :text},
        %{
          field: "track_count",
          filterable: true,
          filter_type: :checkbox,
          filter_options: [value: 8]
        }
      ]

      # Simulate display columns (no track_count because it's filter-only)
      display_columns = [
        %{field: "name", sortable: true, filterable: true, filter_type: :text},
        %{field: "artist.name", sortable: true, filterable: false}
      ]

      # Simulate URL parameters that include a filter-only field
      url_params = %{"track_count" => "8", "name" => "test"}

      # Test that query_columns can decode the filter-only field
      filters_with_query_columns = Cinder.UrlManager.decode_filters(url_params, query_columns)
      assert Map.has_key?(filters_with_query_columns, "track_count")

      assert filters_with_query_columns["track_count"] == %{
               type: :checkbox,
               value: 8,
               operator: :equals
             }

      # Test that display columns cannot decode the filter-only field
      filters_with_display_columns = Cinder.UrlManager.decode_filters(url_params, display_columns)
      refute Map.has_key?(filters_with_display_columns, "track_count")

      # Test that sorts still work correctly with display columns
      sort_params = %{"sort" => "name,-artist.name"}
      decoded_sorts = Cinder.UrlManager.decode_sort(Map.get(sort_params, "sort"), display_columns)
      assert decoded_sorts == [{"name", :asc}, {"artist.name", :desc}]

      # Test that invalid sorts are filtered out correctly
      invalid_sort_params = %{"sort" => "track_count,name"}

      filtered_sorts =
        Cinder.UrlManager.decode_sort(Map.get(invalid_sort_params, "sort"), display_columns)

      # track_count should be filtered out because it's not in display columns (not sortable)
      assert filtered_sorts == [{"name", :asc}]
    end
  end

  test "regression test: sort-only columns work via URL validation" do
    # This test verifies the bug fix where sort-only columns (filterable: false)
    # should be sortable via URL parameters using display_columns for validation

    # Mock display columns that would be in socket.assigns.columns
    display_columns = [
      %{field: "name", sortable: true, filterable: false},
      %{field: "artist.name", sortable: true, filterable: false},
      %{field: "genre", sortable: false, filterable: true}
    ]

    # Mock URL parameters with sort on a sort-only column
    raw_params = %{"sort" => "artist.name"}

    # With the fix: decode_url_state uses display_columns for validation
    decoded_state = Cinder.UrlManager.decode_state(raw_params, display_columns)

    # The sort should be preserved because artist.name is found in display_columns
    assert decoded_state.sort_by == [{"artist.name", :asc}],
           "Sort-only columns should be sortable via URL when using display_columns for validation"
  end

  describe "update_url/3 query parameter merging" do
    test "preserves existing custom query parameters when updating table state" do
      # This test demonstrates the bug where custom query parameters are lost
      # when table state changes

      # Current URI has custom query parameters
      current_uri = "http://localhost:4000/users?tab=overview&section=details"

      # New table state (user filtered by name and went to page 2)
      encoded_state = %{"name" => "john", "page" => "2"}

      # Build the URL using the current implementation
      result_url = UrlSync.build_url(encoded_state, current_uri)

      # Expected: URL should preserve custom params and merge with table state
      # /users?tab=overview&section=details&name=john&page=2

      # This will FAIL with current implementation - custom params are lost
      assert String.contains?(result_url, "tab=overview"),
             "Expected URL to contain tab=overview but got: #{result_url}"

      assert String.contains?(result_url, "section=details"),
             "Expected URL to contain section=details but got: #{result_url}"

      assert String.contains?(result_url, "name=john"),
             "Expected URL to contain name=john but got: #{result_url}"

      assert String.contains?(result_url, "page=2"),
             "Expected URL to contain page=2 but got: #{result_url}"
    end

    test "new table parameters override existing table parameters" do
      # Current URI already has table state (page=1, sort=name) plus custom param
      current_uri = "http://localhost:4000/users?page=1&sort=name&tab=overview"

      # User changes to page 2 and changes sort
      encoded_state = %{"page" => "2", "sort" => "-created_at"}

      result_url = UrlSync.build_url(encoded_state, current_uri)

      # New table params should override old ones
      assert String.contains?(result_url, "page=2")
      assert String.contains?(result_url, "sort=-created_at")
      refute String.contains?(result_url, "page=1")
      refute String.contains?(result_url, "sort=name")

      # But custom param should persist - this will FAIL with current implementation
      assert String.contains?(result_url, "tab=overview"),
             "Expected URL to preserve tab=overview but got: #{result_url}"
    end

    test "handles empty new params without removing existing custom params" do
      current_uri = "http://localhost:4000/users?tab=overview"

      # No new table state (user cleared all filters)
      encoded_state = %{}

      result_url = UrlSync.build_url(encoded_state, current_uri)

      # Custom params should remain even when no table state
      # This will FAIL with current implementation
      assert String.contains?(result_url, "tab=overview"),
             "Expected URL to preserve tab=overview but got: #{result_url}"
    end

    test "handles case with no existing query parameters" do
      current_uri = "http://localhost:4000/users"

      encoded_state = %{"name" => "john", "page" => "2"}

      result_url = UrlSync.build_url(encoded_state, current_uri)

      # Should just have the new params
      assert String.contains?(result_url, "name=john")
      assert String.contains?(result_url, "page=2")
      assert result_url == "/users?name=john&page=2"
    end

    test "removes cleared filters from URL while preserving custom params" do
      # This test demonstrates the critical bug: when a filter is cleared,
      # it should be removed from the URL, but custom params should remain

      # URL has a filter and a custom param
      current_uri = "http://localhost:4000/users?name=john&tab=overview"

      # User clears the name filter - encoded_state no longer has "name"
      # but includes filter field names metadata so we know "name" was a filter
      encoded_state = %{"_filter_fields" => "name"}

      result_url = UrlSync.build_url(encoded_state, current_uri)

      # BUG: The name filter persists in the URL because we're merging
      # Expected: /users?tab=overview
      # Actual: /users?name=john&tab=overview
      refute String.contains?(result_url, "name=john"),
             "Expected cleared filter to be removed but got: #{result_url}"

      # Custom param should still be there
      assert String.contains?(result_url, "tab=overview"),
             "Expected custom param to persist but got: #{result_url}"
    end

    test "removes cleared filters while keeping other filters and custom params" do
      # URL has multiple filters and a custom param
      current_uri =
        "http://localhost:4000/users?name=john&email=test@example.com&page=2&tab=overview"

      # User clears name filter but keeps email filter, resets to page 1
      # Include filter field names metadata to identify which params are filters
      encoded_state = %{"email" => "test@example.com", "_filter_fields" => "name,email"}

      result_url = UrlSync.build_url(encoded_state, current_uri)

      # Cleared filter should be gone
      refute String.contains?(result_url, "name=john"),
             "Expected cleared name filter to be removed but got: #{result_url}"

      # Cleared page should be gone (page=1 is default, so not in encoded_state)
      refute String.contains?(result_url, "page="),
             "Expected page to be removed when back to default but got: #{result_url}"

      # Active filter should remain
      assert String.contains?(result_url, "email=test"),
             "Expected active filter to remain but got: #{result_url}"

      # Custom param should remain
      assert String.contains?(result_url, "tab=overview"),
             "Expected custom param to remain but got: #{result_url}"
    end
  end
end
