defmodule Cinder.Integration.AsyncCountRefreshTest do
  use ExUnit.Case, async: false

  alias Cinder.LiveComponent
  alias Cinder.Support.SearchTestResource

  # Run reads, and the async count, inline so the tests are deterministic.
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

  # The count isn't cached yet, so even navigating within the same query recounts
  test "navigation recounts" do
    create_item("First")
    socket = collection_socket()
    assert socket.assigns.total_count == 1

    create_item("Second")
    {:noreply, socket} = LiveComponent.handle_event("goto_page", %{"page" => "1"}, socket)

    assert length(socket.assigns.data) == 2
    assert socket.assigns.total_count == 2
  end

  test "on_query_change is notified again once the count arrives" do
    create_item("First")
    collection_socket(on_query_change: :query_changed)

    assert_received {:query_changed, %{count: nil, query: %Ash.Query{} = query}}
    assert_received {:query_changed, %{count: 1, query: ^query}}
  end

  test "a failed count tells the controls, until the collection counts again" do
    create_item("First")
    socket = collection_socket()

    log =
      ExUnit.CaptureLog.capture_log(fn ->
        {:noreply, socket} =
          LiveComponent.handle_async(:load_count, {:exit, :database_unavailable}, socket)

        send(self(), {:socket, socket})
      end)

    assert_received {:socket, socket}
    assert log =~ "Cinder count query failed: :database_unavailable"
    assert socket.assigns.count_failed?

    {:ok, socket} = LiveComponent.update(%{refresh: true}, socket)
    refute socket.assigns.count_failed?
    assert socket.assigns.total_count == 1
  end

  defp collection_socket(extra_assigns \\ []) do
    {:ok, socket} =
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
      }
      |> Map.merge(Map.new(extra_assigns))
      |> LiveComponent.update(%Phoenix.LiveView.Socket{})

    socket
  end

  defp create_item(title) do
    SearchTestResource
    |> Ash.Changeset.for_create(:create, %{title: title})
    |> Ash.create!(authorize?: false)
  end
end
