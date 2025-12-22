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

  The `Cinder.Table.table` component is also available for table-specific usage:

  ```heex
  # Using resource parameter
  <Cinder.Table.table resource={MyApp.User} actor={@current_user}>
    <:col :let={user} field="name" filter sort>{user.name}</:col>
    <:col :let={user} field="email" filter>{user.email}</:col>
    <:col :let={user} field="created_at" sort>{user.created_at}</:col>
  </Cinder.Table.table>

  # Using query parameter
  <Cinder.Table.table query={MyApp.User} actor={@current_user}>
    <:col :let={user} field="name" filter sort>{user.name}</:col>
    <:col :let={user} field="email" filter>{user.email}</:col>
    <:col :let={user} field="created_at" sort>{user.created_at}</:col>
  </Cinder.Table.table>

  # Advanced query usage
  <Cinder.Table.table query={MyApp.User |> Ash.Query.filter(active: true)} actor={@current_user}>
    <:col :let={user} field="name" filter sort>{user.name}</:col>
    <:col :let={user} field="email" filter>{user.email}</:col>
    <:col :let={user} field="created_at" sort>{user.created_at}</:col>
  </Cinder.Table.table>
  ```

  ## Custom Filters

  Cinder supports custom filter types through a simple configuration-based approach:

      # 1. Configure your filters in config.exs
      config :cinder, :filters, [
        slider: MyApp.Filters.Slider,
        color_picker: MyApp.Filters.ColorPicker
      ]

      # 2. Set up Cinder in your application.ex
      def start(_type, _args) do
        Cinder.setup()  # Automatically registers all configured filters
        # ... rest of application startup
      end

      # 3. Create custom filters with minimal boilerplate
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

      # 4. Use in your tables
      <:col field="price" filter={:slider} filter_options={[min: 0, max: 1000]}>
        ${product.price}
      </:col>

  That's it! No manual registration, no complex setup - just configure and use.

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
  - `Cinder.Table` - The table component
  - `Cinder.Table.UrlSync` - URL state management helper
  - `Cinder.Table.Refresh` - Table refresh helpers
  - `Cinder.Filter` - Base behavior for custom filters
  - `Cinder.setup/0` - One-time setup for custom filters

  ## Table Refresh Functions

  For convenience, table refresh functions are available directly from the main module:

      import Cinder.Table.Refresh

      # Or use fully qualified names
      def handle_event("delete", %{"id" => id}, socket) do
        # ... delete logic ...
        {:noreply, Cinder.Table.Refresh.refresh_table(socket, "my-table")}
      end

  For comprehensive examples and documentation, see the [README](readme.html) and [Examples](examples.html).
  """

  # Unified collection component
  defdelegate collection(assigns), to: Cinder.Collection

  # Refresh functions
  defdelegate refresh_table(socket, table_id), to: Cinder.Refresh
  defdelegate refresh_tables(socket, table_ids), to: Cinder.Refresh

  # In-memory update functions (efficient for small PubSub-driven changes)
  defdelegate update_item(socket, collection_id, id, update_fn), to: Cinder.Update
  defdelegate update_items(socket, collection_id, ids, update_fn), to: Cinder.Update
  defdelegate update_if_visible(socket, collection_id, id, update_fn), to: Cinder.Update
  defdelegate update_items_if_visible(socket, collection_id, ids, update_fn), to: Cinder.Update

  @doc """
  Sets up Cinder with configured custom filters.

  This is the recommended way to use custom filters in Cinder. Call this
  function once during application startup to automatically register all
  custom filters defined in your configuration.

  ## Configuration

  Define your custom filters in your application configuration:

      config :cinder, :filters, [
        slider: MyApp.Filters.Slider,
        color_picker: MyApp.Filters.ColorPicker
      ]

  ## Usage

  Call `setup/0` once in your application startup:

      # In your application.ex
      def start(_type, _args) do
        Cinder.setup()  # Registers all configured filters automatically

        children = [
          # ... your application's children
        ]

        opts = [strategy: :one_for_one, name: MyApp.Supervisor]
        Supervisor.start_link(children, opts)
      end

  ## What it does

  - Registers all custom filters from configuration
  - Validates that all filter modules implement the required behavior
  - Provides helpful logging for successful registrations and errors
  - Gracefully handles configuration issues without breaking startup

  ## Returns

  Always returns `:ok`. Any registration issues are logged as warnings
  but don't prevent application startup.

  ## Examples

      # Successful setup with filters
      Cinder.setup()
      # => :ok
      # Logs: "Cinder: Registered 3 custom filters: slider, color_picker, date_picker"

      # Setup with configuration errors
      Cinder.setup()
      # => :ok
      # Logs: "Cinder: Some custom filters failed to register: ..."
  """
  def setup do
    case Cinder.Filters.Registry.register_config_filters() do
      :ok ->
        configured_filters = Application.get_env(:cinder, :filters, [])

        if length(configured_filters) > 0 do
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
