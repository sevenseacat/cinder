# SPDX-FileCopyrightText: 2025 Cinder contributors <https://github.com/sevenseacat/cinder/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Cinder do
  @moduledoc """
  Cinder is a powerful, intelligent data table component for Phoenix LiveView applications with seamless Ash Framework integration.

  ## Quick Start

  The simplest way to display a collection is with `Cinder.collection`:

  ```heex
  <Cinder.collection resource={MyApp.User} actor={@current_user}>
    <:col :let={user} field="name" filter sort>{user.name}</:col>
    <:col :let={user} field="email" filter>{user.email}</:col>
  </Cinder.collection>
  ```

  You can also use different layouts:

  ```heex
  <!-- List layout -->
  <Cinder.collection resource={MyApp.User} actor={@current_user} layout={:list}>
    <:col field="name" filter sort />
    <:item :let={user}>
      <div class="p-4">{user.name}</div>
    </:item>
  </Cinder.collection>

  <!-- Grid layout -->
  <Cinder.collection resource={MyApp.User} actor={@current_user} layout={:grid}>
    <:col field="name" filter sort />
    <:item :let={user}>
      <div class="p-4 border rounded">{user.name}</div>
    </:item>
  </Cinder.collection>
  ```

  Pass a `query` instead of a `resource` to start from a query of your own:

  ```heex
  <Cinder.collection query={MyApp.User |> Ash.Query.filter(active: true)} actor={@current_user}>
    <:col :let={user} field="name" filter sort>{user.name}</:col>
    <:col :let={user} field="email" filter>{user.email}</:col>
  </Cinder.collection>
  ```

  ## Custom Filters

  Cinder supports custom filter types through a simple configuration-based approach:

      # 1. Configure your filters in config.exs
      config :cinder, :filters, [
        slider: MyApp.Filters.Slider,
        color_picker: MyApp.Filters.ColorPicker
      ]

      # 2. Create custom filters with minimal boilerplate
      defmodule MyApp.Filters.Slider do
        use Cinder.Filter  # Includes everything you need

        @impl true
        def render(column, current_value, theme, assigns) do
          # Your filter implementation with HEEx templates
        end

        @impl true
        def process(raw_value, column) do
          # Transform form input to filter value
        end

        @impl true
        def validate(filter_value), do: # Validate filter value

        @impl true
        def default_options, do: [min: 0, max: 100, step: 1]

        @impl true
        def empty?(value), do: # Check if filter is empty
      end

      # 3. Use in your collections
      <:col field="price" filter={[type: :slider, min: 0, max: 1000]}>
        ${product.price}
      </:col>

  No registration or setup needed: configure them and use them.

  ## Key Features

  - **Intelligent Defaults**: Automatic filter type detection from Ash resource attributes
  - **Minimal Configuration**: 70% fewer attributes required compared to traditional table components
  - **URL State Management**: Filters, pagination, and sorting synchronized with browser URL
  - **Relationship Support**: Dot notation for related fields (e.g., `user.department.name`)
  - **Custom Filters**: Pluggable filter system with configuration-based registration
  - **Flexible Theming**: Built-in presets and full customization
  - **Ash Integration**: Native support for Ash Framework resources and authorization

  ## Main Components

  - `Cinder.collection/1` - Unified collection component (table, list, or grid layouts)
  - `Cinder.UrlSync` - URL state management helper
  - `Cinder.Filter` - Base behavior for custom filters

  ## Refreshing Collections

      def handle_event("delete", %{"id" => id}, socket) do
        # ... delete logic ...
        {:noreply, Cinder.refresh_table(socket, "my-table")}
      end

  For comprehensive examples and documentation, see the [README](readme.html) and [Examples](examples.html).
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
