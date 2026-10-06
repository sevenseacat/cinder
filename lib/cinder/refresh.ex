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
  - Loading state is shown during refresh by default
  - Data is reloaded using the same query parameters

  Pass `silent: true` to keep the currently rendered data visible without the
  loading treatment while its asynchronous replacement query runs.
  If that query fails, the error is logged, the existing data stays visible,
  and no error indicator is shown. Collections without existing rows use normal
  loading and error behavior, even when `silent: true` is requested.
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
  - `opts` - Optional keyword list (defaults to `[]`)

  ## Options

  - `:silent` - Boolean, defaults to `false`. When `true` and the collection has
    existing rows, keeps those rows visible without a loading indicator until
    the replacement data arrives. A failed silent refresh logs the error and
    retains the rows without showing an error indicator. Empty collections use
    normal loading and error behavior.

  Raises `ArgumentError` if `:silent` is not a boolean.

  ## Returns

  The socket (unchanged, but refresh message has been sent).

  ## Examples

      # Refresh a specific collection
      {:noreply, refresh_table(socket, "users-table")}

      # Refresh existing rows without a loading indicator
      {:noreply, refresh_table(socket, "users-table", silent: true)}

      # In a handle_event callback
      def handle_event("delete_user", %{"id" => id}, socket) do
        MyApp.User
        |> Ash.get!(id)
        |> Ash.destroy!()

        {:noreply, refresh_table(socket, "users-table")}
      end
  """
  def refresh_table(socket, collection_id, opts \\ []) when is_binary(collection_id) do
    send_update(Cinder.LiveComponent,
      id: collection_id,
      refresh: true,
      silent: silent_option!(opts)
    )

    socket
  end

  @doc """
  Refreshes multiple collections by their IDs.

  Convenience function to refresh several collections at once while maintaining
  granular control over which collections are refreshed.

  ## Parameters

  - `socket` - The LiveView socket
  - `collection_ids` - List of collection IDs to refresh
  - `opts` - Optional keyword list (defaults to `[]`), with the same `:silent`
    option as `refresh_table/3`

  With `silent: true`, each collection with existing rows keeps them visible
  while loading replacement data. Failures are logged without displaying an
  error indicator or clearing those rows. Collections without existing rows
  retain normal loading and error behavior.

  Raises `ArgumentError` if `:silent` is not a boolean.

  ## Returns

  The socket (unchanged, but refresh messages have been sent to all specified collections).

  ## Examples

      {:noreply, refresh_tables(socket, ["users-table", "orders-table"])}

      {:noreply, refresh_tables(socket, ["users-table", "orders-table"], silent: true)}
  """
  def refresh_tables(socket, collection_ids, opts \\ [])
      when is_list(collection_ids) and is_list(opts) do
    silent = silent_option!(opts)

    Enum.each(collection_ids, fn collection_id ->
      send_update(Cinder.LiveComponent,
        id: collection_id,
        refresh: true,
        silent: silent
      )
    end)

    socket
  end

  defp silent_option!(opts) do
    case Keyword.get(opts, :silent, false) do
      value when is_boolean(value) ->
        value

      value ->
        raise ArgumentError, "expected :silent to be a boolean, got: #{inspect(value)}"
    end
  end

  # Delegate to Cinder.Update for in-memory updates
  defdelegate update_item(socket, collection_id, id, update_fn), to: Cinder.Update
  defdelegate update_items(socket, collection_id, ids, update_fn), to: Cinder.Update
  defdelegate update_if_visible(socket, collection_id, id, update_fn), to: Cinder.Update
  defdelegate update_items_if_visible(socket, collection_id, ids, update_fn), to: Cinder.Update
end
