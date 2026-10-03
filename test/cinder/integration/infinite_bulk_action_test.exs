defmodule Cinder.Integration.InfiniteBulkActionTest do
  use ExUnit.Case, async: false

  alias Cinder.LiveComponent
  alias Cinder.Support.SearchTestResource

  setup {Cinder.TestHelpers, :disable_async_loading}

  test "a successful bulk destroy replaces the infinite stream without deleted rows" do
    deleted = create_item("Delete me")
    retained = create_item("Keep me")

    {:ok, socket} =
      LiveComponent.update(
        %{
          id: "infinite-bulk",
          query: SearchTestResource,
          actor: nil,
          tenant: nil,
          query_opts: [authorize?: false],
          col: [],
          search_fn: nil,
          pagination_mode: :infinite,
          count_mode: false,
          infinite_load: :manual,
          selectable: true,
          bulk_action_slots: [%{action: :destroy, action_opts: [authorize?: false]}]
        },
        %Phoenix.LiveView.Socket{private: %{lifecycle: %Phoenix.LiveView.Lifecycle{}}}
      )

    assert socket.assigns.infinite_item_ids == MapSet.new([deleted.id, retained.id])

    # Discard the first render's pending inserts so assertions inspect only the reload.
    socket = Phoenix.Component.assign(socket, :selected_ids, MapSet.new([deleted.id]))

    socket =
      put_in(
        socket.assigns.streams.items,
        Phoenix.LiveView.LiveStream.prune(socket.assigns.streams.items)
      )

    assert {:noreply, socket} =
             LiveComponent.handle_event("bulk_action_execute", %{"index" => 0}, socket)

    assert Enum.map(Ash.read!(SearchTestResource, authorize?: false), & &1.id) == [retained.id]
    assert socket.assigns.infinite_item_ids == MapSet.new([retained.id])
    assert socket.assigns.infinite_loaded_count == 1
    assert socket.assigns.streams.items.reset?
    assert [insert] = socket.assigns.streams.items.inserts
    %{id: id} = elem(insert, 2)
    assert id == retained.id
  end

  defp create_item(title) do
    SearchTestResource
    |> Ash.Changeset.for_create(:create, %{title: title})
    |> Ash.create!(authorize?: false)
  end
end
