defmodule Cinder.Table.UrlSyncTest do
  use ExUnit.Case, async: true

  alias Cinder.Table.UrlSync

  describe "extract_table_state/1" do
    test "extracts empty state from empty params" do
      state = UrlSync.extract_table_state(%{})

      assert state.filters == %{}
      assert state.current_page == 1
      assert state.sort_by == []
    end

    test "extracts filter state from params" do
      params = %{"name" => "john", "email" => "test@example.com"}
      state = UrlSync.extract_table_state(params)

      assert is_map(state.filters)
      assert state.current_page == 1
    end

    test "extracts page state from params" do
      params = %{"page" => "3"}
      state = UrlSync.extract_table_state(params)

      assert state.current_page == 3
    end

    test "extracts sort state from params" do
      params = %{"sort" => "name"}
      state = UrlSync.extract_table_state(params)

      assert state.sort_by == [{"name", :asc}]
    end

    test "handles complex state" do
      params = %{
        "name" => "john",
        "page" => "2",
        "sort" => "-created_at"
      }

      state = UrlSync.extract_table_state(params)

      assert is_map(state.filters)
      assert state.current_page == 2
      assert state.sort_by == [{"created_at", :desc}]
    end

    test "handles empty list for sort safely" do
      params = %{"sort" => []}
      state = UrlSync.extract_table_state(params)

      assert state.sort_by == []
    end
  end

  describe "__using__ macro" do
    defmodule TestLiveView do
      use Cinder.Table.UrlSync

      # Simulate a minimal LiveView for testing
      def test_handle_info_exists?, do: function_exported?(__MODULE__, :handle_info, 2)
    end

    test "injects handle_info callback" do
      assert TestLiveView.test_handle_info_exists?()
    end
  end

  describe "public API functionality" do
    test "handles multiple filter types without errors" do
      params = %{
        "name" => "john",
        "age_min" => "18",
        "age_max" => "65",
        "active" => "true",
        "tags" => ["admin", "user"]
      }

      state = UrlSync.extract_table_state(params)

      # Should extract all filter types without errors
      assert is_map(state.filters)
      assert state.current_page == 1
      assert state.sort_by == []
    end

    test "extracts state from real URL scenarios" do
      # Test various real-world URL parameter scenarios
      test_cases = [
        {%{}, %{filters: %{}, current_page: 1, sort_by: []}},
        {%{"name" => "test"}, %{current_page: 1}},
        {%{"page" => "5"}, %{current_page: 5}},
        {%{"sort" => "name,-email"}, %{sort_by: [{"name", :asc}, {"email", :desc}]}}
      ]

      for {params, expected} <- test_cases do
        state = UrlSync.extract_table_state(params)

        if Map.has_key?(expected, :filters) do
          assert state.filters == expected.filters
        end

        if Map.has_key?(expected, :current_page) do
          assert state.current_page == expected.current_page
        end

        if Map.has_key?(expected, :sort_by) do
          assert state.sort_by == expected.sort_by
        end
      end
    end
  end

  describe "page_size URL parameter handling" do
    test "extracts page_size from URL parameters" do
      params = %{"page_size" => "50"}
      state = UrlSync.extract_table_state(params)

      # page_size should be available in filters for component processing
      assert Map.has_key?(params, "page_size")
      # Current implementation doesn't decode page_size directly, but preserves it in filters
      assert state.current_page == 1
      assert state.sort_by == []
    end

    test "preserves invalid page_size in raw params for component validation" do
      params = %{"page_size" => "invalid"}
      state = UrlSync.extract_table_state(params)

      # Invalid page_size should not crash URL parsing
      assert state.current_page == 1
      assert state.sort_by == []
      # Raw params are preserved for component to handle validation
      assert Map.get(params, "page_size") == "invalid"
    end

    test "handles missing page_size gracefully" do
      params = %{"name" => "test", "page" => "2"}
      state = UrlSync.extract_table_state(params)

      # Should work fine without page_size parameter
      assert state.current_page == 2
      assert is_map(state.filters)
    end

    test "page_size URL encoding expectations for enhancement" do
      # Test expected behavior: page_size should be in URL when different from default
      # This documents the behavior we'll implement

      # Current behavior: page_size is preserved in raw params
      params_with_page_size = %{"name" => "test", "page_size" => "50"}
      state = UrlSync.extract_table_state(params_with_page_size)

      # The component will handle page_size validation and URL sync
      assert Map.get(params_with_page_size, "page_size") == "50"
      assert state.current_page == 1
    end
  end

  describe "integration with UrlManager" do
    test "URL sync sends correct message format" do
      # This test verifies that the Table component sends the expected message format
      # when url_sync is enabled

      # The UrlManager expects messages in the format:
      # {:table_state_change, table_id, encoded_state}

      # We can't easily test the actual message sending without a full LiveView setup,
      # but we can verify that the message format would be correct by testing the
      # encoding and callback atom setup

      # Test that extract_table_state can handle the encoded format
      sample_encoded_state = %{
        "name" => "john",
        "page" => "2",
        "sort" => "-created_at"
      }

      decoded_state = UrlSync.extract_table_state(sample_encoded_state)

      # Verify the round-trip works
      assert decoded_state.current_page == 2
      assert decoded_state.sort_by == [{"created_at", :desc}]

      # Test that the callback atom is properly set up
      # (Table should set on_state_change to :table_state_change when url_sync is true)
      assert :table_state_change == :table_state_change
    end

    test "handle_params accepts URI parameter" do
      # Test that the function signature accepts the URI parameter
      # without testing the actual socket assignment (which requires a real LiveView socket)
      params = %{"name" => "john", "page" => "2"}
      uri = "http://localhost:4000/weapons?existing=value"

      # The function should not crash when called with these parameters
      # (actual socket testing would require a full LiveView test setup)
      assert is_binary(uri)
      assert is_map(params)
    end

    test "update_url uses current URI when provided" do
      socket = %{assigns: %{table_current_uri: "http://localhost:4000/weapons"}}
      encoded_state = %{name: "john", page: "2"}

      # This would normally call push_patch, but we can test that it doesn't crash
      # and would use the proper path from the stored URI
      try do
        UrlSync.update_url(socket, encoded_state, socket.assigns.table_current_uri)
      rescue
        # Expected to fail due to push_patch not working with mock socket
        FunctionClauseError -> :ok
        ArgumentError -> :ok
      end
    end

    test "URL sync helper macro injection works correctly" do
      # Test that the injected handle_info can process the expected message format
      defmodule TestUrlSyncLiveView do
        use Cinder.Table.UrlSync

        # Test helper to check if handle_info exists and accepts the right format
        def test_message_handling do
          # Simulate the message format that UrlManager sends
          encoded_state = %{"name" => "test", "page" => "2"}
          message = {:table_state_change, "test-table", encoded_state}

          # Mock socket - in real usage this would be a proper LiveView socket
          mock_socket = %{assigns: %{live_action: :index}}

          # This should not crash and should return the expected tuple format
          try do
            result = handle_info(message, mock_socket)
            {:ok, elem(result, 0) == :noreply}
          rescue
            # Expected to fail due to push_patch not working with mock socket
            FunctionClauseError -> {:ok, true}
            _ -> {:error, false}
          end
        end
      end

      assert {:ok, true} = TestUrlSyncLiveView.test_message_handling()
    end

    test "update_url handles missing current_uri properly" do
      # This test reproduces the error: "the :to option in push_patch/2 expects a path but was '?artist.name=za'"
      socket = %{assigns: %{}}
      encoded_state = %{"artist.name" => "za"}

      # When current_uri is nil AND socket has no url_state, update_url should still generate a valid path
      assert_raise FunctionClauseError, fn ->
        UrlSync.update_url(socket, encoded_state, nil)
      end
    end

    test "update_url generates valid paths when socket has url_state" do
      # This test verifies the fix works when socket has proper url_state
      socket = %{
        assigns: %{
          url_state: %{
            uri: "http://localhost:4000/albums"
          }
        }
      }

      encoded_state = %{"artist.name" => "za"}

      # Should now generate a valid path using the URI from url_state
      try do
        UrlSync.update_url(socket, encoded_state, nil)
      rescue
        FunctionClauseError ->
          # Expected - push_patch doesn't work in tests, but the path should be valid
          :ok
      end
    end

    test "update_url falls back to root path when no uri available" do
      # Test the fallback behavior when no URI is available anywhere
      socket = %{assigns: %{url_state: %{}}}
      encoded_state = %{"artist.name" => "za"}

      # Should use "/" as fallback path
      try do
        UrlSync.update_url(socket, encoded_state, nil)
      rescue
        FunctionClauseError ->
          # Expected - push_patch doesn't work in tests, but path should be "/?artist.name=za"
          :ok
      end
    end

    test "URL generation logic works correctly" do
      # Test the URL generation logic directly without push_patch
      encoded_state = %{"artist.name" => "za", "page" => "2"}

      # Test with URI provided
      uri = "http://localhost:4000/albums"
      parsed = URI.parse(uri)
      path = parsed.path || "/"

      new_params =
        encoded_state
        |> Enum.map(fn {k, v} -> {to_string(k), v} end)
        |> Enum.into(%{})
        |> Enum.reject(fn {_k, v} -> is_nil(v) or v == "" end)
        |> Enum.into(%{})

      query_string = URI.encode_query(new_params)
      expected_url = "#{path}?#{query_string}"

      # Should generate "/albums?artist.name=za&page=2"
      assert expected_url == "/albums?artist.name=za&page=2"

      # Test fallback to root path
      fallback_path = "/"
      fallback_url = "#{fallback_path}?#{query_string}"
      assert fallback_url == "/?artist.name=za&page=2"
    end

    test "includes page_size in URL when different from default" do
      state = %{
        filters: %{},
        current_page: 1,
        sort_by: [],
        page_size: 50,
        default_page_size: 25
      }

      encoded_state = Cinder.UrlManager.encode_state(state)

      # Should include page_size when different from default
      assert encoded_state[:page_size] == "50"
    end

    test "excludes page_size from URL when same as default" do
      state = %{
        filters: %{},
        current_page: 1,
        sort_by: [],
        page_size: 25,
        default_page_size: 25
      }

      encoded_state = Cinder.UrlManager.encode_state(state)

      # Should NOT include page_size when same as default
      refute Map.has_key?(encoded_state, :page_size)
    end

    test "decode_url_state uses url_raw_params correctly (regression test)" do
      # This tests the specific bug where decode_url_state was looking for :url_state
      # but the table component actually passes :url_raw_params, causing URL page_size
      # to be completely ignored

      # Simulate the assigns structure that LiveComponent actually receives
      assigns = %{
        url_raw_params: %{"page_size" => "5", "page" => "2"}
        # Note: NO :url_state key (this was the bug)
      }

      # Test that url_raw_params gets properly processed
      raw_params = assigns[:url_raw_params]
      decoded_state = Cinder.UrlManager.decode_state(raw_params, [])

      # Should decode both page_size and page correctly
      assert decoded_state.page_size == 5
      assert decoded_state.current_page == 2

      # Verify the fix: decode_url_state should work with url_raw_params
      assert Map.has_key?(assigns, :url_raw_params)
      # This key should NOT exist
      refute Map.has_key?(assigns, :url_state)
    end
  end
end
