defmodule Cinder.Integration.InfiniteCursorRestoreTest do
  use ExUnit.Case, async: false
  alias Cinder.LiveComponent
  alias Cinder.Support.SearchTestResource

  setup {Cinder.TestHelpers, :disable_async_loading}

  test "restoring the final batch keeps earlier records reachable" do
    socket = first_page()
    first_ids = socket.assigns.infinite_item_ids
    restored = collection(%{"after" => socket.assigns.last_keyset})

    refute restored.assigns.infinite_item_ids == first_ids
    refute restored.assigns.infinite_has_next
    assert restored.assigns.infinite_has_previous
    {:noreply, previous} = LiveComponent.handle_event("load_previous", %{}, restored)
    assert MapSet.subset?(first_ids, previous.assigns.infinite_item_ids)
  end

  test "restoring a before cursor keeps later records reachable" do
    first = first_page()
    last = collection(%{"after" => first.assigns.last_keyset})
    restored = collection(%{"before" => last.assigns.first_keyset})

    assert restored.assigns.infinite_item_ids == first.assigns.infinite_item_ids
    refute restored.assigns.infinite_has_previous
    assert restored.assigns.infinite_has_next
    {:noreply, next} = LiveComponent.handle_event("load_more", %{}, restored)
    assert MapSet.subset?(last.assigns.infinite_item_ids, next.assigns.infinite_item_ids)
  end

  defp first_page do
    for title <- ["First", "Second"] do
      SearchTestResource
      |> Ash.Changeset.for_create(:create, %{title: title})
      |> Ash.create!(authorize?: false)
    end

    collection(%{})
  end

  defp collection(params) do
    {:ok, socket} =
      LiveComponent.update(
        %{
          id: "restore",
          query: SearchTestResource,
          actor: nil,
          tenant: nil,
          query_opts: [authorize?: false],
          col: [],
          search_fn: nil,
          pagination_mode: :infinite,
          count_mode: false,
          page_size: 1,
          infinite_load: :manual,
          url_raw_params: params
        },
        %Phoenix.LiveView.Socket{}
      )

    socket
  end
end
