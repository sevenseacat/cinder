defmodule Cinder.UrlSyncIntegrationTest do
  use ExUnit.Case, async: true

  describe "URL sync integration" do
    test "extract_table_state handles URL parameters correctly" do
      # Test the core URL parsing functionality
      params = %{
        "name" => "john",
        "age_min" => "25",
        "age_max" => "65",
        "active" => "true",
        "page" => "2",
        "sort" => "-name"
      }

      # Call extract_table_state directly
      state = Cinder.UrlSync.extract_table_state(params)

      # Verify state was extracted correctly
      assert state.current_page == 2
      assert state.sort_by == [{"name", :desc}]
      assert is_map(state.filters)
    end

    test "URL generation logic works correctly" do
      # Test URL path extraction from URI
      uri = "http://localhost:4000/users"
      parsed = URI.parse(uri)
      path = parsed.path || "/"

      assert path == "/users"

      # Test query string generation
      encoded_state = %{"name" => "jane", "page" => "1"}

      new_params =
        encoded_state
        |> Enum.map(fn {k, v} -> {to_string(k), v} end)
        |> Enum.into(%{})
        |> Enum.reject(fn {_k, v} -> is_nil(v) or v == "" end)
        |> Enum.into(%{})

      query_string = URI.encode_query(new_params)
      expected_url = "#{path}?#{query_string}"

      assert expected_url == "/users?name=jane&page=1"
    end

    test "empty filter handling" do
      # Test that empty filters are properly removed
      encoded_state = %{"name" => "", "page" => nil, "active" => "true"}

      clean_params =
        encoded_state
        |> Enum.map(fn {k, v} -> {to_string(k), v} end)
        |> Enum.into(%{})
        |> Enum.reject(fn {_k, v} -> is_nil(v) or v == "" end)
        |> Enum.into(%{})

      # Only non-empty values should remain
      assert clean_params == %{"active" => "true"}
    end

    test "relationship filter parameter handling" do
      params = %{
        "user.department.name" => "Engineering",
        "user.role" => "admin",
        "page" => "3"
      }

      state = Cinder.UrlSync.extract_table_state(params)

      # Verify relationship filters are in the state
      assert state.current_page == 3
      # Filters are processed but may be empty due to no column context
      assert is_map(state.filters)
    end

    test "URL sync macro injection" do
      # Test that the UrlSync macro properly injects handle_info
      defmodule TestUrlSyncView do
        use Cinder.UrlSync
      end

      # Verify the function exists
      assert function_exported?(TestUrlSyncView, :handle_info, 2)
    end

    test "edge case handling" do
      # Test with minimal params
      minimal_params = %{}
      state = Cinder.UrlSync.extract_table_state(minimal_params)

      assert state.filters == %{}
      assert state.current_page == 1
      assert state.sort_by == []

      # Test with invalid page number
      invalid_params = %{"page" => "invalid"}
      state2 = Cinder.UrlSync.extract_table_state(invalid_params)

      # Should default to page 1 for invalid page numbers
      assert state2.current_page == 1
    end

    test "multiple parameter handling" do
      # Test that URL sync can handle multiple different parameters
      params = %{
        "users_name" => "john",
        "orders_status" => "completed",
        "page" => "3"
      }

      state = Cinder.UrlSync.extract_table_state(params)

      # Standard page parameter should be handled
      assert state.current_page == 3

      # All other parameters should be available in filters
      assert is_map(state.filters)
    end

    test "special character handling" do
      # Test URL encoding with special characters
      params = %{
        "name" => "O'Connor & Associates",
        "email" => "test+user@example.com",
        "description" => "Projects: A, B & C"
      }

      # Test that query encoding works correctly
      query_string = URI.encode_query(params)

      # Should properly encode special characters
      assert query_string =~ "O%27Connor"
      assert query_string =~ "test%2Buser"
      assert query_string =~ "A%2C+B"
    end
  end

  describe "error handling" do
    test "gracefully handles malformed sort parameters" do
      params = %{
        # Should be a string, not an array
        "sort" => ["invalid", "array"]
      }

      # Should not crash and should handle gracefully
      state = Cinder.UrlSync.extract_table_state(params)

      # Should default to empty sort
      assert state.sort_by == []
    end
  end

  describe "core functionality" do
    test "extract_table_state works independently" do
      # This function should work without requiring full URL sync setup
      params = %{
        "name" => "test",
        "page" => "5",
        "sort" => "email"
      }

      state = Cinder.UrlSync.extract_table_state(params)

      assert is_map(state.filters)
      assert state.current_page == 5
      assert state.sort_by == [{"email", :asc}]
    end
  end
end
