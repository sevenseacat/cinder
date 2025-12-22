defmodule Cinder.Update do
  @moduledoc """
  Efficient in-memory updates for Cinder collection data.

  This module provides functions to update individual items in a collection's
  data without triggering a full database re-query. This is useful for applying
  small changes received via PubSub (e.g., status changes, counter increments)
  where re-fetching all 25+ items would be wasteful.

  ## Usage

      # Update a single item by ID
      def handle_info({:user_status_changed, user_id, new_status}, socket) do
        {:noreply, update_item(socket, "users-table", user_id, fn user ->
          %{user | status: new_status}
        end)}
      end

      # Update multiple items with the same function
      def handle_info({:users_activated, user_ids}, socket) do
        {:noreply, update_items(socket, "users-table", user_ids, fn user ->
          %{user | active: true}
        end)}
      end

      # Only update if the item is currently visible (no-op otherwise)
      def handle_info({:user_updated, user_id, changes}, socket) do
        {:noreply, update_if_visible(socket, "users-table", user_id, fn user ->
          Map.merge(user, changes)
        end)}
      end

  ## Caveats

  - These functions modify in-memory data only. Computed fields, aggregates,
    and calculations that come from the database will NOT be recalculated.
  - For changes that affect derived data, use `refresh_table/2` instead.
  - If the item is not found in the current data, the update is silently ignored.
  """

  import Phoenix.LiveView, only: [send_update: 2]

  @doc """
  Updates a single item in a collection by its ID.

  Applies the given function to the item matching the ID. If no item matches,
  the data remains unchanged.

  ## Parameters

  - `socket` - The LiveView socket
  - `collection_id` - The ID of the collection (string)
  - `id` - The ID of the item to update
  - `update_fn` - A function that receives the item and returns the updated item

  ## Returns

  The socket (unchanged, but update message has been sent).

  ## Examples

      # Update user's online status
      update_item(socket, "users-table", user_id, fn user ->
        %{user | online: true}
      end)

      # Increment a counter
      update_item(socket, "posts-table", post_id, fn post ->
        %{post | view_count: post.view_count + 1}
      end)
  """
  def update_item(socket, collection_id, id, update_fn)
      when is_binary(collection_id) and is_function(update_fn, 1) do
    send_update(Cinder.LiveComponent,
      id: collection_id,
      __update_item__: {id, update_fn}
    )

    socket
  end

  @doc """
  Updates multiple items in a collection by their IDs.

  Applies the given function to all items whose IDs are in the provided list.
  Items not in the list are left unchanged.

  ## Parameters

  - `socket` - The LiveView socket
  - `collection_id` - The ID of the collection (string)
  - `ids` - List of IDs of items to update
  - `update_fn` - A function that receives each item and returns the updated item

  ## Returns

  The socket (unchanged, but update message has been sent).

  ## Examples

      # Mark multiple users as active
      update_items(socket, "users-table", user_ids, fn user ->
        %{user | active: true}
      end)

      # Apply discount to selected products
      update_items(socket, "products-table", product_ids, fn product ->
        %{product | price: product.price * 0.9}
      end)
  """
  def update_items(socket, collection_id, ids, update_fn)
      when is_binary(collection_id) and is_list(ids) and is_function(update_fn, 1) do
    send_update(Cinder.LiveComponent,
      id: collection_id,
      __update_items__: {ids, update_fn}
    )

    socket
  end

  @doc """
  Updates an item only if it's currently visible in the collection.

  This combines the efficiency of `update_item/4` with visibility checking.
  If the item is not in the visible set, no update is sent (complete no-op).

  Requires the collection to have `emit_visible_ids={true}` and the parent
  LiveView to store visible IDs via the `{:cinder_visible_ids, ...}` handler.

  ## Parameters

  - `socket` - The LiveView socket (must have `:cinder_visible_ids` in assigns)
  - `collection_id` - The ID of the collection (string)
  - `id` - The ID of the item to update
  - `update_fn` - A function that receives the item and returns the updated item

  ## Returns

  The socket (unchanged). Update message sent only if item is visible.

  ## Examples

      # In parent LiveView, store visible IDs
      def handle_info({:cinder_visible_ids, collection_id, ids}, socket) do
        visible_ids = socket.assigns[:cinder_visible_ids] || %{}
        {:noreply, assign(socket, :cinder_visible_ids, Map.put(visible_ids, collection_id, MapSet.new(ids)))}
      end

      # Update only if visible
      def handle_info({:user_typing, user_id}, socket) do
        {:noreply, update_if_visible(socket, "users-table", user_id, fn user ->
          %{user | typing: true}
        end)}
      end
  """
  def update_if_visible(socket, collection_id, id, update_fn)
      when is_binary(collection_id) and is_function(update_fn, 1) do
    visible_ids = get_in(socket.assigns, [:cinder_visible_ids, collection_id])

    if visible_ids && id in visible_ids do
      update_item(socket, collection_id, id, update_fn)
    else
      socket
    end
  end

  @doc """
  Updates multiple items only if any are currently visible.

  Like `update_if_visible/4` but for multiple IDs. Only items that are both
  in the provided list AND currently visible will be updated.

  ## Parameters

  - `socket` - The LiveView socket (must have `:cinder_visible_ids` in assigns)
  - `collection_id` - The ID of the collection (string)
  - `ids` - List of IDs to potentially update
  - `update_fn` - A function that receives each item and returns the updated item

  ## Returns

  The socket (unchanged). Update message sent only for visible items.

  ## Examples

      def handle_info({:users_went_offline, user_ids}, socket) do
        {:noreply, update_items_if_visible(socket, "users-table", user_ids, fn user ->
          %{user | online: false}
        end)}
      end
  """
  def update_items_if_visible(socket, collection_id, ids, update_fn)
      when is_binary(collection_id) and is_list(ids) and is_function(update_fn, 1) do
    visible_ids = get_in(socket.assigns, [:cinder_visible_ids, collection_id])

    if visible_ids do
      visible_to_update = Enum.filter(ids, &(&1 in visible_ids))

      if visible_to_update != [] do
        update_items(socket, collection_id, visible_to_update, update_fn)
      else
        socket
      end
    else
      socket
    end
  end
end
