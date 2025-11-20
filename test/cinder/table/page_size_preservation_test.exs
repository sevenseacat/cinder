defmodule Cinder.Table.PageSizePreservationTest do
  @moduledoc """
  Regression tests for page size preservation when parent LiveView re-renders.

  This tests the fix for the bug where user-selected page sizes were reset
  to default when the parent LiveView re-rendered due to unrelated state changes.
  """
  use ExUnit.Case, async: true

  alias Cinder.Table.LiveComponent

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
      filter_configs: [],
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
end
