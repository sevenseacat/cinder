defmodule Cinder.Integration.PaginationPreservationTest do
  @moduledoc """
  Tests that pagination state is preserved during slot-only updates.

  When a parent LiveView re-renders due to assign changes that only affect
  slot content (like driver_progress changing), the Cinder component should
  NOT reload data and should preserve the existing :page assign.
  """

  # Runs synchronously (async: false) so we can disable Cinder's async loading
  # for the whole module. That makes these assertions meaningful: if an update
  # wrongly triggered a reload, load_data would run inline against the `query: nil`
  # fake socket and reset :page — which the assertions catch. With async loading
  # on, a spurious reload is deferred via start_async and would go unnoticed here.
  # ExUnit runs async: false modules in isolation, so toggling the global flag is
  # race-free.
  use ExUnit.Case, async: false

  alias Cinder.LiveComponent

  setup {Cinder.TestHelpers, :disable_async_loading}

  defmodule TestScopeStruct do
    defstruct [:current_user, :current_tenant]
  end

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

    test "an equal struct scope does not trigger a reload on parent re-render" do
      # A component already loaded with a struct scope.
      scope = %TestScopeStruct{current_user: %{id: 1}, current_tenant: "scope_tenant"}
      loaded = make_loaded_socket()
      socket = %{loaded | assigns: Map.put(loaded.assigns, :scope, scope)}
      original_page = socket.assigns.page

      # The parent re-renders, rebuilding the scope struct from scratch (a new
      # instance with equal content) and changing only slot content — exactly
      # what happens when an unrelated parent assign changes. normalize_scope/1
      # must map equal-content scopes to the same key, otherwise this looks like
      # a data change and triggers a spurious reload.
      new_assigns = %{
        id: "test-table",
        query: nil,
        query_opts: [],
        actor: nil,
        tenant: nil,
        scope: %TestScopeStruct{current_user: %{id: 1}, current_tenant: "scope_tenant"},
        col: [],
        item_slot: [%{inner_block: fn _, _ -> "new content" end}],
        search_fn: nil
      }

      assert {:ok, updated_socket} = LiveComponent.update(new_assigns, socket)

      # No reload happened, so the page is preserved. (With query: nil, a reload
      # would have failed and reset the page to nil.)
      assert updated_socket.assigns.page == original_page
      assert updated_socket.assigns.page != nil
    end
  end
end
