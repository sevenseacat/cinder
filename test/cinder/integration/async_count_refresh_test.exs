defmodule Cinder.Integration.AsyncCountRefreshTest do
  use ExUnit.Case, async: false

  alias Cinder.LiveComponent
  alias Cinder.Support.SearchTestResource

  # Run reads deterministically while exercising the :async count cache policy.
  setup {Cinder.TestHelpers, :disable_async_loading}

  for refresh <- [:update, :event] do
    test "#{refresh} refresh recalculates an async count after an insert" do
      create_item("First")
      socket = collection_socket()
      assert socket.assigns.total_count == 1

      create_item("Second")

      socket =
        case unquote(refresh) do
          :update ->
            {:ok, refreshed} = LiveComponent.update(%{refresh: true}, socket)
            refreshed

          :event ->
            {:noreply, refreshed} = LiveComponent.handle_event("refresh", %{}, socket)
            refreshed
        end

      assert length(socket.assigns.data) == 2
      assert socket.assigns.total_count == 2
    end
  end

  test "a successful bulk destroy recalculates the async count" do
    deleted = create_item("Delete me")
    retained = create_item("Keep me")
    socket = collection_socket()
    assert socket.assigns.total_count == 2

    socket = Phoenix.Component.assign(socket, :selected_ids, MapSet.new([deleted.id]))

    assert {:noreply, socket} =
             LiveComponent.handle_event("bulk_action_execute", %{"index" => 0}, socket)

    assert Enum.map(socket.assigns.data, & &1.id) == [retained.id]
    assert socket.assigns.total_count == 1
  end

  test "navigation reuses the count for an unchanged query" do
    create_item("First")
    socket = collection_socket()
    assert socket.assigns.total_count == 1

    create_item("Second")
    {:noreply, socket} = LiveComponent.handle_event("goto_page", %{"page" => "1"}, socket)

    assert length(socket.assigns.data) == 2
    assert socket.assigns.total_count == 1
  end

  test "refresh invalidates a pending count so its late result cannot overwrite the new total" do
    create_item("First")
    socket = collection_socket()
    old_attempt = make_ref()
    socket = Phoenix.Component.assign(socket, total_count: nil, count_attempt: old_attempt)
    create_item("Second")

    {:ok, socket} = LiveComponent.update(%{refresh: true}, socket)
    assert socket.assigns.total_count == 2

    {:noreply, socket} =
      LiveComponent.handle_async({:load_count, old_attempt}, {:ok, {:ok, 1}}, socket)

    assert socket.assigns.total_count == 2
  end

  defp collection_socket do
    {:ok, socket} =
      LiveComponent.update(
        %{
          id: "async-count",
          query: SearchTestResource,
          actor: nil,
          tenant: nil,
          query_opts: [authorize?: false],
          col: [],
          search_fn: nil,
          pagination_mode: :offset,
          count_mode: :async,
          selectable: true,
          bulk_action_slots: [%{action: :destroy, action_opts: [authorize?: false]}]
        },
        %Phoenix.LiveView.Socket{}
      )

    socket
  end

  defp create_item(title) do
    SearchTestResource
    |> Ash.Changeset.for_create(:create, %{title: title})
    |> Ash.create!(authorize?: false)
  end
end
