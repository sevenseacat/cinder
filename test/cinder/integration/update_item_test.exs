defmodule Cinder.Integration.UpdateItemTest do
  @moduledoc """
  Integration tests for in-memory item updates via Cinder.Update.

  These tests verify that the LiveComponent correctly applies update functions
  to items in its data without triggering a full re-query.
  """

  use ExUnit.Case, async: true

  alias Cinder.LiveComponent

  # Helper to create a properly structured socket for testing
  defp make_socket(assigns) do
    %Phoenix.LiveView.Socket{
      assigns: Map.merge(%{__changed__: %{}}, assigns)
    }
  end

  defp make_infinite_socket(overrides \\ %{}) do
    assigns = %{
      id: "products",
      id_field: :id,
      data: [],
      pagination_mode: :infinite,
      selectable: & &1.selectable?,
      infinite_item_ids: MapSet.new(["1", "2"]),
      infinite_selectable_ids: MapSet.new(["1", "2"]),
      infinite_pages: [
        %{
          page: 4,
          items: [
            %{id: "1", keyset: "cursor-1", number: 7, selectable?: true},
            %{id: "2", keyset: "cursor-2", number: 8, selectable?: true}
          ],
          ids: ["1", "2"],
          selectable_ids: ["1", "2"],
          first_keyset: "cursor-1",
          last_keyset: "cursor-2"
        }
      ]
    }

    socket = %Phoenix.LiveView.Socket{
      assigns: assigns |> Map.merge(overrides) |> Map.put(:__changed__, %{}),
      private: %{lifecycle: %Phoenix.LiveView.Lifecycle{}}
    }

    Phoenix.LiveView.stream_configure(socket, :items, dom_id: &"products-item-#{&1.id}")
  end

  describe "LiveComponent update/2 with __update_item__" do
    test "updates a single item by ID" do
      # Simulate existing socket state with data
      socket =
        make_socket(%{
          id_field: :id,
          data: [
            %{id: "user-1", name: "Alice", status: :inactive},
            %{id: "user-2", name: "Bob", status: :inactive},
            %{id: "user-3", name: "Charlie", status: :inactive}
          ]
        })

      # Simulate the update assign that would be sent via send_update
      assigns = %{
        __update_item__: {"user-2", fn item -> %{item | status: :active} end}
      }

      {:ok, updated_socket} = LiveComponent.update(assigns, socket)

      assert updated_socket.assigns.data == [
               %{id: "user-1", name: "Alice", status: :inactive},
               %{id: "user-2", name: "Bob", status: :active},
               %{id: "user-3", name: "Charlie", status: :inactive}
             ]
    end

    test "leaves data unchanged when ID not found" do
      socket =
        make_socket(%{
          id_field: :id,
          data: [
            %{id: "user-1", name: "Alice"}
          ]
        })

      assigns = %{
        __update_item__: {"nonexistent-id", fn item -> %{item | name: "Modified"} end}
      }

      {:ok, updated_socket} = LiveComponent.update(assigns, socket)

      assert updated_socket.assigns.data == [
               %{id: "user-1", name: "Alice"}
             ]
    end

    test "works with custom id_field" do
      socket =
        make_socket(%{
          id_field: :uuid,
          data: [
            %{uuid: "abc-123", name: "Item 1", count: 0},
            %{uuid: "def-456", name: "Item 2", count: 0}
          ]
        })

      assigns = %{
        __update_item__: {"abc-123", fn item -> %{item | count: item.count + 1} end}
      }

      {:ok, updated_socket} = LiveComponent.update(assigns, socket)

      assert updated_socket.assigns.data == [
               %{uuid: "abc-123", name: "Item 1", count: 1},
               %{uuid: "def-456", name: "Item 2", count: 0}
             ]
    end

    test "defaults to :id when id_field not set" do
      socket =
        make_socket(%{
          data: [
            %{id: 1, value: "old"}
          ]
        })

      assigns = %{
        __update_item__: {1, fn item -> %{item | value: "new"} end}
      }

      {:ok, updated_socket} = LiveComponent.update(assigns, socket)

      assert updated_socket.assigns.data == [
               %{id: 1, value: "new"}
             ]
    end

    test "handles empty data list" do
      socket =
        make_socket(%{
          id_field: :id,
          data: []
        })

      assigns = %{
        __update_item__: {"any-id", fn item -> %{item | changed: true} end}
      }

      {:ok, updated_socket} = LiveComponent.update(assigns, socket)

      assert updated_socket.assigns.data == []
    end

    test "handles nil data" do
      socket =
        make_socket(%{
          id_field: :id,
          data: nil
        })

      assigns = %{
        __update_item__: {"any-id", fn item -> %{item | changed: true} end}
      }

      {:ok, updated_socket} = LiveComponent.update(assigns, socket)

      assert updated_socket.assigns.data == []
    end

    test "only updates data without processing other assigns" do
      # __update_item__ is a focused operation that ONLY updates :data
      # It should not process any other assigns to avoid triggering reloads
      socket =
        make_socket(%{
          id_field: :id,
          data: [%{id: 1, value: "test"}]
        })

      assigns = %{
        __update_item__: {1, fn item -> %{item | value: "updated"} end},
        other_assign: "should_be_ignored"
      }

      {:ok, updated_socket} = LiveComponent.update(assigns, socket)

      # Data should be updated
      assert updated_socket.assigns.data == [%{id: 1, value: "updated"}]
      # Other assigns should NOT be applied (focused operation)
      refute Map.has_key?(updated_socket.assigns, :other_assign)
      refute Map.has_key?(updated_socket.assigns, :__update_item__)
    end
  end

  describe "LiveComponent update/2 with __update_items__" do
    test "updates multiple items by their IDs" do
      socket =
        make_socket(%{
          id_field: :id,
          data: [
            %{id: "a", selected: false},
            %{id: "b", selected: false},
            %{id: "c", selected: false},
            %{id: "d", selected: false}
          ]
        })

      assigns = %{
        __update_items__: {["a", "c"], fn item -> %{item | selected: true} end}
      }

      {:ok, updated_socket} = LiveComponent.update(assigns, socket)

      assert updated_socket.assigns.data == [
               %{id: "a", selected: true},
               %{id: "b", selected: false},
               %{id: "c", selected: true},
               %{id: "d", selected: false}
             ]
    end

    test "handles empty ID list" do
      socket =
        make_socket(%{
          id_field: :id,
          data: [%{id: 1, value: "unchanged"}]
        })

      assigns = %{
        __update_items__: {[], fn item -> %{item | value: "changed"} end}
      }

      {:ok, updated_socket} = LiveComponent.update(assigns, socket)

      assert updated_socket.assigns.data == [
               %{id: 1, value: "unchanged"}
             ]
    end

    test "ignores IDs not present in data" do
      socket =
        make_socket(%{
          id_field: :id,
          data: [
            %{id: 1, status: :pending},
            %{id: 2, status: :pending}
          ]
        })

      # ID 3 doesn't exist in data
      assigns = %{
        __update_items__: {[1, 3], fn item -> %{item | status: :done} end}
      }

      {:ok, updated_socket} = LiveComponent.update(assigns, socket)

      assert updated_socket.assigns.data == [
               %{id: 1, status: :done},
               %{id: 2, status: :pending}
             ]
    end

    test "works with integer IDs" do
      socket =
        make_socket(%{
          id_field: :id,
          data: [
            %{id: 1, count: 0},
            %{id: 2, count: 0},
            %{id: 3, count: 0}
          ]
        })

      assigns = %{
        __update_items__: {[1, 3], fn item -> %{item | count: 99} end}
      }

      {:ok, updated_socket} = LiveComponent.update(assigns, socket)

      assert Enum.map(updated_socket.assigns.data, & &1.count) == [99, 0, 99]
    end

    test "strips __update_items__ from assigns after processing" do
      socket =
        make_socket(%{
          id_field: :id,
          data: [%{id: 1}]
        })

      assigns = %{
        __update_items__: {[1], fn item -> item end}
      }

      {:ok, updated_socket} = LiveComponent.update(assigns, socket)

      refute Map.has_key?(updated_socket.assigns, :__update_items__)
    end
  end

  describe "LiveComponent update/2 with __update_item_if_visible__" do
    test "updates item when it exists in data" do
      socket =
        make_socket(%{
          id_field: :id,
          data: [
            %{id: "user-1", name: "Alice", status: :inactive},
            %{id: "user-2", name: "Bob", status: :inactive}
          ]
        })

      assigns = %{
        __update_item_if_visible__: {"user-2", fn item -> %{item | status: :active} end}
      }

      {:ok, updated_socket} = LiveComponent.update(assigns, socket)

      assert updated_socket.assigns.data == [
               %{id: "user-1", name: "Alice", status: :inactive},
               %{id: "user-2", name: "Bob", status: :active}
             ]
    end

    test "does nothing when item is not in data" do
      socket =
        make_socket(%{
          id_field: :id,
          data: [
            %{id: "user-1", name: "Alice"}
          ]
        })

      assigns = %{
        __update_item_if_visible__:
          {"user-999", fn item -> %{item | name: "Should not happen"} end}
      }

      {:ok, updated_socket} = LiveComponent.update(assigns, socket)

      # Data should be unchanged
      assert updated_socket.assigns.data == [
               %{id: "user-1", name: "Alice"}
             ]
    end

    test "works with custom id_field" do
      socket =
        make_socket(%{
          id_field: :uuid,
          data: [
            %{uuid: "abc-123", count: 0}
          ]
        })

      assigns = %{
        __update_item_if_visible__: {"abc-123", fn item -> %{item | count: 1} end}
      }

      {:ok, updated_socket} = LiveComponent.update(assigns, socket)

      assert updated_socket.assigns.data == [%{uuid: "abc-123", count: 1}]
    end

    test "handles empty data list gracefully" do
      socket =
        make_socket(%{
          id_field: :id,
          data: []
        })

      assigns = %{
        __update_item_if_visible__: {"any-id", fn item -> %{item | changed: true} end}
      }

      {:ok, updated_socket} = LiveComponent.update(assigns, socket)

      assert updated_socket.assigns.data == []
    end

    test "accepts raw item instead of ID and passes it to update function" do
      socket =
        make_socket(%{
          id_field: :id,
          data: [
            %{id: "user-1", name: "Alice", status: :stale},
            %{id: "user-2", name: "Bob", status: :stale}
          ]
        })

      # Pass a raw item (like from PubSub) instead of just an ID
      raw_item = %{id: "user-1", name: "Alice Updated", status: :fresh, extra: "new_field"}

      assigns = %{
        __update_item_if_visible__:
          {raw_item,
           fn item ->
             # The update function receives the raw item, not the table's existing item
             assert item == raw_item
             item
           end}
      }

      {:ok, updated_socket} = LiveComponent.update(assigns, socket)

      # The raw item replaces the existing one
      assert updated_socket.assigns.data == [
               %{id: "user-1", name: "Alice Updated", status: :fresh, extra: "new_field"},
               %{id: "user-2", name: "Bob", status: :stale}
             ]
    end

    test "raw item update does nothing when item ID is not visible" do
      socket =
        make_socket(%{
          id_field: :id,
          data: [
            %{id: "user-1", name: "Alice"}
          ]
        })

      # Raw item with ID that doesn't exist in table
      raw_item = %{id: "user-999", name: "Ghost"}

      update_called = :ets.new(:update_called, [:set, :public])
      :ets.insert(update_called, {:called, false})

      assigns = %{
        __update_item_if_visible__:
          {raw_item,
           fn item ->
             :ets.insert(update_called, {:called, true})
             item
           end}
      }

      {:ok, updated_socket} = LiveComponent.update(assigns, socket)

      # Update function should NOT have been called
      assert :ets.lookup(update_called, :called) == [{:called, false}]
      :ets.delete(update_called)

      # Data unchanged
      assert updated_socket.assigns.data == [%{id: "user-1", name: "Alice"}]
    end

    test "raw item works with custom id_field" do
      socket =
        make_socket(%{
          id_field: :uuid,
          data: [
            %{uuid: "abc-123", value: "old"}
          ]
        })

      raw_item = %{uuid: "abc-123", value: "new", loaded: true}

      assigns = %{
        __update_item_if_visible__: {raw_item, fn item -> item end}
      }

      {:ok, updated_socket} = LiveComponent.update(assigns, socket)

      assert updated_socket.assigns.data == [%{uuid: "abc-123", value: "new", loaded: true}]
    end

    test "updates a visible infinite-stream row from a raw incoming record" do
      socket = make_infinite_socket()
      raw_item = %{id: 2, name: "Fresh", selectable?: false}

      assigns = %{
        __update_item_if_visible__: {raw_item, &Map.put(&1, :loaded?, true)}
      }

      {:ok, updated_socket} = LiveComponent.update(assigns, socket)

      assert updated_socket.assigns.data == []
      assert updated_socket.assigns.infinite_item_ids == MapSet.new(["1", "2"])
      assert updated_socket.assigns.infinite_selectable_ids == MapSet.new(["1"])

      [page] = updated_socket.assigns.infinite_pages

      assert Enum.map(page.items, &Map.take(&1, [:id, :number, :keyset])) == [
               %{id: "1", number: 7, keyset: "cursor-1"},
               %{id: "2", number: 8, keyset: "cursor-2"}
             ]

      assert [{"products-item-2", -1, entry, nil, nil}] =
               updated_socket.assigns.streams.items.inserts

      assert entry == %{
               id: "2",
               number: 8,
               keyset: "cursor-2",
               selectable?: false,
               record: %{id: 2, name: "Fresh", selectable?: false, loaded?: true}
             }
    end

    test "does not invoke a raw notification callback for a pruned infinite row" do
      socket = make_infinite_socket()

      assigns = %{
        __update_item_if_visible__:
          {%{id: 99, name: "Not visible", selectable?: true},
           fn _ ->
             flunk("update callback must not run for a row outside the stream window")
           end}
      }

      {:ok, updated_socket} = LiveComponent.update(assigns, socket)

      refute Map.has_key?(updated_socket.assigns.streams, :items)
      assert updated_socket.assigns.infinite_item_ids == MapSet.new(["1", "2"])
    end

    test "keeps ID-only updates as a no-op because stream records are not retained" do
      socket = make_infinite_socket()

      assigns = %{
        __update_item_if_visible__: {"2", fn _ -> flunk("there is no retained record") end}
      }

      {:ok, updated_socket} = LiveComponent.update(assigns, socket)

      refute Map.has_key?(updated_socket.assigns.streams, :items)
    end

    test "rejects notification transforms that change the streamed identity" do
      socket = make_infinite_socket()

      assigns = %{
        __update_item_if_visible__: {%{id: 2, selectable?: true}, fn item -> %{item | id: 3} end}
      }

      assert_raise ArgumentError, ~r/must preserve the :id field/, fn ->
        LiveComponent.update(assigns, socket)
      end
    end
  end

  describe "LiveComponent update/2 with __update_items_if_visible__" do
    test "updates only items that exist in data" do
      socket =
        make_socket(%{
          id_field: :id,
          data: [
            %{id: "a", selected: false},
            %{id: "b", selected: false},
            %{id: "c", selected: false}
          ]
        })

      # Include IDs that exist and don't exist
      # update_fn receives a list and returns a list
      assigns = %{
        __update_items_if_visible__:
          {["a", "c", "z"], fn items -> Enum.map(items, &%{&1 | selected: true}) end}
      }

      {:ok, updated_socket} = LiveComponent.update(assigns, socket)

      assert updated_socket.assigns.data == [
               %{id: "a", selected: true},
               %{id: "b", selected: false},
               %{id: "c", selected: true}
             ]
    end

    test "does nothing when no IDs are in data" do
      socket =
        make_socket(%{
          id_field: :id,
          data: [
            %{id: "user-1", value: "original"}
          ]
        })

      assigns = %{
        __update_items_if_visible__:
          {["user-99", "user-100"], fn items -> Enum.map(items, &%{&1 | value: "changed"}) end}
      }

      {:ok, updated_socket} = LiveComponent.update(assigns, socket)

      assert updated_socket.assigns.data == [
               %{id: "user-1", value: "original"}
             ]
    end

    test "handles empty ID list" do
      socket =
        make_socket(%{
          id_field: :id,
          data: [%{id: 1, value: "test"}]
        })

      assigns = %{
        __update_items_if_visible__:
          {[], fn items -> Enum.map(items, &%{&1 | value: "changed"}) end}
      }

      {:ok, updated_socket} = LiveComponent.update(assigns, socket)

      # No changes when empty list
      assert updated_socket.assigns.data == [%{id: 1, value: "test"}]
    end

    test "batch-updates only raw incoming records in the infinite window" do
      socket = make_infinite_socket()

      raw_items = [
        %{id: 2, name: "Two", selectable?: true},
        %{id: 3, name: "Pruned", selectable?: true},
        %{id: 1, name: "One", selectable?: true}
      ]

      assigns = %{
        __update_items_if_visible__:
          {raw_items,
           fn visible ->
             assert Enum.map(visible, & &1.id) == [1, 2]
             Enum.map(visible, &Map.put(&1, :loaded?, true))
           end}
      }

      {:ok, updated_socket} = LiveComponent.update(assigns, socket)

      assert updated_socket.assigns.data == []

      assert Enum.map(updated_socket.assigns.infinite_pages, & &1.items) == [
               [
                 %{id: "1", keyset: "cursor-1", number: 7, selectable?: true},
                 %{id: "2", keyset: "cursor-2", number: 8, selectable?: true}
               ]
             ]

      assert updated_socket.assigns.streams.items.inserts
             |> Enum.map(fn {dom_id, _at, entry, _limit, _update_only} ->
               {dom_id, entry.number, entry.record.loaded?}
             end)
             |> Enum.sort() == [
               {"products-item-1", 7, true},
               {"products-item-2", 8, true}
             ]
    end
  end

  describe "update function behavior" do
    test "update function can modify multiple fields" do
      socket =
        make_socket(%{
          id_field: :id,
          data: [
            %{id: 1, name: "Old", status: :draft, updated_at: nil}
          ]
        })

      now = DateTime.utc_now()

      assigns = %{
        __update_item__:
          {1,
           fn item ->
             %{item | name: "New", status: :published, updated_at: now}
           end}
      }

      {:ok, updated_socket} = LiveComponent.update(assigns, socket)

      [updated_item] = updated_socket.assigns.data
      assert updated_item.name == "New"
      assert updated_item.status == :published
      assert updated_item.updated_at == now
    end

    test "update function receives the full item" do
      socket =
        make_socket(%{
          id_field: :id,
          data: [
            %{id: 1, a: 1, b: 2, c: 3}
          ]
        })

      assigns = %{
        __update_item__:
          {1,
           fn item ->
             # Verify we have access to all fields
             %{item | c: item.a + item.b}
           end}
      }

      {:ok, updated_socket} = LiveComponent.update(assigns, socket)

      [item] = updated_socket.assigns.data
      # 1 + 2
      assert item.c == 3
    end
  end
end
