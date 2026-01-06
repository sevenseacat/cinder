defmodule Cinder.Refresh do
  @moduledoc """
  Helper functions for refreshing Cinder collection data from parent LiveViews.

  This module provides convenient functions to refresh collection data after
  performing CRUD operations, ensuring the collection reflects the latest state
  without requiring a full page reload.

  ## Usage

  After performing operations that modify data displayed in a collection:

      def handle_event("delete", %{"id" => id}, socket) do
        MyApp.MyResource
        |> Ash.get!(id)
        |> Ash.destroy!()

        {:noreply, refresh_table(socket, "my-table-id")}
      end

  Or to refresh multiple collections:

      def handle_event("bulk_delete", params, socket) do
        # ... perform bulk operations ...

        {:noreply, refresh_tables(socket, ["users-table", "orders-table"])}
      end

  ## Refresh Behavior

  When a collection is refreshed:
  - Current filters are maintained
  - Sort order is preserved
  - Pagination state is kept (user stays on current page if possible)
  - Loading state is shown during refresh
  - Data is reloaded using the same query parameters
  """

  import Phoenix.LiveView, only: [send_update: 2]

  @doc """
  Refreshes a specific collection by its ID.

  Sends a refresh message to the LiveComponent with the given ID.
  The collection will reload its data while maintaining current filters, sorting,
  and pagination state.

  ## Parameters

  - `socket` - The LiveView socket
  - `collection_id` - The ID of the collection to refresh (string)

  ## Returns

  The socket (unchanged, but refresh message has been sent).

  ## Examples

      # Refresh a specific collection
      {:noreply, refresh_table(socket, "users-table")}

      # In a handle_event callback
      def handle_event("delete_user", %{"id" => id}, socket) do
        MyApp.User
        |> Ash.get!(id)
        |> Ash.destroy!()

        {:noreply, refresh_table(socket, "users-table")}
      end
  """
  def refresh_table(socket, collection_id) when is_binary(collection_id) do
    send_update(Cinder.LiveComponent, id: collection_id, refresh: true)
    socket
  end

  @doc """
  Refreshes multiple collections by their IDs.

  Convenience function to refresh several collections at once while maintaining
  granular control over which collections are refreshed.

  ## Parameters

  - `socket` - The LiveView socket
  - `collection_ids` - List of collection IDs to refresh

  ## Returns

  The socket (unchanged, but refresh messages have been sent to all specified collections).

  ## Examples

      {:noreply, refresh_tables(socket, ["users-table", "orders-table"])}
  """
  def refresh_tables(socket, collection_ids) when is_list(collection_ids) do
    Enum.each(collection_ids, fn collection_id ->
      send_update(Cinder.LiveComponent, id: collection_id, refresh: true)
    end)

    socket
  end

  # Delegate to Cinder.Update for in-memory updates
  defdelegate update_item(socket, collection_id, id, update_fn), to: Cinder.Update
  defdelegate update_items(socket, collection_id, ids, update_fn), to: Cinder.Update
  defdelegate update_if_visible(socket, collection_id, id, update_fn), to: Cinder.Update
  defdelegate update_items_if_visible(socket, collection_id, ids, update_fn), to: Cinder.Update
end
