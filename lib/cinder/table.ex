defmodule Cinder.Table do
  @moduledoc """
  Table component for displaying data in a traditional HTML table layout.

  **DEPRECATED:** Use `Cinder.collection` instead. This module will be removed in version 1.0.

  ```heex
  <!-- Use this instead -->
  <Cinder.collection resource={MyApp.User} actor={@current_user}>
    <:col :let={user} field="name" filter sort>{user.name}</:col>
  </Cinder.collection>
  ```

  See the [Upgrading Guide](upgrading.html) for migration instructions.

  ## Basic Usage

  ```heex
  <Cinder.Table.table resource={MyApp.User} actor={@current_user}>
    <:col :let={user} field="name" filter sort>{user.name}</:col>
    <:col :let={user} field="email" filter>{user.email}</:col>
    <:col :let={user} field="created_at" sort>{user.created_at}</:col>
  </Cinder.Table.table>
  ```

  ## With Query

  ```heex
  <Cinder.Table.table query={MyApp.User |> Ash.Query.filter(active: true)} actor={@current_user}>
    <:col :let={user} field="name" filter sort>{user.name}</:col>
    <:col :let={user} field="email" filter>{user.email}</:col>
  </Cinder.Table.table>
  ```

  ## See Also

  - `Cinder.collection/1` - Unified collection component supporting table, list, and grid layouts
  - `Cinder.Collection` - Full documentation for all collection features
  """

  use Phoenix.Component

  # All attributes are passed through to Collection
  attr :resource, :atom, default: nil, doc: "The Ash resource to query"
  attr :query, :any, default: nil, doc: "The Ash query to execute"
  attr :actor, :any, default: nil, doc: "Actor for authorization"
  attr :tenant, :any, default: nil, doc: "Tenant for multi-tenant resources"
  attr :scope, :any, default: nil, doc: "Ash scope containing actor and tenant"
  attr :id, :string, default: "cinder-table", doc: "Unique identifier for the table"
  attr :page_size, :any, default: 25, doc: "Number of items per page"
  attr :theme, :any, default: "default", doc: "Theme name or theme map"
  attr :url_state, :any, default: false, doc: "URL state object from UrlSync.handle_params"
  attr :query_opts, :list, default: [], doc: "Additional Ash query options"
  attr :on_state_change, :any, default: nil, doc: "Custom state change handler"
  attr :show_pagination, :boolean, default: true, doc: "Whether to show pagination controls"
  attr :show_filters, :boolean, default: nil, doc: "Whether to show filter controls"
  attr :loading_message, :string, default: "Loading...", doc: "Message to show while loading"
  attr :filters_label, :string, default: "🔍 Filters", doc: "Label for the filters component"
  attr :search, :any, default: nil, doc: "Search configuration"
  attr :empty_message, :string, default: "No results found", doc: "Message when no results"
  attr :class, :string, default: "", doc: "Additional CSS classes"
  attr :row_click, :any, default: nil, doc: "Function to call when a row is clicked"

  attr :bulk_actions, :list,
    default: [],
    doc:
      "List of bulk action maps with :label and :event keys, e.g. [%{label: \"Export\", event: \"export_ids\"}]"

  attr :id_field, :atom,
    default: :id,
    doc: "Field to use as ID for bulk actions (defaults to :id)"

  attr :emit_visible_ids, :boolean,
    default: false,
    doc: "When true, emits {:cinder_visible_ids, table_id, [id]} to parent after each data load"

  slot :col do
    attr :field, :string
    attr :filter, :any
    attr :filter_options, :list
    attr :sort, :any
    attr :search, :boolean
    attr :label, :string
    attr :class, :string
  end

  slot :filter do
    attr :field, :string
    attr :filter, :any
    attr :label, :string
  end

  @doc """
  Renders a data table.

  **DEPRECATED:** Use `Cinder.collection` instead.

  This is equivalent to calling `Cinder.collection` with `layout={:table}`.
  """
  @doc deprecated: "Use Cinder.collection instead"
  def table(assigns) do
    # Map row_click to click for Collection
    assigns =
      assigns
      |> assign(:layout, :table)
      |> assign(:click, assigns[:row_click])

    Cinder.Collection.collection(assigns)
  end

  # ============================================================================
  # DELEGATED FUNCTIONS
  # These are kept for backward compatibility with code that calls them directly
  # ============================================================================

  @doc """
  Process column definitions into the format expected by the underlying component.
  Delegates to `Cinder.Collection.process_columns/2`.
  """
  defdelegate process_columns(col_slots, resource), to: Cinder.Collection

  @doc """
  Process filter-only slot definitions.
  Delegates to `Cinder.Collection.process_filter_slots/2`.
  """
  defdelegate process_filter_slots(filter_slots, resource), to: Cinder.Collection

  @doc """
  Merge column filters and filter-only slots, checking for field conflicts.
  Delegates to `Cinder.Collection.merge_filter_configurations/2`.
  """
  defdelegate merge_filter_configurations(processed_columns, processed_filter_slots),
    to: Cinder.Collection

  @doc """
  Process unified search configuration into individual components.
  Delegates to `Cinder.Collection.process_search_config/2`.
  """
  defdelegate process_search_config(search_config, columns), to: Cinder.Collection
end
