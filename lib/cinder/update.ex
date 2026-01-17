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
  - The `update_if_visible` functions check visibility within the component itself.
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
  The component itself checks if the item exists in its current data before
  applying the update. If the item is not visible, the update function is never
  called, enabling lazy loading patterns.

  Safe to call when you're unsure if the item is currently displayed.

  ## Parameters

  - `socket` - The LiveView socket
  - `collection_id` - The ID of the collection (string)
  - `id` - The ID of the item to update
  - `update_fn` - A function that receives a list containing the visible item
    and returns either a list of updated items or a map of `%{id => updated_item}`

  ## Returns

  The socket (unchanged, but update message has been sent to component).

  ## Examples

      # Simple update
      def handle_info({:user_typing, user_id}, socket) do
        {:noreply, update_if_visible(socket, "users-table", user_id, fn [user] ->
          [%{user | typing: true}]
        end)}
      end

      # Lazy loading - only loads if visible
      def handle_info({:user_updated, user_id, raw_data}, socket) do
        {:noreply, update_if_visible(socket, "users-table", user_id, fn _visible ->
          {:ok, loaded} = Ash.load(raw_data, [:profile, :settings], opts)
          [loaded]
        end)}
      end
  """
  def update_if_visible(socket, collection_id, id, update_fn)
      when is_binary(collection_id) and is_function(update_fn, 1) do
    send_update(Cinder.LiveComponent,
      id: collection_id,
      __update_item_if_visible__: {id, update_fn}
    )

    socket
  end

  @doc """
  Updates multiple items only if any are currently visible.

  Like `update_if_visible/4` but for multiple IDs. Only items that are both
  in the provided list AND currently visible will be updated. The component
  itself determines which items are visible by checking its current data.

  The update function is called ONCE with ALL visible items, enabling efficient
  batch operations. If no items are visible, the function is never called.

  ## Parameters

  - `socket` - The LiveView socket
  - `collection_id` - The ID of the collection (string)
  - `ids` - List of IDs to potentially update
  - `update_fn` - A function that receives a list of visible items and returns
    either a list of updated items or a map of `%{id => updated_item}`

  ## Returns

  The socket (unchanged, but update message has been sent to component).

  ## Examples

      # Simple batch update
      def handle_info({:users_went_offline, user_ids}, socket) do
        {:noreply, update_items_if_visible(socket, "users-table", user_ids, fn users ->
          Enum.map(users, &%{&1 | online: false})
        end)}
      end

      # Lazy batch loading - only loads visible items
      def handle_info(%{payload: %{data: data}}, socket) do
        items = List.wrap(data)
        ids = Enum.map(items, & &1.id)
        raw_by_id = Map.new(items, &{&1.id, &1})

        {:noreply, update_items_if_visible(socket, "table", ids, fn visible_items ->
          to_load = Enum.map(visible_items, &raw_by_id[&1.id])
          {:ok, loaded} = Ash.load(to_load, [:relations], opts)
          loaded
        end)}
      end
  """
  def update_items_if_visible(socket, collection_id, item, update_fn)
      when is_binary(collection_id) and is_struct(item) and is_function(update_fn, 1) do
    update_items_if_visible(socket, collection_id, [item], update_fn)
  end

  def update_items_if_visible(socket, collection_id, ids, update_fn)
      when is_binary(collection_id) and is_list(ids) and is_function(update_fn, 1) do
    send_update(Cinder.LiveComponent,
      id: collection_id,
      __update_items_if_visible__: {ids, update_fn}
    )

    socket
  end
end
