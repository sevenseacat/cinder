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

  @doc """
  Refreshes a collection only if any of the given IDs are currently visible.

  Checks if the provided ID(s) are in the set of visible records for the collection.
  If any match, the collection is refreshed; otherwise, the socket is returned unchanged.

  Requires the collection to have `emit_visible_ids={true}` and the parent LiveView
  to store visible IDs via handling `{:cinder_visible_ids, collection_id, ids}`.

  ## Parameters

  - `socket` - The LiveView socket (must have `:cinder_visible_ids` in assigns)
  - `collection_id` - The ID of the collection to conditionally refresh
  - `ids` - A single ID or list of IDs to check against visible set

  ## Returns

  Updated socket with refresh message sent if any ID is visible, unchanged otherwise.

  ## Examples

      # In parent LiveView, store visible IDs
      def handle_info({:cinder_visible_ids, collection_id, ids}, socket) do
        visible_ids = socket.assigns[:cinder_visible_ids] || %{}
        {:noreply, assign(socket, :cinder_visible_ids, Map.put(visible_ids, collection_id, MapSet.new(ids)))}
      end

      # Refresh only if the changed record is visible
      def handle_info({:record_updated, record}, socket) do
        {:noreply, refresh_if_visible(socket, "my-collection", record.id)}
      end

      # With multiple IDs
      def handle_info({:records_updated, records}, socket) do
        {:noreply, refresh_if_visible(socket, "my-collection", Enum.map(records, & &1.id))}
      end
  """
  def refresh_if_visible(socket, collection_id, ids)
      when is_binary(collection_id) and is_list(ids) do
    visible_ids = get_in(socket.assigns, [:cinder_visible_ids, collection_id])

    if visible_ids && Enum.any?(ids, &(&1 in visible_ids)) do
      refresh_table(socket, collection_id)
    else
      socket
    end
  end

  def refresh_if_visible(socket, collection_id, id) when is_binary(collection_id) do
    refresh_if_visible(socket, collection_id, [id])
  end
end
