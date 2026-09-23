defmodule Cinder.UpdateTest do
  use ExUnit.Case, async: true

  alias Cinder.Update

  describe "update_item/4" do
    test "returns socket unchanged (update sent via send_update)" do
      socket = %Phoenix.LiveView.Socket{assigns: %{}}

      result =
        Update.update_item(socket, "test-table", "user-123", fn item ->
          %{item | status: :active}
        end)

      assert result == socket
    end

    test "accepts any ID type" do
      socket = %Phoenix.LiveView.Socket{assigns: %{}}

      # String ID
      result = Update.update_item(socket, "table", "string-id", &Function.identity/1)
      assert result == socket

      # Integer ID
      result = Update.update_item(socket, "table", 123, &Function.identity/1)
      assert result == socket

      # UUID
      result = Update.update_item(socket, "table", Ecto.UUID.generate(), &Function.identity/1)
      assert result == socket
    end
  end

  describe "update_items/4" do
    test "returns socket unchanged (update sent via send_update)" do
      socket = %Phoenix.LiveView.Socket{assigns: %{}}

      result =
        Update.update_items(socket, "test-table", ["id-1", "id-2"], fn item ->
          %{item | active: true}
        end)

      assert result == socket
    end

    test "accepts empty list of IDs" do
      socket = %Phoenix.LiveView.Socket{assigns: %{}}

      result = Update.update_items(socket, "table", [], &Function.identity/1)
      assert result == socket
    end
  end

  describe "remove_item/3" do
    test "sends an in-memory removal update and returns the socket unchanged" do
      socket = %Phoenix.LiveView.Socket{assigns: %{}}

      assert Update.remove_item(socket, "test-table", "user-123") == socket

      assert_receive {:phoenix, :send_update,
                      {{Cinder.LiveComponent, "test-table"},
                       %{id: "test-table", __remove_items__: ["user-123"]}}}
    end

    test "accepts any ID type" do
      socket = %Phoenix.LiveView.Socket{assigns: %{}}

      assert Update.remove_item(socket, "table", 123) == socket
    end
  end

  describe "remove_items/3" do
    test "sends a batch removal update and returns the socket unchanged" do
      socket = %Phoenix.LiveView.Socket{assigns: %{}}

      assert Update.remove_items(socket, "test-table", ["id-1", "id-2"]) == socket

      assert_receive {:phoenix, :send_update,
                      {{Cinder.LiveComponent, "test-table"},
                       %{id: "test-table", __remove_items__: ["id-1", "id-2"]}}}
    end

    test "accepts an empty list of IDs" do
      socket = %Phoenix.LiveView.Socket{assigns: %{}}

      assert Update.remove_items(socket, "table", []) == socket
    end
  end

  describe "deselect_item/3 and deselect_items/3" do
    test "send focused deselection updates and return the socket unchanged" do
      socket = %Phoenix.LiveView.Socket{assigns: %{}}

      assert Update.deselect_item(socket, "test-table", 123) == socket

      assert_receive {:phoenix, :send_update,
                      {{Cinder.LiveComponent, "test-table"},
                       %{id: "test-table", __deselect_items__: [123]}}}

      assert Update.deselect_items(socket, "test-table", ["id-1", "id-2"]) == socket

      assert_receive {:phoenix, :send_update,
                      {{Cinder.LiveComponent, "test-table"},
                       %{id: "test-table", __deselect_items__: ["id-1", "id-2"]}}}
    end

    test "accepts an empty list of IDs" do
      socket = %Phoenix.LiveView.Socket{assigns: %{}}

      assert Update.deselect_items(socket, "table", []) == socket
    end
  end

  describe "update_if_visible/4" do
    test "returns socket unchanged (update sent via send_update)" do
      socket = %Phoenix.LiveView.Socket{assigns: %{}}

      result =
        Update.update_if_visible(socket, "users-table", "user-123", fn item ->
          %{item | status: :updated}
        end)

      # Should return socket (visibility check happens in component)
      assert result == socket
    end

    test "accepts any ID type" do
      socket = %Phoenix.LiveView.Socket{assigns: %{}}

      # String ID
      result = Update.update_if_visible(socket, "table", "string-id", &Function.identity/1)
      assert result == socket

      # Integer ID
      result = Update.update_if_visible(socket, "table", 123, &Function.identity/1)
      assert result == socket

      # UUID
      result =
        Update.update_if_visible(socket, "table", Ecto.UUID.generate(), &Function.identity/1)

      assert result == socket
    end
  end

  describe "update_items_if_visible/4" do
    test "returns socket unchanged (update sent via send_update)" do
      socket = %Phoenix.LiveView.Socket{assigns: %{}}

      result =
        Update.update_items_if_visible(
          socket,
          "users-table",
          ["user-1", "user-2", "user-3"],
          fn item -> %{item | batch_updated: true} end
        )

      # Should return socket (visibility check happens in component)
      assert result == socket
    end

    test "accepts empty list of IDs" do
      socket = %Phoenix.LiveView.Socket{assigns: %{}}

      result = Update.update_items_if_visible(socket, "table", [], &Function.identity/1)
      assert result == socket
    end
  end

  describe "delegated functions from Cinder.Refresh" do
    test "Cinder.Refresh delegates update_item/4" do
      socket = %Phoenix.LiveView.Socket{assigns: %{}}

      result = Cinder.Refresh.update_item(socket, "table", "id", &Function.identity/1)
      assert result == socket
    end

    test "Cinder.Refresh delegates update_items/4" do
      socket = %Phoenix.LiveView.Socket{assigns: %{}}

      result = Cinder.Refresh.update_items(socket, "table", ["id"], &Function.identity/1)
      assert result == socket
    end

    test "Cinder.Refresh delegates update_if_visible/4" do
      socket = %Phoenix.LiveView.Socket{assigns: %{}}

      result = Cinder.Refresh.update_if_visible(socket, "table", "id", &Function.identity/1)
      assert result == socket
    end

    test "Cinder.Refresh delegates update_items_if_visible/4" do
      socket = %Phoenix.LiveView.Socket{assigns: %{}}

      result =
        Cinder.Refresh.update_items_if_visible(socket, "table", ["id"], &Function.identity/1)

      assert result == socket
    end

    test "Cinder.Refresh delegates removal functions" do
      socket = %Phoenix.LiveView.Socket{assigns: %{}}

      assert Cinder.Refresh.remove_item(socket, "table", "id") == socket
      assert Cinder.Refresh.remove_items(socket, "table", ["id"]) == socket
    end

    test "Cinder.Refresh delegates deselection functions" do
      socket = %Phoenix.LiveView.Socket{assigns: %{}}

      assert Cinder.Refresh.deselect_item(socket, "table", "id") == socket
      assert Cinder.Refresh.deselect_items(socket, "table", ["id"]) == socket
    end
  end

  describe "delegated functions from main Cinder module" do
    test "Cinder delegates update_item/4" do
      socket = %Phoenix.LiveView.Socket{assigns: %{}}

      result = Cinder.update_item(socket, "table", "id", &Function.identity/1)
      assert result == socket
    end

    test "Cinder delegates update_items/4" do
      socket = %Phoenix.LiveView.Socket{assigns: %{}}

      result = Cinder.update_items(socket, "table", ["id"], &Function.identity/1)
      assert result == socket
    end

    test "Cinder delegates update_if_visible/4" do
      socket = %Phoenix.LiveView.Socket{assigns: %{}}

      result = Cinder.update_if_visible(socket, "table", "id", &Function.identity/1)
      assert result == socket
    end

    test "Cinder delegates update_items_if_visible/4" do
      socket = %Phoenix.LiveView.Socket{assigns: %{}}

      result = Cinder.update_items_if_visible(socket, "table", ["id"], &Function.identity/1)
      assert result == socket
    end

    test "Cinder delegates removal functions" do
      socket = %Phoenix.LiveView.Socket{assigns: %{}}

      assert Cinder.remove_item(socket, "table", "id") == socket
      assert Cinder.remove_items(socket, "table", ["id"]) == socket
    end

    test "Cinder delegates deselection functions" do
      socket = %Phoenix.LiveView.Socket{assigns: %{}}

      assert Cinder.deselect_item(socket, "table", "id") == socket
      assert Cinder.deselect_items(socket, "table", ["id"]) == socket
    end
  end
end
