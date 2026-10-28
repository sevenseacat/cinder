# SPDX-FileCopyrightText: 2025 Cinder contributors <https://github.com/sevenseacat/cinder/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Cinder do
  @moduledoc """
  Tables, lists and grids of Ash resources in Phoenix LiveView, with filtering, sorting, search
  and pagination.

  ```heex
  <Cinder.collection resource={MyApp.User} actor={@current_user}>
    <:col :let={user} field="name" filter sort>{user.name}</:col>
    <:col :let={user} field="email" filter>{user.email}</:col>
  </Cinder.collection>
  ```

  For a list or grid, describe each item with an `<:item>` slot:

  ```heex
  <Cinder.collection resource={MyApp.User} actor={@current_user} layout={:grid}>
    <:col field="name" filter sort />
    <:item :let={user}>
      <div class="p-4 border rounded">{user.name}</div>
    </:item>
  </Cinder.collection>
  ```

  This module holds the component, `collection/1` (see `Cinder.Collection` for its attributes),
  and functions for changing a collection from your LiveView:

  - `refresh_table/2,3` and `refresh_tables/2,3` re-read collections.
  - `update_item/4`, `update_items/4`, `update_if_visible/4` and `update_items_if_visible/4` change
    rows on screen without re-reading.
  - `remove_item/3` and `remove_items/3` take rows off the page.

  See the [Getting Started](getting-started.html) guide to begin, and
  [Custom Filters](custom-filters.html) to write your own filter types.
  """

  # Unified collection component
  defdelegate collection(assigns), to: Cinder.Collection

  # Refresh functions
  defdelegate refresh_table(socket, table_id), to: Cinder.Refresh
  defdelegate refresh_table(socket, table_id, opts), to: Cinder.Refresh
  defdelegate refresh_tables(socket, table_ids), to: Cinder.Refresh
  defdelegate refresh_tables(socket, table_ids, opts), to: Cinder.Refresh

  # In-memory change functions (efficient for small PubSub-driven changes)
  defdelegate update_item(socket, collection_id, id, update_fn), to: Cinder.Update
  defdelegate update_items(socket, collection_id, ids, update_fn), to: Cinder.Update
  defdelegate update_if_visible(socket, collection_id, id, update_fn), to: Cinder.Update
  defdelegate update_items_if_visible(socket, collection_id, ids, update_fn), to: Cinder.Update
  defdelegate remove_item(socket, collection_id, id), to: Cinder.Update
  defdelegate remove_items(socket, collection_id, ids), to: Cinder.Update

  @doc false
  @deprecated "Custom filters are read from `config :cinder, :filters`, no setup needed"
  def setup do
    case Cinder.Filters.Registry.register_config_filters() do
      :ok ->
        configured_filters = Application.get_env(:cinder, :filters, [])

        if configured_filters != [] do
          filter_names = configured_filters |> Keyword.keys() |> Enum.join(", ")
          require Logger

          Logger.info(
            "Cinder: Registered #{length(configured_filters)} custom filters: #{filter_names}"
          )
        end

        :ok

      {:error, errors} ->
        require Logger

        Logger.warning(
          "Cinder: Some custom filters failed to register:\n" <>
            Enum.map_join(errors, "\n", &"  - #{&1}")
        )

        :ok
    end

    # Validate all filters (both config and runtime registered)
    case Cinder.FilterManager.validate_runtime_filters() do
      :ok -> :ok
      # Errors are already logged by validate_runtime_filters
      {:error, _} -> :ok
    end
  end
end
