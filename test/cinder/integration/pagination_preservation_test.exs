defmodule Cinder.Integration.PaginationPreservationTest do
  @moduledoc """
  Tests that pagination state is preserved during slot-only updates.

  When a parent LiveView re-renders due to assign changes that only affect
  slot content (like driver_progress changing), the Cinder component should
  NOT reload data and should preserve the existing :page assign.
  """

  use ExUnit.Case, async: true

  alias Cinder.LiveComponent

  # Simulate a socket with all the assigns a loaded Cinder component would have
  defp make_loaded_socket do
    page = %Ash.Page.Offset{
      results: [%{id: 1}, %{id: 2}],
      count: 50,
      offset: 0,
      limit: 25,
      more?: true
    }

    %Phoenix.LiveView.Socket{
      assigns: %{
        __changed__: %{},
        # Internal state that should be preserved
        page: page,
        data: [%{id: 1, name: "Item 1"}, %{id: 2, name: "Item 2"}],
        filters: %{},
        sort_by: [],
        current_page: 1,
        page_size: 25,
        search_term: "",
        loading: false,
        # These are needed for assign_defaults/assign_column_definitions
        id: "test-table",
        query: nil,
        query_opts: [],
        actor: nil,
        tenant: nil,
        col: [],
        item_slot: [],
        pagination_mode: :offset,
        page_size_config: %{
          selected_page_size: 25,
          page_size_options: [10, 25, 50],
          default_page_size: 25,
          configurable: true
        },
        after_keyset: nil,
        before_keyset: nil,
        first_keyset: nil,
        last_keyset: nil,
        theme: Cinder.Theme.default(),
        bulk_actions: [],
        id_field: :id,
        emit_visible_ids: false,
        user_has_interacted: false,
        scope: nil
      }
    }
  end

  describe "pagination preservation during parent re-renders" do
    test "page is preserved when only slot content changes" do
      socket = make_loaded_socket()
      original_page = socket.assigns.page

      # Simulate parent re-render that only changes slot content
      # (like when @driver_progress changes in route_progress.ex)
      new_assigns = %{
        id: "test-table",
        query: nil,
        query_opts: [],
        actor: nil,
        tenant: nil,
        col: [],
        # Slot would be different closure but same structure
        item_slot: [%{inner_block: fn _, _ -> "new content" end}]
      }

      {:ok, updated_socket} = LiveComponent.update(new_assigns, socket)

      # Page should be preserved, not nil
      assert updated_socket.assigns.page == original_page
      assert updated_socket.assigns.page != nil
    end

    test "page is preserved after in-memory update followed by slot update" do
      socket = make_loaded_socket()
      original_page = socket.assigns.page

      # First: in-memory update (like Cinder.update_if_visible)
      update_assigns = %{
        __update_item__: {1, fn item -> %{item | name: "Updated"} end}
      }

      {:ok, socket} = LiveComponent.update(update_assigns, socket)

      # Page should still be there
      assert socket.assigns.page == original_page

      # Second: parent re-render with slot change
      slot_assigns = %{
        id: "test-table",
        query: nil,
        query_opts: [],
        actor: nil,
        tenant: nil,
        col: [],
        item_slot: [%{inner_block: fn _, _ -> "changed again" end}]
      }

      {:ok, socket} = LiveComponent.update(slot_assigns, socket)

      # Page should STILL be preserved
      assert socket.assigns.page == original_page
      assert socket.assigns.page != nil
    end

    test "data is preserved when only slot content changes" do
      socket = make_loaded_socket()
      original_data = socket.assigns.data

      new_assigns = %{
        id: "test-table",
        query: nil,
        query_opts: [],
        actor: nil,
        tenant: nil,
        col: [],
        item_slot: []
      }

      {:ok, updated_socket} = LiveComponent.update(new_assigns, socket)

      # Data should be preserved
      assert updated_socket.assigns.data == original_data
    end
  end
end
