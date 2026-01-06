defmodule Cinder.Table.PageSizePreservationTest do
  @moduledoc """
  Regression tests for page size preservation when parent LiveView re-renders,
  plus backward compatibility tests for LiveComponent event handlers.

  This tests the fix for the bug where user-selected page sizes were reset
  to default when the parent LiveView re-rendered due to unrelated state changes.

  The event handler tests establish a contract that must not be violated
  during refactoring.
  """
  use ExUnit.Case, async: true

  alias Cinder.LiveComponent

  defmodule TestResource do
    @moduledoc false
    use Ash.Resource,
      domain: Cinder.Table.PageSizePreservationTest.Domain,
      data_layer: Ash.DataLayer.Ets,
      validate_domain_inclusion?: false

    ets do
      private?(true)
    end

    attributes do
      uuid_primary_key(:id)
      attribute(:name, :string, public?: true)
    end

    actions do
      defaults([:read])
    end
  end

  defmodule Domain do
    @moduledoc false
    use Ash.Domain, validate_config_inclusion?: false

    resources do
      resource(TestResource)
    end
  end

  defp build_test_assigns(page_size_config) do
    %{
      id: "test-table",
      query: TestResource,
      actor: nil,
      tenant: nil,
      page_size_config: page_size_config,
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

  describe "page size preservation across updates" do
    test "preserves user-selected page size when component receives new assigns" do
      # Initial mount
      {:ok, socket} = LiveComponent.mount(%Phoenix.LiveView.Socket{})

      # First update with default page size config
      page_size_config = %{
        selected_page_size: 10,
        page_size_options: [10, 25, 50],
        default_page_size: 10,
        configurable: true
      }

      initial_assigns = build_test_assigns(page_size_config)
      {:ok, socket} = LiveComponent.update(initial_assigns, socket)
      assert socket.assigns.page_size == 10
      assert socket.assigns.page_size_config.selected_page_size == 10

      # User changes page size to 25
      {:noreply, socket} =
        LiveComponent.handle_event("change_page_size", %{"page_size" => "25"}, socket)

      assert socket.assigns.page_size == 25
      assert socket.assigns.page_size_config.selected_page_size == 25

      # Parent LiveView re-renders and sends new assigns (simulating a parent state change)
      # The page_size_config will be recreated with the default value
      new_assigns =
        build_test_assigns(%{
          selected_page_size: 10,
          page_size_options: [10, 25, 50],
          default_page_size: 10,
          configurable: true
        })

      {:ok, socket} = LiveComponent.update(new_assigns, socket)

      # The user's selection should be preserved in both page_size and page_size_config
      assert socket.assigns.page_size == 25,
             "User-selected page_size should be preserved across parent re-renders"

      assert socket.assigns.page_size_config.selected_page_size == 25,
             "page_size_config.selected_page_size should match preserved page_size for UI consistency"
    end

    test "uses default page size on first render when no previous selection exists" do
      {:ok, socket} = LiveComponent.mount(%Phoenix.LiveView.Socket{})

      page_size_config = %{
        selected_page_size: 50,
        page_size_options: [10, 25, 50],
        default_page_size: 50,
        configurable: true
      }

      assigns = build_test_assigns(page_size_config)
      {:ok, socket} = LiveComponent.update(assigns, socket)

      # Should use the default from config on first render
      assert socket.assigns.page_size == 50
      assert socket.assigns.page_size_config.selected_page_size == 50
    end
  end

  # ============================================================================
  # BACKWARD COMPATIBILITY: EVENT HANDLER TESTS
  # These tests document the expected event handler behavior that must be
  # preserved during refactoring.
  # ============================================================================

  describe "backward compatibility: event handlers" do
    setup do
      {:ok, socket} = LiveComponent.mount(%Phoenix.LiveView.Socket{})

      page_size_config = %{
        selected_page_size: 25,
        page_size_options: [10, 25, 50],
        default_page_size: 25,
        configurable: true
      }

      assigns = build_test_assigns(page_size_config)
      {:ok, socket} = LiveComponent.update(assigns, socket)

      # Add required assigns for event handlers
      socket =
        socket
        |> Phoenix.Component.assign(:filters, %{})
        |> Phoenix.Component.assign(:sort_by, [])
        |> Phoenix.Component.assign(:current_page, 1)
        |> Phoenix.Component.assign(:search_term, "")
        |> Phoenix.Component.assign(:filter_field_names, ["name"])
        |> Phoenix.Component.assign(:query_columns, [
          %{field: "name", filterable: true, filter_type: :text}
        ])
        |> Phoenix.Component.assign(:user_has_interacted, false)

      {:ok, socket: socket}
    end

    test "change_page_size event accepts page_size as string", %{socket: socket} do
      # Event parameter structure: %{"page_size" => "50"}
      {:noreply, socket} =
        LiveComponent.handle_event("change_page_size", %{"page_size" => "50"}, socket)

      assert socket.assigns.page_size == 50
      assert socket.assigns.page_size_config.selected_page_size == 50
    end

    test "goto_page event accepts page as string", %{socket: socket} do
      # Event parameter structure: %{"page" => "3"}
      {:noreply, socket} =
        LiveComponent.handle_event("goto_page", %{"page" => "3"}, socket)

      assert socket.assigns.current_page == 3
    end

    test "toggle_sort event accepts key as string", %{socket: socket} do
      # Event parameter structure: %{"key" => "name"}
      {:noreply, socket} =
        LiveComponent.handle_event("toggle_sort", %{"key" => "name"}, socket)

      # Should add ascending sort for the field
      assert socket.assigns.sort_by == [{"name", :asc}]
    end

    test "toggle_sort cycles through asc -> desc -> none", %{socket: socket} do
      # First click: asc
      {:noreply, socket} =
        LiveComponent.handle_event("toggle_sort", %{"key" => "name"}, socket)

      assert socket.assigns.sort_by == [{"name", :asc}]

      # Second click: desc
      {:noreply, socket} =
        LiveComponent.handle_event("toggle_sort", %{"key" => "name"}, socket)

      assert socket.assigns.sort_by == [{"name", :desc}]

      # Third click: removed
      {:noreply, socket} =
        LiveComponent.handle_event("toggle_sort", %{"key" => "name"}, socket)

      assert socket.assigns.sort_by == []
    end

    test "clear_filter event accepts key as string", %{socket: socket} do
      # Setup: add a filter first
      socket =
        Phoenix.Component.assign(socket, :filters, %{
          "name" => %{type: :text, value: "test", operator: :contains}
        })

      # Event parameter structure: %{"key" => "name"}
      {:noreply, socket} =
        LiveComponent.handle_event("clear_filter", %{"key" => "name"}, socket)

      assert socket.assigns.filters == %{}
    end

    test "clear_filter with key=search clears search_term", %{socket: socket} do
      socket = Phoenix.Component.assign(socket, :search_term, "search query")

      # Event parameter structure: %{"key" => "search"}
      {:noreply, socket} =
        LiveComponent.handle_event("clear_filter", %{"key" => "search"}, socket)

      assert socket.assigns.search_term == ""
    end

    test "clear_all_filters event clears all filters", %{socket: socket} do
      # Setup: add filters
      socket =
        Phoenix.Component.assign(socket, :filters, %{
          "name" => %{type: :text, value: "test", operator: :contains},
          "email" => %{type: :text, value: "example", operator: :contains}
        })

      # Event parameter structure: %{} (no params)
      {:noreply, socket} =
        LiveComponent.handle_event("clear_all_filters", %{}, socket)

      assert socket.assigns.filters == %{}
    end

    test "refresh event returns noreply tuple", %{socket: socket} do
      # Event parameter structure: %{} (no params)
      result = LiveComponent.handle_event("refresh", %{}, socket)

      # Should return {:noreply, socket} tuple
      assert {:noreply, _socket} = result
    end

    test "filter_change event accepts filters map structure", %{socket: socket} do
      # Event parameter structure: %{"filters" => %{"field" => "value"}}
      params = %{
        "filters" => %{"name" => "test value"}
      }

      {:noreply, socket} =
        LiveComponent.handle_event("filter_change", params, socket)

      # Should have processed the filter
      assert Map.has_key?(socket.assigns.filters, "name")
    end

    test "filter_change resets current_page to 1", %{socket: socket} do
      socket = Phoenix.Component.assign(socket, :current_page, 5)

      params = %{"filters" => %{"name" => "test"}}

      {:noreply, socket} =
        LiveComponent.handle_event("filter_change", params, socket)

      assert socket.assigns.current_page == 1
    end

    test "toggle_sort resets current_page to 1", %{socket: socket} do
      socket = Phoenix.Component.assign(socket, :current_page, 5)

      {:noreply, socket} =
        LiveComponent.handle_event("toggle_sort", %{"key" => "name"}, socket)

      assert socket.assigns.current_page == 1
    end

    test "clear_filter resets current_page to 1", %{socket: socket} do
      socket =
        socket
        |> Phoenix.Component.assign(:current_page, 5)
        |> Phoenix.Component.assign(:filters, %{"name" => %{value: "test"}})

      {:noreply, socket} =
        LiveComponent.handle_event("clear_filter", %{"key" => "name"}, socket)

      assert socket.assigns.current_page == 1
    end

    test "clear_all_filters resets current_page to 1", %{socket: socket} do
      socket =
        socket
        |> Phoenix.Component.assign(:current_page, 5)
        |> Phoenix.Component.assign(:filters, %{"name" => %{value: "test"}})

      {:noreply, socket} =
        LiveComponent.handle_event("clear_all_filters", %{}, socket)

      assert socket.assigns.current_page == 1
    end
  end
end
