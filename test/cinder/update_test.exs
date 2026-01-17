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

    test "requires collection_id to be binary" do
      socket = %Phoenix.LiveView.Socket{assigns: %{}}

      assert_raise FunctionClauseError, fn ->
        Update.update_item(socket, :not_a_string, "id", &Function.identity/1)
      end
    end

    test "requires update_fn to be arity-1 function" do
      socket = %Phoenix.LiveView.Socket{assigns: %{}}

      assert_raise FunctionClauseError, fn ->
        Update.update_item(socket, "table", "id", fn _a, _b -> :ok end)
      end
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

    test "requires ids to be a list" do
      socket = %Phoenix.LiveView.Socket{assigns: %{}}

      assert_raise FunctionClauseError, fn ->
        Update.update_items(socket, "table", "not-a-list", &Function.identity/1)
      end
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

    test "requires collection_id to be binary" do
      socket = %Phoenix.LiveView.Socket{assigns: %{}}

      assert_raise FunctionClauseError, fn ->
        Update.update_if_visible(socket, :not_a_string, "id", &Function.identity/1)
      end
    end

    test "requires update_fn to be arity-1 function" do
      socket = %Phoenix.LiveView.Socket{assigns: %{}}

      assert_raise FunctionClauseError, fn ->
        Update.update_if_visible(socket, "table", "id", fn _a, _b -> :ok end)
      end
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

    test "requires ids to be a list" do
      socket = %Phoenix.LiveView.Socket{assigns: %{}}

      assert_raise FunctionClauseError, fn ->
        Update.update_items_if_visible(socket, "table", "not-a-list", &Function.identity/1)
      end
    end

    test "requires collection_id to be binary" do
      socket = %Phoenix.LiveView.Socket{assigns: %{}}

      assert_raise FunctionClauseError, fn ->
        Update.update_items_if_visible(socket, :not_a_string, ["id"], &Function.identity/1)
      end
    end

    test "requires update_fn to be arity-1 function" do
      socket = %Phoenix.LiveView.Socket{assigns: %{}}

      assert_raise FunctionClauseError, fn ->
        Update.update_items_if_visible(socket, "table", ["id"], fn _a, _b -> :ok end)
      end
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
  end
end
