defmodule Cinder.RefreshTest do
  use ExUnit.Case, async: true

  test "refresh helpers reject non-boolean silent options" do
    socket = %Phoenix.LiveView.Socket{assigns: %{}}

    for value <- ["true", nil, 1],
        refresh <- [
          fn -> Cinder.refresh_table(socket, "table", silent: value) end,
          fn -> Cinder.refresh_tables(socket, ["table"], silent: value) end,
          fn -> Cinder.refresh_tables(socket, [], silent: value) end
        ] do
      assert_raise ArgumentError,
                   "expected :silent to be a boolean, got: #{inspect(value)}",
                   refresh
    end
  end

  describe "refresh_table/2" do
    test "returns socket unchanged with string table ID" do
      socket = %Phoenix.LiveView.Socket{
        assigns: %{}
      }

      result = Cinder.Refresh.refresh_table(socket, "test-table")
      assert result == socket
    end

    test "accepts binary table IDs" do
      socket = %Phoenix.LiveView.Socket{
        assigns: %{}
      }

      # Should not raise an error
      result = Cinder.Refresh.refresh_table(socket, "my-table-id")
      assert result == socket
    end
  end

  describe "refresh_tables/2" do
    test "returns socket unchanged with table ID list" do
      socket = %Phoenix.LiveView.Socket{
        assigns: %{}
      }

      table_ids = ["table-1", "table-2", "table-3"]
      result = Cinder.Refresh.refresh_tables(socket, table_ids)

      # Should return the socket unchanged
      assert result == socket
    end

    test "handles empty table ID list" do
      socket = %Phoenix.LiveView.Socket{
        assigns: %{}
      }

      result = Cinder.Refresh.refresh_tables(socket, [])
      assert result == socket
    end
  end

  describe "delegated functions from main Cinder module" do
    test "Cinder.refresh_table/2 delegates to Refresh module" do
      socket = %Phoenix.LiveView.Socket{
        assigns: %{}
      }

      result = Cinder.refresh_table(socket, "test-table")
      assert result == socket
    end

    test "Cinder.refresh_tables/2 delegates to Refresh module" do
      socket = %Phoenix.LiveView.Socket{
        assigns: %{}
      }

      result = Cinder.refresh_tables(socket, ["table-1", "table-2"])
      assert result == socket
    end
  end
end
