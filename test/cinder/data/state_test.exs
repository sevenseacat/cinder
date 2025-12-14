defmodule Cinder.Data.StateTest do
  @moduledoc """
  Tests for Cinder.Data.State shared state management functions.
  """
  use ExUnit.Case, async: true

  alias Cinder.Data.State

  # ============================================================================
  # TEST HELPERS
  # ============================================================================

  defp build_socket(assigns \\ %{}) do
    default_assigns = %{
      filters: %{},
      search_term: "",
      current_page: 1,
      sort_by: [],
      page_size: 25,
      page_size_config: %{
        selected_page_size: 25,
        page_size_options: [10, 25, 50],
        default_page_size: 25,
        configurable: true
      },
      columns: [
        %{field: "name", filterable: true, filter_type: :text},
        %{field: "email", filterable: true, filter_type: :text}
      ],
      col: [
        %{field: "name", sort_cycle: nil},
        %{field: "email", sort_cycle: nil}
      ],
      user_has_interacted: false,
      on_state_change: nil,
      loading: false,
      data: [],
      query: "TestResource"
    }

    merged = Map.merge(default_assigns, assigns)

    # Build a proper socket with __changed__ tracking
    %Phoenix.LiveView.Socket{}
    |> Phoenix.Component.assign(merged)
  end

  # ============================================================================
  # FILTER STATE MANAGEMENT TESTS
  # ============================================================================

  describe "apply_filter_change/2" do
    test "updates filters from params" do
      socket = build_socket()

      params = %{"filters" => %{"name" => "test value"}}
      result = State.apply_filter_change(socket, params)

      assert Map.has_key?(result.assigns.filters, "name")
    end

    test "updates search term when present in params" do
      socket = build_socket()

      params = %{"filters" => %{}, "search" => "search query"}
      result = State.apply_filter_change(socket, params)

      assert result.assigns.search_term == "search query"
    end

    test "preserves existing search term when not in params" do
      socket = build_socket(%{search_term: "existing"})

      params = %{"filters" => %{"name" => "test"}}
      result = State.apply_filter_change(socket, params)

      assert result.assigns.search_term == "existing"
    end

    test "resets current_page to 1" do
      socket = build_socket(%{current_page: 5})

      params = %{"filters" => %{"name" => "test"}}
      result = State.apply_filter_change(socket, params)

      assert result.assigns.current_page == 1
    end

    test "handles empty filters param" do
      socket = build_socket(%{filters: %{"name" => %{value: "old"}}})

      params = %{}
      result = State.apply_filter_change(socket, params)

      # Should clear filters when empty
      assert result.assigns.filters == %{}
    end

    test "uses filter_columns when available" do
      filter_columns = [
        %{field: "status", filterable: true, filter_type: :select}
      ]

      socket = build_socket(%{filter_columns: filter_columns})

      params = %{"filters" => %{"status" => "active"}}
      result = State.apply_filter_change(socket, params)

      assert Map.has_key?(result.assigns.filters, "status")
    end
  end

  describe "clear_filter/2" do
    test "removes specific filter" do
      socket =
        build_socket(%{
          filters: %{
            "name" => %{type: :text, value: "test"},
            "email" => %{type: :text, value: "example"}
          }
        })

      result = State.clear_filter(socket, "name")

      refute Map.has_key?(result.assigns.filters, "name")
      assert Map.has_key?(result.assigns.filters, "email")
    end

    test "resets current_page to 1" do
      socket =
        build_socket(%{
          current_page: 5,
          filters: %{"name" => %{value: "test"}}
        })

      result = State.clear_filter(socket, "name")

      assert result.assigns.current_page == 1
    end

    test "handles clearing non-existent filter" do
      socket = build_socket(%{filters: %{}})

      result = State.clear_filter(socket, "nonexistent")

      assert result.assigns.filters == %{}
    end
  end

  describe "clear_search/1" do
    test "clears search term" do
      socket = build_socket(%{search_term: "search query"})

      result = State.clear_search(socket)

      assert result.assigns.search_term == ""
    end

    test "resets current_page to 1" do
      socket = build_socket(%{search_term: "query", current_page: 5})

      result = State.clear_search(socket)

      assert result.assigns.current_page == 1
    end
  end

  describe "clear_all_filters/1" do
    test "clears all filters" do
      socket =
        build_socket(%{
          filters: %{
            "name" => %{type: :text, value: "test"},
            "email" => %{type: :text, value: "example"}
          }
        })

      result = State.clear_all_filters(socket)

      assert result.assigns.filters == %{}
    end

    test "resets current_page to 1" do
      socket =
        build_socket(%{
          current_page: 5,
          filters: %{"name" => %{value: "test"}}
        })

      result = State.clear_all_filters(socket)

      assert result.assigns.current_page == 1
    end
  end

  # ============================================================================
  # SORT STATE MANAGEMENT TESTS
  # ============================================================================

  describe "toggle_sort/2" do
    test "adds ascending sort for unsorted field" do
      socket = build_socket(%{sort_by: []})

      result = State.toggle_sort(socket, "name")

      assert result.assigns.sort_by == [{"name", :asc}]
    end

    test "changes ascending to descending" do
      socket = build_socket(%{sort_by: [{"name", :asc}]})

      result = State.toggle_sort(socket, "name")

      assert result.assigns.sort_by == [{"name", :desc}]
    end

    test "removes descending sort" do
      socket = build_socket(%{sort_by: [{"name", :desc}]})

      result = State.toggle_sort(socket, "name")

      assert result.assigns.sort_by == []
    end

    test "resets current_page to 1" do
      socket = build_socket(%{current_page: 5, sort_by: []})

      result = State.toggle_sort(socket, "name")

      assert result.assigns.current_page == 1
    end

    test "sets user_has_interacted to true" do
      socket = build_socket(%{user_has_interacted: false})

      result = State.toggle_sort(socket, "name")

      assert result.assigns.user_has_interacted == true
    end

    test "uses column sort_cycle when available" do
      col_with_cycle = [
        %{field: "priority", sort_cycle: [:desc, :asc, nil]}
      ]

      socket = build_socket(%{col: col_with_cycle, sort_by: []})

      # First toggle should be desc (first in cycle)
      result = State.toggle_sort(socket, "priority")

      assert result.assigns.sort_by == [{"priority", :desc}]
    end
  end

  # ============================================================================
  # PAGINATION STATE MANAGEMENT TESTS
  # ============================================================================

  describe "goto_page/2" do
    test "accepts page as string" do
      socket = build_socket(%{current_page: 1})

      result = State.goto_page(socket, "5")

      assert result.assigns.current_page == 5
    end

    test "accepts page as integer" do
      socket = build_socket(%{current_page: 1})

      result = State.goto_page(socket, 5)

      assert result.assigns.current_page == 5
    end
  end

  describe "change_page_size/2" do
    test "accepts page_size as string" do
      socket = build_socket()

      result = State.change_page_size(socket, "50")

      assert result.assigns.page_size == 50
    end

    test "accepts page_size as integer" do
      socket = build_socket()

      result = State.change_page_size(socket, 50)

      assert result.assigns.page_size == 50
    end

    test "updates page_size_config" do
      socket = build_socket()

      result = State.change_page_size(socket, 50)

      assert result.assigns.page_size_config.selected_page_size == 50
    end

    test "resets current_page to 1" do
      socket = build_socket(%{current_page: 5})

      result = State.change_page_size(socket, 50)

      assert result.assigns.current_page == 1
    end
  end

  # ============================================================================
  # DATA LOADING TESTS
  # ============================================================================

  describe "handle_load_success/3" do
    test "sets loading to false" do
      socket = build_socket(%{loading: true})

      result = State.handle_load_success(socket, [], %{total_pages: 1})

      assert result.assigns.loading == false
    end

    test "sets data from results" do
      socket = build_socket(%{data: []})
      results = [%{id: 1, name: "Test"}]

      result = State.handle_load_success(socket, results, %{total_pages: 1})

      assert result.assigns.data == results
    end

    test "sets page_info" do
      socket = build_socket()
      page_info = %{total_pages: 5, current_page: 2, total_count: 100}

      result = State.handle_load_success(socket, [], page_info)

      assert result.assigns.page_info == page_info
    end
  end

  describe "handle_load_error/2" do
    test "sets loading to false" do
      socket = build_socket(%{loading: true, query: "TestResource"})

      result = State.handle_load_error(socket, "Some error")

      assert result.assigns.loading == false
    end

    test "sets empty data" do
      socket = build_socket(%{data: [%{id: 1}], query: "TestResource"})

      result = State.handle_load_error(socket, "Some error")

      assert result.assigns.data == []
    end

    test "sets error page_info" do
      socket = build_socket(%{query: "TestResource"})

      result = State.handle_load_error(socket, "Some error")

      assert result.assigns.page_info == Cinder.QueryBuilder.build_error_page_info()
    end
  end

  describe "handle_load_crash/2" do
    test "sets loading to false" do
      socket = build_socket(%{loading: true, query: "TestResource"})

      result = State.handle_load_crash(socket, :timeout)

      assert result.assigns.loading == false
    end

    test "sets empty data" do
      socket = build_socket(%{data: [%{id: 1}], query: "TestResource"})

      result = State.handle_load_crash(socket, :timeout)

      assert result.assigns.data == []
    end

    test "sets error page_info" do
      socket = build_socket(%{query: "TestResource"})

      result = State.handle_load_crash(socket, :timeout)

      assert result.assigns.page_info == Cinder.QueryBuilder.build_error_page_info()
    end
  end

  # ============================================================================
  # URL SYNC HELPER TESTS
  # ============================================================================

  describe "url_sync_enabled?/1" do
    test "returns true when on_state_change is set" do
      socket = build_socket(%{on_state_change: :table_state_change})

      assert State.url_sync_enabled?(socket) == true
    end

    test "returns false when on_state_change is nil" do
      socket = build_socket(%{on_state_change: nil})

      assert State.url_sync_enabled?(socket) == false
    end
  end

  describe "maybe_load_data/1" do
    test "returns socket unchanged when URL sync is enabled" do
      socket = build_socket(%{on_state_change: :table_state_change})

      result = State.maybe_load_data(socket)

      # Should not have started loading
      assert result.assigns.loading == false
    end
  end
end
