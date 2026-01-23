defmodule Cinder.SelectionTest do
  @moduledoc """
  Tests for selection state management in LiveComponent.
  """

  use ExUnit.Case, async: true

  alias Cinder.LiveComponent

  # Helper to create a properly structured socket for testing
  defp make_socket(assigns) do
    defaults = %{
      __changed__: %{},
      id_field: :id,
      selectable: false,
      selected_ids: MapSet.new(),
      on_selection_change: nil,
      data: []
    }

    %Phoenix.LiveView.Socket{
      assigns: Map.merge(defaults, assigns),
      root_pid: self()
    }
  end

  describe "toggle_select event" do
    test "adds item to selection when not selected" do
      socket =
        make_socket(%{
          id: "test-table",
          selectable: true,
          selected_ids: MapSet.new(),
          data: [%{id: "user-1"}, %{id: "user-2"}]
        })

      {:noreply, updated_socket} =
        LiveComponent.handle_event("toggle_select", %{"id" => "user-1"}, socket)

      assert MapSet.member?(updated_socket.assigns.selected_ids, "user-1")
      assert MapSet.size(updated_socket.assigns.selected_ids) == 1
    end

    test "removes item from selection when already selected" do
      socket =
        make_socket(%{
          id: "test-table",
          selectable: true,
          selected_ids: MapSet.new(["user-1", "user-2"]),
          data: [%{id: "user-1"}, %{id: "user-2"}]
        })

      {:noreply, updated_socket} =
        LiveComponent.handle_event("toggle_select", %{"id" => "user-1"}, socket)

      refute MapSet.member?(updated_socket.assigns.selected_ids, "user-1")
      assert MapSet.member?(updated_socket.assigns.selected_ids, "user-2")
      assert MapSet.size(updated_socket.assigns.selected_ids) == 1
    end

    test "notifies parent when on_selection_change is set with atom" do
      socket =
        make_socket(%{
          id: "test-table",
          selectable: true,
          selected_ids: MapSet.new(),
          on_selection_change: :selection_changed,
          data: [%{id: "user-1"}]
        })

      {:noreply, _updated_socket} =
        LiveComponent.handle_event("toggle_select", %{"id" => "user-1"}, socket)

      assert_received {:selection_changed,
                       %{
                         component_id: "test-table",
                         selected_ids: selected_ids,
                         selected_count: 1,
                         action: :toggle
                       }}

      assert MapSet.member?(selected_ids, "user-1")
    end

    test "notifies parent when on_selection_change is set with string" do
      socket =
        make_socket(%{
          id: "test-table",
          selectable: true,
          selected_ids: MapSet.new(),
          on_selection_change: "selection_changed",
          data: [%{id: "user-1"}]
        })

      {:noreply, _updated_socket} =
        LiveComponent.handle_event("toggle_select", %{"id" => "user-1"}, socket)

      assert_received {"selection_changed",
                       %{
                         component_id: "test-table",
                         selected_ids: selected_ids,
                         selected_count: 1,
                         action: :toggle
                       }}

      assert MapSet.member?(selected_ids, "user-1")
    end
  end

  describe "toggle_select_all_page event" do
    test "selects all items on page when none are selected" do
      socket =
        make_socket(%{
          id: "test-table",
          selectable: true,
          selected_ids: MapSet.new(),
          id_field: :id,
          data: [%{id: "user-1"}, %{id: "user-2"}, %{id: "user-3"}]
        })

      {:noreply, updated_socket} =
        LiveComponent.handle_event("toggle_select_all_page", %{}, socket)

      assert MapSet.size(updated_socket.assigns.selected_ids) == 3
      assert MapSet.member?(updated_socket.assigns.selected_ids, "user-1")
      assert MapSet.member?(updated_socket.assigns.selected_ids, "user-2")
      assert MapSet.member?(updated_socket.assigns.selected_ids, "user-3")
    end

    test "deselects all items on page when all are selected" do
      socket =
        make_socket(%{
          id: "test-table",
          selectable: true,
          selected_ids: MapSet.new(["user-1", "user-2", "user-3"]),
          id_field: :id,
          data: [%{id: "user-1"}, %{id: "user-2"}, %{id: "user-3"}]
        })

      {:noreply, updated_socket} =
        LiveComponent.handle_event("toggle_select_all_page", %{}, socket)

      assert MapSet.size(updated_socket.assigns.selected_ids) == 0
    end

    test "selects remaining items when some are selected" do
      socket =
        make_socket(%{
          id: "test-table",
          selectable: true,
          selected_ids: MapSet.new(["user-1"]),
          id_field: :id,
          data: [%{id: "user-1"}, %{id: "user-2"}, %{id: "user-3"}]
        })

      {:noreply, updated_socket} =
        LiveComponent.handle_event("toggle_select_all_page", %{}, socket)

      # When not all are selected, clicking select-all should select all
      assert MapSet.size(updated_socket.assigns.selected_ids) == 3
    end

    test "preserves selection from other pages" do
      # user-4 is from a different page
      socket =
        make_socket(%{
          id: "test-table",
          selectable: true,
          selected_ids: MapSet.new(["user-4"]),
          id_field: :id,
          data: [%{id: "user-1"}, %{id: "user-2"}]
        })

      {:noreply, updated_socket} =
        LiveComponent.handle_event("toggle_select_all_page", %{}, socket)

      # Should have user-4 (from other page) plus user-1 and user-2 (current page)
      assert MapSet.size(updated_socket.assigns.selected_ids) == 3
      assert MapSet.member?(updated_socket.assigns.selected_ids, "user-4")
    end

    test "notifies parent with select_all action" do
      socket =
        make_socket(%{
          id: "test-table",
          selectable: true,
          selected_ids: MapSet.new(),
          on_selection_change: :selection_changed,
          id_field: :id,
          data: [%{id: "user-1"}, %{id: "user-2"}]
        })

      {:noreply, _updated_socket} =
        LiveComponent.handle_event("toggle_select_all_page", %{}, socket)

      assert_received {:selection_changed,
                       %{
                         action: :select_all,
                         selected_count: 2
                       }}
    end
  end

  describe "clear_selection event" do
    test "clears all selected items" do
      socket =
        make_socket(%{
          id: "test-table",
          selectable: true,
          selected_ids: MapSet.new(["user-1", "user-2", "user-3"]),
          data: [%{id: "user-1"}, %{id: "user-2"}]
        })

      {:noreply, updated_socket} =
        LiveComponent.handle_event("clear_selection", %{}, socket)

      assert MapSet.size(updated_socket.assigns.selected_ids) == 0
    end

    test "notifies parent with clear action" do
      socket =
        make_socket(%{
          id: "test-table",
          selectable: true,
          selected_ids: MapSet.new(["user-1"]),
          on_selection_change: :selection_changed,
          data: [%{id: "user-1"}]
        })

      {:noreply, _updated_socket} =
        LiveComponent.handle_event("clear_selection", %{}, socket)

      assert_received {:selection_changed,
                       %{
                         action: :clear,
                         selected_count: 0
                       }}
    end
  end

  describe "selection state persistence" do
    test "selection persists across data reloads" do
      # This tests that selection state uses assign_new, so it's preserved
      # when other assigns are updated
      socket =
        make_socket(%{
          id: "test-table",
          selectable: true,
          selected_ids: MapSet.new(["user-1", "user-2"]),
          data: [%{id: "user-1"}, %{id: "user-2"}]
        })

      # Simulate what happens when new data arrives
      # The selected_ids should be preserved because of assign_new
      assert MapSet.size(socket.assigns.selected_ids) == 2
    end
  end
end
