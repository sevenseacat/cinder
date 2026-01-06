defmodule Cinder.Integration.KeysetPaginationTest do
  @moduledoc """
  Integration tests for keyset (cursor-based) pagination.

  Keyset pagination provides better performance for large datasets by using
  cursors instead of offsets. This test suite covers:
  - QueryBuilder keyset execution
  - LiveComponent event handlers (next_page, prev_page)
  - URL state encoding/decoding for cursors
  - Keyset cursor extraction from results
  """

  use ExUnit.Case, async: true

  alias Cinder.QueryBuilder
  alias Cinder.UrlManager

  # ============================================================================
  # TEST RESOURCES
  # ============================================================================

  defmodule TestDomain do
    use Ash.Domain, validate_config_inclusion?: false

    resources do
      allow_unregistered?(true)
    end
  end

  defmodule TestItem do
    use Ash.Resource,
      domain: TestDomain,
      data_layer: Ash.DataLayer.Ets,
      validate_domain_inclusion?: false

    ets do
      private?(true)
    end

    actions do
      defaults([:read, :destroy])

      create :create do
        primary?(true)
        accept([:name, :position])
      end
    end

    attributes do
      uuid_primary_key(:id)
      attribute(:name, :string, allow_nil?: false, public?: true)
      attribute(:position, :integer, allow_nil?: false, public?: true)
    end
  end

  # ============================================================================
  # QUERY BUILDER TESTS
  # ============================================================================

  describe "QueryBuilder with keyset pagination" do
    setup do
      # Clean up any existing records
      TestItem |> Ash.read!() |> Enum.each(&Ash.destroy!/1)

      # Create test items with sequential positions for deterministic ordering
      items =
        for i <- 1..10 do
          TestItem
          |> Ash.Changeset.for_create(:create, %{name: "Item #{i}", position: i})
          |> Ash.create!()
        end

      %{items: items}
    end

    test "executes keyset pagination and returns page with keyset metadata" do
      options = [
        actor: nil,
        filters: %{},
        sort_by: [{"position", :asc}],
        page_size: 3,
        current_page: 1,
        columns: [],
        query_opts: [],
        pagination_mode: :keyset,
        after_keyset: nil,
        before_keyset: nil
      ]

      {:ok, page} = QueryBuilder.build_and_execute(TestItem, options)

      # Ash may return either Offset or Keyset depending on app config and parameters.
      # On first page (no cursor), typically returns Offset but with keyset metadata.
      assert page.__struct__ in [Ash.Page.Offset, Ash.Page.Keyset]
      assert length(page.results) == 3
      assert page.count == 10
      assert page.limit == 3

      # First page should have items 1, 2, 3
      names = Enum.map(page.results, & &1.name)
      assert names == ["Item 1", "Item 2", "Item 3"]

      # Each result should have keyset metadata for subsequent navigation
      for result <- page.results do
        assert Map.has_key?(result.__metadata__, :keyset)
        assert is_binary(result.__metadata__.keyset)
      end
    end

    test "navigates forward with after cursor" do
      # First, get the first page to obtain a cursor
      first_page_options = [
        actor: nil,
        filters: %{},
        sort_by: [{"position", :asc}],
        page_size: 3,
        current_page: 1,
        columns: [],
        query_opts: [],
        pagination_mode: :keyset,
        after_keyset: nil,
        before_keyset: nil
      ]

      {:ok, first_page} = QueryBuilder.build_and_execute(TestItem, first_page_options)

      # Get the keyset from the last result
      last_keyset = List.last(first_page.results).__metadata__.keyset

      # Now fetch next page using after cursor
      next_page_options = Keyword.put(first_page_options, :after_keyset, last_keyset)
      {:ok, next_page} = QueryBuilder.build_and_execute(TestItem, next_page_options)

      assert %Ash.Page.Keyset{} = next_page
      assert length(next_page.results) == 3

      # Second page should have items 4, 5, 6
      names = Enum.map(next_page.results, & &1.name)
      assert names == ["Item 4", "Item 5", "Item 6"]
    end

    test "navigates backward with before cursor" do
      # First, navigate to page 2
      first_page_options = [
        actor: nil,
        filters: %{},
        sort_by: [{"position", :asc}],
        page_size: 3,
        current_page: 1,
        columns: [],
        query_opts: [],
        pagination_mode: :keyset,
        after_keyset: nil,
        before_keyset: nil
      ]

      {:ok, first_page} = QueryBuilder.build_and_execute(TestItem, first_page_options)
      last_keyset = List.last(first_page.results).__metadata__.keyset

      # Get page 2
      page2_options = Keyword.put(first_page_options, :after_keyset, last_keyset)
      {:ok, page2} = QueryBuilder.build_and_execute(TestItem, page2_options)

      # Now go back using before cursor from first result of page 2
      first_keyset = List.first(page2.results).__metadata__.keyset

      back_options =
        first_page_options
        |> Keyword.put(:before_keyset, first_keyset)
        |> Keyword.put(:after_keyset, nil)

      {:ok, back_page} = QueryBuilder.build_and_execute(TestItem, back_options)

      # Should be back to first 3 items
      names = Enum.map(back_page.results, & &1.name)
      assert names == ["Item 1", "Item 2", "Item 3"]
    end

    test "returns empty results when navigating past end" do
      # Get to the last page
      options = [
        actor: nil,
        filters: %{},
        sort_by: [{"position", :asc}],
        page_size: 5,
        current_page: 1,
        columns: [],
        query_opts: [],
        pagination_mode: :keyset,
        after_keyset: nil,
        before_keyset: nil
      ]

      # First page (1-5)
      {:ok, page1} = QueryBuilder.build_and_execute(TestItem, options)
      cursor1 = List.last(page1.results).__metadata__.keyset

      # Second page (6-10)
      {:ok, page2} =
        QueryBuilder.build_and_execute(TestItem, Keyword.put(options, :after_keyset, cursor1))

      cursor2 = List.last(page2.results).__metadata__.keyset

      # Third page should be empty
      {:ok, page3} =
        QueryBuilder.build_and_execute(TestItem, Keyword.put(options, :after_keyset, cursor2))

      assert page3.results == []
    end

    test "offset pagination still works as default" do
      options = [
        actor: nil,
        filters: %{},
        sort_by: [{"position", :asc}],
        page_size: 3,
        current_page: 2,
        columns: [],
        query_opts: [],
        pagination_mode: :offset,
        after_keyset: nil,
        before_keyset: nil
      ]

      {:ok, page} = QueryBuilder.build_and_execute(TestItem, options)

      assert %Ash.Page.Offset{} = page
      assert length(page.results) == 3
      assert page.offset == 3

      # Page 2 should have items 4, 5, 6
      names = Enum.map(page.results, & &1.name)
      assert names == ["Item 4", "Item 5", "Item 6"]
    end
  end

  # ============================================================================
  # URL STATE TESTS
  # ============================================================================

  describe "UrlManager keyset cursor encoding/decoding" do
    test "encodes after cursor in state" do
      state = %{
        filters: %{},
        sort_by: [],
        current_page: 1,
        page_size: 25,
        search_term: "",
        after: "g2wAAAABbQAAAARha3Vsag==",
        before: nil
      }

      encoded = UrlManager.encode_state(state)

      assert encoded[:after] == "g2wAAAABbQAAAARha3Vsag=="
      refute Map.has_key?(encoded, :before)
      refute Map.has_key?(encoded, :page)
    end

    test "encodes before cursor in state" do
      state = %{
        filters: %{},
        sort_by: [],
        current_page: 1,
        page_size: 25,
        search_term: "",
        after: nil,
        before: "g2wAAAABbQAAAARia3Vsag=="
      }

      encoded = UrlManager.encode_state(state)

      assert encoded[:before] == "g2wAAAABbQAAAARia3Vsag=="
      refute Map.has_key?(encoded, :after)
    end

    test "decodes cursor from URL params" do
      assert UrlManager.decode_cursor("g2wAAAABbQAAAARha3Vsag==") ==
               "g2wAAAABbQAAAARha3Vsag=="

      assert UrlManager.decode_cursor(nil) == nil
      assert UrlManager.decode_cursor("") == nil
    end

    test "decode_state includes after and before cursors" do
      url_params = %{
        "after" => "cursor123",
        "sort" => "name"
      }

      columns = [%{field: "name", sortable: true}]

      decoded = UrlManager.decode_state(url_params, columns)

      assert decoded.after == "cursor123"
      assert decoded.before == nil
    end

    test "prefers cursor over page number for keyset mode" do
      state = %{
        filters: %{},
        sort_by: [],
        current_page: 5,
        page_size: 25,
        search_term: "",
        after: "some_cursor",
        before: nil
      }

      encoded = UrlManager.encode_state(state)

      # Should have cursor, not page
      assert encoded[:after] == "some_cursor"
      refute Map.has_key?(encoded, :page)
    end

    test "falls back to page number when no cursor present" do
      state = %{
        filters: %{},
        sort_by: [],
        current_page: 3,
        page_size: 25,
        search_term: "",
        after: nil,
        before: nil
      }

      encoded = UrlManager.encode_state(state)

      assert encoded[:page] == "3"
      refute Map.has_key?(encoded, :after)
      refute Map.has_key?(encoded, :before)
    end
  end

  # ============================================================================
  # PAGINATION RENDERER TESTS
  # ============================================================================

  describe "Pagination.show_pagination?/1" do
    alias Cinder.Renderers.Pagination

    test "returns true for Ash.Page.Keyset when count exceeds limit" do
      page = %Ash.Page.Keyset{
        results: [],
        count: 100,
        limit: 25,
        more?: true,
        after: nil,
        before: nil,
        rerun: nil
      }

      assert Pagination.show_pagination?(page) == true
    end

    test "returns false for Ash.Page.Keyset when count fits in one page" do
      page = %Ash.Page.Keyset{
        results: [],
        count: 10,
        limit: 25,
        more?: false,
        after: nil,
        before: nil,
        rerun: nil
      }

      assert Pagination.show_pagination?(page) == false
    end

    test "returns true for Ash.Page.Offset when count exceeds limit" do
      page = %Ash.Page.Offset{
        results: [],
        count: 100,
        limit: 25,
        offset: 0,
        more?: true,
        rerun: nil
      }

      assert Pagination.show_pagination?(page) == true
    end

    test "returns false for Ash.Page.Offset when count fits in one page" do
      page = %Ash.Page.Offset{
        results: [],
        count: 10,
        limit: 25,
        offset: 0,
        more?: false,
        rerun: nil
      }

      assert Pagination.show_pagination?(page) == false
    end

    test "returns false for nil page" do
      assert Pagination.show_pagination?(nil) == false
    end

    test "returns false for non-paginated result map" do
      assert Pagination.show_pagination?(%{results: []}) == false
    end
  end

  # ============================================================================
  # KEYSET CURSOR EXTRACTION TESTS
  # ============================================================================

  describe "keyset cursor extraction" do
    test "extracts keyset from result metadata" do
      # Simulate what Ash returns
      result = %{
        id: "123",
        name: "Test",
        __metadata__: %{keyset: "encoded_cursor_value"}
      }

      keyset = get_keyset_from_result(result)
      assert keyset == "encoded_cursor_value"
    end

    test "returns nil when no metadata" do
      result = %{id: "123", name: "Test"}
      assert get_keyset_from_result(result) == nil
    end

    test "returns nil for nil result" do
      assert get_keyset_from_result(nil) == nil
    end

    # Helper to match LiveComponent's implementation
    defp get_keyset_from_result(nil), do: nil

    defp get_keyset_from_result(result) do
      case result do
        %{__metadata__: %{keyset: keyset}} -> keyset
        _ -> nil
      end
    end
  end

  # ============================================================================
  # LIVE COMPONENT EVENT HANDLER TESTS
  # ============================================================================

  describe "LiveComponent keyset event handlers" do
    alias Cinder.LiveComponent

    defp build_keyset_test_assigns do
      %{
        id: "keyset-test-table",
        query: TestItem,
        actor: nil,
        tenant: nil,
        pagination_mode: :keyset,
        page_size_config: %{
          selected_page_size: 10,
          page_size_options: [10, 25, 50],
          default_page_size: 10,
          configurable: true
        },
        theme: Cinder.Theme.default(),
        url_raw_params: %{},
        query_opts: [],
        on_state_change: nil,
        show_filters: false,
        show_pagination: true,
        loading_message: "Loading...",
        filters_label: "Filters",
        empty_message: "No results",
        col: [],
        query_columns: [],
        row_click: nil,
        search_enabled: false,
        search_label: "Search",
        search_placeholder: "Search...",
        search_fn: nil
      }
    end

    test "next_page event sets after_keyset from last_keyset" do
      {:ok, socket} = LiveComponent.mount(%Phoenix.LiveView.Socket{})
      {:ok, socket} = LiveComponent.update(build_keyset_test_assigns(), socket)

      # Simulate having loaded a page with cursors
      socket =
        socket
        |> Phoenix.Component.assign(:first_keyset, "first_cursor")
        |> Phoenix.Component.assign(:last_keyset, "last_cursor")
        |> Phoenix.Component.assign(:after_keyset, nil)
        |> Phoenix.Component.assign(:before_keyset, nil)

      {:noreply, socket} = LiveComponent.handle_event("next_page", %{}, socket)

      assert socket.assigns.after_keyset == "last_cursor"
      assert socket.assigns.before_keyset == nil
    end

    test "prev_page event sets before_keyset from first_keyset" do
      {:ok, socket} = LiveComponent.mount(%Phoenix.LiveView.Socket{})
      {:ok, socket} = LiveComponent.update(build_keyset_test_assigns(), socket)

      # Simulate being on page 2 (navigated forward with after_keyset)
      socket =
        socket
        |> Phoenix.Component.assign(:first_keyset, "page2_first_cursor")
        |> Phoenix.Component.assign(:last_keyset, "page2_last_cursor")
        |> Phoenix.Component.assign(:after_keyset, "page1_last_cursor")
        |> Phoenix.Component.assign(:before_keyset, nil)

      {:noreply, socket} = LiveComponent.handle_event("prev_page", %{}, socket)

      assert socket.assigns.before_keyset == "page2_first_cursor"
      assert socket.assigns.after_keyset == nil
    end

    test "change_page_size event clears keyset cursors" do
      {:ok, socket} = LiveComponent.mount(%Phoenix.LiveView.Socket{})
      {:ok, socket} = LiveComponent.update(build_keyset_test_assigns(), socket)

      # Simulate having navigated (cursors set)
      socket =
        socket
        |> Phoenix.Component.assign(:after_keyset, "some_cursor")
        |> Phoenix.Component.assign(:before_keyset, nil)

      {:noreply, socket} =
        LiveComponent.handle_event("change_page_size", %{"page_size" => "25"}, socket)

      # Cursors should be cleared to restart from beginning
      assert socket.assigns.after_keyset == nil
      assert socket.assigns.before_keyset == nil
      assert socket.assigns.page_size == 25
    end

    test "goto_page event is ignored in keyset mode" do
      {:ok, socket} = LiveComponent.mount(%Phoenix.LiveView.Socket{})
      {:ok, socket} = LiveComponent.update(build_keyset_test_assigns(), socket)

      original_page = socket.assigns.current_page

      # In keyset mode, goto_page should return early without changing state
      {:noreply, socket} = LiveComponent.handle_event("goto_page", %{"page" => "5"}, socket)

      # Page should remain unchanged
      assert socket.assigns.current_page == original_page
    end

    test "next_page event is ignored in offset mode" do
      assigns = build_keyset_test_assigns() |> Map.put(:pagination_mode, :offset)

      {:ok, socket} = LiveComponent.mount(%Phoenix.LiveView.Socket{})
      {:ok, socket} = LiveComponent.update(assigns, socket)

      socket =
        socket
        |> Phoenix.Component.assign(:last_keyset, "some_cursor")
        |> Phoenix.Component.assign(:after_keyset, nil)

      {:noreply, socket} = LiveComponent.handle_event("next_page", %{}, socket)

      # after_keyset should remain nil in offset mode
      assert socket.assigns.after_keyset == nil
    end

    test "prev_page event is ignored in offset mode" do
      assigns = build_keyset_test_assigns() |> Map.put(:pagination_mode, :offset)

      {:ok, socket} = LiveComponent.mount(%Phoenix.LiveView.Socket{})
      {:ok, socket} = LiveComponent.update(assigns, socket)

      socket =
        socket
        |> Phoenix.Component.assign(:first_keyset, "some_cursor")
        |> Phoenix.Component.assign(:before_keyset, nil)

      {:noreply, socket} = LiveComponent.handle_event("prev_page", %{}, socket)

      # before_keyset should remain nil in offset mode
      assert socket.assigns.before_keyset == nil
    end

    test "filter_change event clears keyset cursors when filters change" do
      {:ok, socket} = LiveComponent.mount(%Phoenix.LiveView.Socket{})
      {:ok, socket} = LiveComponent.update(build_keyset_test_assigns(), socket)

      # Simulate having navigated to page 2 with existing filters
      socket =
        socket
        |> Phoenix.Component.assign(:after_keyset, "page1_last_cursor")
        |> Phoenix.Component.assign(:before_keyset, nil)
        |> Phoenix.Component.assign(:columns, [])
        |> Phoenix.Component.assign(:query_columns, [])
        |> Phoenix.Component.assign(:filters, %{"status" => %{value: "active"}})

      # Apply different filters - this should reset pagination
      {:noreply, socket} =
        LiveComponent.handle_event("filter_change", %{"filters" => %{}}, socket)

      # Cursors should be cleared because filters changed
      assert socket.assigns.after_keyset == nil
      assert socket.assigns.before_keyset == nil
    end

    test "filter_change event does not reset pagination when filters unchanged" do
      {:ok, socket} = LiveComponent.mount(%Phoenix.LiveView.Socket{})
      {:ok, socket} = LiveComponent.update(build_keyset_test_assigns(), socket)

      # Simulate having navigated to page 2 with no filters
      socket =
        socket
        |> Phoenix.Component.assign(:after_keyset, "page1_last_cursor")
        |> Phoenix.Component.assign(:before_keyset, nil)
        |> Phoenix.Component.assign(:columns, [])
        |> Phoenix.Component.assign(:query_columns, [])
        |> Phoenix.Component.assign(:filters, %{})

      # Submit same empty filters (e.g., typing in autocomplete without selecting)
      {:noreply, socket} =
        LiveComponent.handle_event("filter_change", %{"filters" => %{}}, socket)

      # Cursors should NOT be cleared because filters didn't change
      assert socket.assigns.after_keyset == "page1_last_cursor"
      assert socket.assigns.before_keyset == nil
    end

    test "toggle_sort event clears keyset cursors" do
      {:ok, socket} = LiveComponent.mount(%Phoenix.LiveView.Socket{})
      {:ok, socket} = LiveComponent.update(build_keyset_test_assigns(), socket)

      # Simulate having navigated to page 2
      socket =
        socket
        |> Phoenix.Component.assign(:after_keyset, "page1_last_cursor")
        |> Phoenix.Component.assign(:before_keyset, nil)
        |> Phoenix.Component.assign(:sort_by, [])

      {:noreply, socket} =
        LiveComponent.handle_event("toggle_sort", %{"key" => "name"}, socket)

      # Cursors should be cleared to restart from beginning
      assert socket.assigns.after_keyset == nil
      assert socket.assigns.before_keyset == nil
    end

    test "clear_filter event clears keyset cursors" do
      {:ok, socket} = LiveComponent.mount(%Phoenix.LiveView.Socket{})
      {:ok, socket} = LiveComponent.update(build_keyset_test_assigns(), socket)

      # Simulate having navigated and having filters
      socket =
        socket
        |> Phoenix.Component.assign(:after_keyset, "page1_last_cursor")
        |> Phoenix.Component.assign(:before_keyset, nil)
        |> Phoenix.Component.assign(:filters, %{"status" => %{value: "active"}})

      {:noreply, socket} =
        LiveComponent.handle_event("clear_filter", %{"key" => "status"}, socket)

      # Cursors should be cleared to restart from beginning
      assert socket.assigns.after_keyset == nil
      assert socket.assigns.before_keyset == nil
    end

    test "clear_filter search event clears keyset cursors" do
      {:ok, socket} = LiveComponent.mount(%Phoenix.LiveView.Socket{})
      {:ok, socket} = LiveComponent.update(build_keyset_test_assigns(), socket)

      # Simulate having navigated with a search term
      socket =
        socket
        |> Phoenix.Component.assign(:after_keyset, "page1_last_cursor")
        |> Phoenix.Component.assign(:before_keyset, nil)
        |> Phoenix.Component.assign(:search_term, "test query")

      {:noreply, socket} =
        LiveComponent.handle_event("clear_filter", %{"key" => "search"}, socket)

      # Cursors should be cleared to restart from beginning
      assert socket.assigns.after_keyset == nil
      assert socket.assigns.before_keyset == nil
    end

    test "clear_all_filters event clears keyset cursors" do
      {:ok, socket} = LiveComponent.mount(%Phoenix.LiveView.Socket{})
      {:ok, socket} = LiveComponent.update(build_keyset_test_assigns(), socket)

      # Simulate having navigated with filters
      socket =
        socket
        |> Phoenix.Component.assign(:after_keyset, "page1_last_cursor")
        |> Phoenix.Component.assign(:before_keyset, nil)
        |> Phoenix.Component.assign(:filters, %{"status" => %{value: "active"}})

      {:noreply, socket} =
        LiveComponent.handle_event("clear_all_filters", %{}, socket)

      # Cursors should be cleared to restart from beginning
      assert socket.assigns.after_keyset == nil
      assert socket.assigns.before_keyset == nil
    end
  end
end
