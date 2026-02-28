# Advanced Features

This guide covers URL state management, relationships, embedded resources, refresh, state slots, performance, and bulk actions. For basic setup, see [Getting Started](getting-started.md).

## Table of Contents

- [URL State Management](#url-state-management)
- [Relationship Fields](#relationship-fields)
- [Embedded Resources](#embedded-resources)
- [Collection Refresh](#collection-refresh)
- [Loading, Empty & Error States](#loading-empty-error-states)
- [Performance Optimization](#performance-optimization)
- [Selection & Bulk Actions](#selection--bulk-actions)

**See also:** [Filters](filters.md) | [Sorting](sorting.md)

## URL State Management

Synchronize collection state (filters, sorting, pagination) with the browser URL for bookmarkable, shareable views.

### Setup

```elixir
defmodule MyAppWeb.UsersLive do
  use MyAppWeb, :live_view
  use Cinder.UrlSync

  def mount(_params, _session, socket) do
    {:ok, assign(socket, :current_user, get_current_user(socket))}
  end

  def handle_params(params, uri, socket) do
    socket = Cinder.UrlSync.handle_params(params, uri, socket)
    {:noreply, socket}
  end

  def render(assigns) do
    ~H"""
    <Cinder.collection
      resource={MyApp.User}
      actor={@current_user}
      url_state={@url_state}
      id="users-table"
    >
      <:col :let={user} field="name" filter sort>{user.name}</:col>
      <:col :let={user} field="email" filter>{user.email}</:col>
      <:col :let={user} field="is_active" filter={:boolean}>
        {if user.is_active, do: "Active", else: "Inactive"}
      </:col>
    </Cinder.collection>
    """
  end
end
```

### URL Examples

```
# Basic filtering
/users?name=john&email=gmail

# Date range
/users?created_at_from=2024-01-01&created_at_to=2024-12-31

# Pagination and sorting
/users?page=3&sort=-created_at

# Complex state
/users?name=admin&is_active=true&page=2&sort=name
```

## Relationship Fields

Use dot notation to filter and sort by related resource fields:

```heex
<Cinder.collection resource={MyApp.User} actor={@current_user}>
  <:col :let={user} field="name" filter sort>{user.name}</:col>
  <:col :let={user} field="department.name" filter sort>{user.department.name}</:col>
  <:col :let={user} field="manager.email" filter>{user.manager.email}</:col>
</Cinder.collection>
```

### Deep Relationships

```heex
<:col :let={user} field="office.building.address" filter>
  {user.office.building.address}
</:col>
```

### Custom Options for Relationship Fields

```heex
<:col
  :let={user}
  field="department.name"
  filter={[type: :select, options: @department_names]}
>
  {user.department.name}
</:col>
```

## Embedded Resources

Use double underscore notation (`__`) for embedded resource fields:

```heex
<Cinder.collection resource={MyApp.User} actor={@current_user}>
  <:col :let={user} field="name">{user.name}</:col>
  <:col :let={user} field="profile__bio" filter>{user.profile.bio}</:col>
  <:col :let={user} field="profile__country" filter>{user.profile.country}</:col>
</Cinder.collection>
```

### Nested Embedded Fields

```heex
<:col :let={user} field="settings__address__city" filter>
  {user.settings.address.city}
</:col>
```

### Sorting Embedded Fields

Embedded fields support sorting just like regular fields:

```heex
<:col :let={user} field="profile__last_name" sort>{user.profile.last_name}</:col>
```

For default sorting on embedded fields, use `Cinder.QueryBuilder.apply_sorting/2`:

```heex
<Cinder.collection
  query={MyApp.User |> Cinder.QueryBuilder.apply_sorting([{"profile__last_name", :asc}])}
  actor={@current_user}
>
  <:col :let={user} field="profile__last_name" sort>{user.profile.last_name}</:col>
</Cinder.collection>
```

### Automatic Enum Detection

Embedded enum fields are automatically detected and rendered as select filters with the enum values:

```heex
<!-- If profile.country is an Ash.Type.Enum, options are auto-populated -->
<:col :let={user} field="profile__country" filter>{user.profile.country}</:col>
```

## Collection Refresh

After CRUD operations, refresh collection data while preserving filters, sorting, and pagination:

```elixir
defmodule MyAppWeb.UsersLive do
  use MyAppWeb, :live_view
  import Cinder.Refresh

  def render(assigns) do
    ~H"""
    <Cinder.collection id="users-table" resource={MyApp.User} actor={@current_user}>
      <:col :let={user} field="name" filter sort>{user.name}</:col>
      <:col :let={user} label="Actions">
        <button phx-click="delete_user" phx-value-id={user.id}>Delete</button>
      </:col>
    </Cinder.collection>
    """
  end

  def handle_event("delete_user", %{"id" => id}, socket) do
    MyApp.User
    |> Ash.get!(id, actor: socket.assigns.current_user)
    |> Ash.destroy!(actor: socket.assigns.current_user)

    # Refresh maintains current filters, sorting, and page
    {:noreply, refresh_table(socket, "users-table")}
  end
end
```

### Multiple Collections

```elixir
{:noreply, refresh_tables(socket, ["users-table", "audit-logs-table"])}
```

### In-Memory Updates

For PubSub-driven updates where you already have the new data, use in-memory updates instead of re-querying the entire table:

```elixir
defmodule MyAppWeb.UsersLive do
  use MyAppWeb, :live_view
  import Cinder.Update

  def mount(_params, _session, socket) do
    if connected?(socket), do: MyApp.PubSub.subscribe("users")
    {:ok, socket}
  end

  # Update a single item by ID
  def handle_info({:user_status_changed, user_id, new_status}, socket) do
    {:noreply, update_item(socket, "users-table", user_id, fn user ->
      %{user | status: new_status}
    end)}
  end

  # Update multiple items
  def handle_info({:users_deactivated, user_ids}, socket) do
    {:noreply, update_items(socket, "users-table", user_ids, fn user ->
      %{user | active: false}
    end)}
  end
end
```

#### Lazy Loading with `update_if_visible`

When PubSub delivers bare records without associations, use `update_if_visible` to only load data for items currently displayed:

```elixir
# Only loads associations if the user is on the current page
def handle_info({:user_updated, raw_user}, socket) do
  {:noreply, update_if_visible(socket, "users-table", raw_user, fn raw ->
    {:ok, loaded} = Ash.load(raw, [:department, :manager])
    loaded
  end)}
end

# Batch version - loads associations for all visible items at once
def handle_info({:users_updated, raw_users}, socket) do
  {:noreply, update_items_if_visible(socket, "users-table", raw_users, fn visible ->
    {:ok, loaded} = Ash.load(visible, [:department, :manager])
    loaded
  end)}
end
```

The `*_if_visible` variants never call your function if the item isn't displayed, avoiding wasted database calls.

#### Caveats

- These functions modify in-memory data only. Computed fields, aggregates, and calculations from the database will NOT be recalculated.
- For changes that affect derived data, use `refresh_table/2` instead.
- If the item is not found in the current page, the update is silently ignored.

## Loading, Empty & Error States

Customize the loading spinner, empty message, and error display using slots. These replace the default string messages with rich content.

### Custom Loading State

```heex
<Cinder.collection resource={MyApp.User} actor={@current_user}>
  <:col :let={user} field="name" filter sort>{user.name}</:col>

  <:loading>
    <div class="flex items-center gap-2 p-8 justify-center">
      <MyAppWeb.Components.spinner />
      <span>Fetching users...</span>
    </div>
  </:loading>
</Cinder.collection>
```

### Custom Empty State

```heex
<Cinder.collection resource={MyApp.User} actor={@current_user}>
  <:col :let={user} field="name" filter sort>{user.name}</:col>

  <:empty>
    <div class="text-center p-8">
      <img src="/images/no-results.svg" class="mx-auto w-32" />
      <p class="mt-4 text-gray-500">No users found</p>
    </div>
  </:empty>
</Cinder.collection>
```

#### Empty Slot Context

The `<:empty>` slot receives context via `:let` to distinguish between "no records exist" and "filters returned no results":

```heex
<Cinder.collection resource={MyApp.User} actor={@current_user}>
  <:col :let={user} field="name" filter sort search>{user.name}</:col>

  <:empty :let={context}>
    <%= if context.filtered? do %>
      <div class="text-center p-8">
        <p>No users match your filters.</p>
        <p class="text-sm text-gray-500">Try adjusting your search or filters.</p>
      </div>
    <% else %>
      <div class="text-center p-8">
        <p>No users yet.</p>
        <.link navigate={~p"/users/new"} class="text-blue-600 underline">Create one</.link>
      </div>
    <% end %>
  </:empty>
</Cinder.collection>
```

The context map contains:

- `filtered?` — `true` when any filter has a meaningful value or a search term is active
- `filters` — the full filters map (e.g. `%{"name" => %{type: :text, value: "bob", ...}}`)
- `search_term` — the current search string

### Custom Error State

```heex
<Cinder.collection resource={MyApp.User} actor={@current_user}>
  <:col :let={user} field="name" filter sort>{user.name}</:col>

  <:error>
    <div class="text-center p-8 text-red-600">
      <p>Something went wrong loading users.</p>
      <button phx-click="retry" class="mt-2 underline">Try again</button>
    </div>
  </:error>
</Cinder.collection>
```

### String Message Attributes

For simple text customization without slots, use the message attributes:

```heex
<Cinder.collection
  resource={MyApp.User}
  actor={@current_user}
  loading_message="Fetching users..."
  empty_message="No users yet"
  error_message="Failed to load users"
>
  <:col :let={user} field="name">{user.name}</:col>
</Cinder.collection>
```

Slots take precedence over message attributes when both are provided.

### State Precedence

When multiple states are active, they follow this display order: **loading > error > empty > data**. Error state hides any stale data rows, and loading overlays the entire content area.

## Performance Optimization

### Efficient Data Loading

Use `query_opts` to load only needed data:

```heex
<Cinder.collection
  resource={MyApp.User}
  actor={@current_user}
  query_opts={[
    load: [:department, :manager],
    select: [:id, :name, :email, :created_at]
  ]}
>
  ...
</Cinder.collection>
```

### Pagination

```heex
<!-- Fixed page size -->
<Cinder.collection resource={MyApp.User} actor={@current_user} page_size={50}>
  ...
</Cinder.collection>

<!-- User-selectable page size -->
<Cinder.collection
  resource={MyApp.User}
  actor={@current_user}
  page_size={[default: 25, options: [10, 25, 50, 100]]}
>
  ...
</Cinder.collection>

<!-- Keyset pagination for large datasets -->
<Cinder.collection
  resource={MyApp.User}
  actor={@current_user}
  pagination={:keyset}
>
  ...
</Cinder.collection>
```

**Global Default Page Size:**

Set a default page size for all collections in your config:

```elixir
# config/config.exs
config :cinder, default_page_size: 50

# Or with user-selectable options
config :cinder, default_page_size: [default: 25, options: [10, 25, 50, 100]]
```

Individual collections can still override with the `page_size` attribute.

**Keyset vs Offset Pagination:**

- **Offset** (default): Traditional page numbers, allows jumping to any page. Can be slow on large datasets.
- **Keyset**: Cursor-based prev/next navigation. Much faster on large datasets but cannot jump to arbitrary pages.

Use keyset pagination when you have large tables (10k+ rows) where offset queries become slow.

**Important:** Ensure your Ash action has pagination configured to prevent loading all records into memory:

```elixir
# In your resource
actions do
  read :read do
    pagination offset?: true, keyset?: true, default_limit: 25
  end
end
```

### Query Timeout

For slow queries, configure a timeout:

```heex
<Cinder.collection
  resource={MyApp.LargeDataset}
  actor={@current_user}
  query_opts={[timeout: 30_000]}
>
  ...
</Cinder.collection>
```

## Selection & Bulk Actions

Enable row/item selection with checkboxes and execute bulk operations on selected records.

### Enabling Selection

Add `selectable` to enable checkboxes:

```heex
<Cinder.collection resource={MyApp.User} actor={@current_user} selectable>
  <:col :let={user} field="name" filter sort>{user.name}</:col>
  <:col :let={user} field="email">{user.email}</:col>
</Cinder.collection>
```

### Bulk Action Slots

Define bulk actions using the `bulk_action` slot. There are two ways to render bulk action buttons:

#### Themed Buttons (Recommended)

Use `label` and `variant` for automatically styled buttons that match your theme:

```heex
<Cinder.collection resource={MyApp.User} actor={@current_user} selectable>
  <:col :let={user} field="name" filter sort>{user.name}</:col>

  <!-- Themed buttons: automatically styled based on theme -->
  <:bulk_action action={:archive} label="Archive ({count})" variant={:primary} />
  <:bulk_action action={:export} label="Export" variant={:secondary} />
  <:bulk_action action={:destroy} label="Delete" variant={:danger} confirm="Delete {count} users?" />
</Cinder.collection>
```

Available variants:
- `:primary` (default) - Solid/filled button for primary actions
- `:secondary` - Outline/ghost style for secondary actions
- `:danger` - Destructive action style (typically red)

The `{count}` placeholder in labels is interpolated with the current selection count. Buttons are automatically disabled when no items are selected.

Themed buttons use these theme properties:
- `button_class` - Base styles (padding, font, border-radius)
- `button_primary_class`, `button_secondary_class`, `button_danger_class` - Variant styles
- `button_disabled_class` - Disabled state styles
- `bulk_actions_container_class` - Container styling (matches card/list item aesthetic)

#### Custom Buttons

For full control over button rendering, provide inner content instead of `label`:

```heex
<Cinder.collection resource={MyApp.User} actor={@current_user} selectable>
  <:col :let={user} field="name" filter sort>{user.name}</:col>

  <:bulk_action action={:archive} :let={context}>
    <button class="btn" disabled={context.selected_count == 0}>Archive Selected</button>
  </:bulk_action>

  <:bulk_action action={:destroy} confirm="Delete {count} users?">
    <button class="btn btn-danger">Delete Selected</button>
  </:bulk_action>
</Cinder.collection>
```

### Action Types

**Atom actions** call Ash bulk operations directly. The action type (update/destroy) is introspected from the resource:

```heex
<!-- Calls Ash.bulk_update with the :archive action -->
<:bulk_action action={:archive}>Archive</:bulk_action>

<!-- Calls Ash.bulk_destroy with the :destroy action -->
<:bulk_action action={:destroy}>Delete</:bulk_action>
```

**Function actions** receive a pre-filtered query matching code interface signatures:

```heex
<:bulk_action action={&MyApp.Users.archive/2}>Archive</:bulk_action>
```

### Confirmation Dialogs

Add `confirm` to show a browser confirmation dialog. Use `{count}` to interpolate the selection count:

```heex
<:bulk_action action={:destroy} confirm="Are you sure you want to delete {count} records?">
  Delete Selected
</:bulk_action>
```

### Success and Error Callbacks

Handle action results in your parent LiveView:

```heex
<Cinder.collection
  resource={MyApp.User}
  actor={@current_user}
  selectable
>
  <:bulk_action
    action={:archive}
    on_success={:users_archived}
    on_error={:archive_failed}
  >
    Archive Selected
  </:bulk_action>
</Cinder.collection>
```

```elixir
def handle_info({:users_archived, payload}, socket) do
  # payload contains: %{component_id, action, count, result}
  {:noreply, put_flash(socket, :info, "Archived #{payload.count} users")}
end

def handle_info({:archive_failed, payload}, socket) do
  # payload contains: %{component_id, action, reason}
  {:noreply, put_flash(socket, :error, "Archive failed: #{inspect(payload.reason)}")}
end
```

### Action Options

Pass additional Ash bulk options via `action_opts`:

```heex
<:bulk_action action={:archive} action_opts={[return_records?: true, notify?: true]}>
  Archive Selected
</:bulk_action>
```

### Selection Change Notifications

You can also track selection state in your parent LiveView. This is not necessary to do, Cinder will track the IDs of selected records internally, but if you want to know about the selections yourself as well, this is how:

```heex
<Cinder.collection
  resource={MyApp.User}
  actor={@current_user}
  selectable
  on_selection_change={:selection_changed}
>
  ...
</Cinder.collection>
```

```elixir
def handle_info({:selection_changed, payload}, socket) do
  # payload contains: %{selected_ids, selected_count, component_id, action}
  # action is one of: :select, :deselect, :select_all, :clear
  {:noreply, assign(socket, :selected_count, payload.selected_count)}
end
```

### Accessing Selection Context

The bulk action slot receives selection context:

```heex
<:bulk_action :let={selection} action={:archive}>
  <button class="btn">
    Archive {selection.selected_count} users
  </button>
</:bulk_action>
```

Available in `selection`:

- `selected_count` - Number of selected items
- `selected_ids` - MapSet of selected record IDs

### Click-to-Select

When `selectable` is enabled without a `click` handler, clicking rows/items toggles selection:

```heex
<!-- Clicking a row toggles its selection -->
<Cinder.collection resource={MyApp.User} actor={@current_user} selectable>
  ...
</Cinder.collection>

<!-- With a click handler, only checkboxes toggle selection -->
<Cinder.collection
  resource={MyApp.User}
  actor={@current_user}
  selectable
  click={fn user -> JS.navigate(~p"/users/#{user.id}") end}
>
  ...
</Cinder.collection>
```
