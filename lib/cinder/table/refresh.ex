defmodule Cinder.Table.Refresh do
  @moduledoc """
  Helper functions for refreshing Cinder table data from parent LiveViews.

  This module provides convenient functions to refresh table data after
  performing CRUD operations, ensuring the table reflects the latest state
  without requiring a full page reload.

  ## Usage

  After performing operations that modify data displayed in a table:

      def handle_event("delete", %{"id" => id}, socket) do
        MyApp.MyResource
        |> Ash.get!(id)
        |> Ash.destroy!()

        {:noreply, refresh_table(socket, "my-table-id")}
      end

  Or to refresh all tables on the page:

      def handle_event("bulk_delete", params, socket) do
        # ... perform bulk operations ...

        {:noreply, refresh_table(socket)}
      end

  ## Refresh Behavior

  When a table is refreshed:
  - Current filters are maintained
  - Sort order is preserved
  - Pagination state is kept (user stays on current page if possible)
  - Loading state is shown during refresh
  - Data is reloaded using the same query parameters
  """

  import Phoenix.LiveView, only: [send_update: 2]

  @doc """
  Refreshes a specific table by its ID.

  Sends a refresh message to the LiveComponent with the given table ID.
  The table will reload its data while maintaining current filters, sorting,
  and pagination state.

  ## Parameters

  - `socket` - The LiveView socket
  - `table_id` - The ID of the table to refresh (string)

  ## Returns

  Updated socket with the refresh message sent.

  ## Examples

      # Refresh a specific table
      {:noreply, refresh_table(socket, "users-table")}

      # In a handle_event callback
      def handle_event("delete_user", %{"id" => id}, socket) do
        MyApp.User
        |> Ash.get!(id)
        |> Ash.destroy!()

        {:noreply, refresh_table(socket, "users-table")}
      end
  """
  def refresh_table(socket, table_id) when is_binary(table_id) do
    send_update(Cinder.Table.LiveComponent, id: table_id, refresh: true)
    socket
  end

  @doc """
  Refreshes multiple specific tables by their IDs.

  Convenience function to refresh several tables at once while maintaining
  granular control over which tables are refreshed.

  ## Parameters

  - `socket` - The LiveView socket
  - `table_ids` - List of table IDs to refresh

  ## Returns

  Updated socket with refresh messages sent to all specified tables.

  ## Examples

      {:noreply, refresh_tables(socket, ["users-table", "orders-table"])}
  """
  def refresh_tables(socket, table_ids) when is_list(table_ids) do
    Enum.each(table_ids, fn table_id ->
      send_update(Cinder.Table.LiveComponent, id: table_id, refresh: true)
    end)

    socket
  end
end
