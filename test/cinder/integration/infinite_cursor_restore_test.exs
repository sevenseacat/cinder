defmodule Cinder.Integration.InfiniteCursorRestoreTest do
  use ExUnit.Case, async: false
  use Mimic
  alias Cinder.LiveComponent
  alias Cinder.Support.SearchTestResource

  require Ash.Query

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

  test "a new query starts the stream over instead of keeping the old rows" do
    {:noreply, both} = LiveComponent.handle_event("load_more", %{}, first_page())
    assert MapSet.size(both.assigns.infinite_item_ids) == 2

    second = Ash.Query.filter(SearchTestResource, title == "Second")
    {:ok, narrowed} = LiveComponent.update(%{query: second}, both)

    [record] = Ash.read!(second, authorize?: false)
    assert narrowed.assigns.infinite_item_ids == MapSet.new([to_string(record.id)])
  end

  test "a new layout starts the stream over, as its container has none of the rows streamed" do
    {:noreply, both} = LiveComponent.handle_event("load_more", %{}, first_page())
    assert MapSet.size(both.assigns.infinite_item_ids) == 2

    {:ok, regridded} = LiveComponent.update(%{renderer: Cinder.Renderers.Grid}, both)

    assert regridded.assigns.current_page == 1
    assert MapSet.size(regridded.assigns.infinite_item_ids) == 1
  end

  test "an emitted URL round trip preserves the batch and does not read again" do
    socket = first_page()
    socket = Phoenix.Component.assign(socket, :on_state_change, :collection_state)
    {:noreply, appended} = LiveComponent.handle_event("load_more", %{}, socket)
    assert_receive {:collection_state, "restore", params}
    params = Map.new(params, fn {key, value} -> {to_string(key), value} end)
    assert appended.assigns.current_page == 2

    reject(&Ash.read/2)
    {:ok, echoed} = LiveComponent.update(%{url_raw_params: params}, appended)
    assert echoed.assigns.current_page == 2
    assert echoed.assigns.infinite_pages == appended.assigns.infinite_pages
    assert echoed.assigns.infinite_item_ids == appended.assigns.infinite_item_ids
  end

  test "an in-flight batch keeps its ordinal when its URL returns" do
    socket = first_page()

    in_flight =
      Phoenix.Component.assign(socket,
        current_page: 2,
        after_keyset: socket.assigns.last_keyset,
        loading: true,
        infinite_append?: true
      )

    reject(&Ash.read/2)

    {:ok, echoed} =
      LiveComponent.update(
        %{url_raw_params: %{"after" => in_flight.assigns.after_keyset}},
        in_flight
      )

    assert echoed.assigns.current_page == 2
    assert echoed.assigns.loading
    assert echoed.assigns.infinite_append?
  end

  test "removing a cursor returns to the first batch" do
    first = first_page()
    {:noreply, appended} = LiveComponent.handle_event("load_more", %{}, first)
    {:ok, restored} = LiveComponent.update(%{url_raw_params: %{}}, appended)

    assert restored.assigns.current_page == 1
    assert restored.assigns.after_keyset == nil
    assert restored.assigns.before_keyset == nil
    assert restored.assigns.infinite_item_ids == first.assigns.infinite_item_ids
  end

  test "switching cursor direction clears the previous cursor" do
    first = first_page()
    {:noreply, appended} = LiveComponent.handle_event("load_more", %{}, first)
    last = List.last(appended.assigns.infinite_pages)

    {:ok, restored} =
      LiveComponent.update(%{url_raw_params: %{"before" => last.first_keyset}}, appended)

    assert restored.assigns.current_page == 1
    assert restored.assigns.after_keyset == nil
    assert restored.assigns.before_keyset == last.first_keyset
    assert restored.assigns.infinite_item_ids == first.assigns.infinite_item_ids
  end

  test "a URL echo after window pruning keeps the surviving batches" do
    for title <- ["One", "Two", "Three", "Four"] do
      SearchTestResource
      |> Ash.Changeset.for_create(:create, %{title: title})
      |> Ash.create!(authorize?: false)
    end

    socket = collection(%{}, window_size: 2)
    {:noreply, second} = LiveComponent.handle_event("load_more", %{}, socket)
    {:noreply, third} = LiveComponent.handle_event("load_more", %{}, second)
    assert Enum.map(third.assigns.infinite_pages, & &1.page) == [2, 3]

    reject(&Ash.read/2)

    {:ok, echoed} =
      LiveComponent.update(%{url_raw_params: %{"after" => third.assigns.after_keyset}}, third)

    assert echoed.assigns.infinite_pages == third.assigns.infinite_pages
    assert echoed.assigns.infinite_item_ids == third.assigns.infinite_item_ids
  end

  defp first_page do
    for title <- ["First", "Second"] do
      SearchTestResource
      |> Ash.Changeset.for_create(:create, %{title: title})
      |> Ash.create!(authorize?: false)
    end

    collection(%{})
  end

  defp collection(params, opts \\ []) do
    {:ok, socket} =
      LiveComponent.update(
        Map.merge(
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
          Map.new(opts)
        ),
        %Phoenix.LiveView.Socket{}
      )

    socket
  end
end
