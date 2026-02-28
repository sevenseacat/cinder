# Getting Started

This guide covers the fundamentals of building collections with Cinder. For a quick start, see the [README](../README.md).

> **Note:** This documentation uses the unified `Cinder.collection` API. If you're upgrading from an older version, see the [Upgrading Guide](upgrading.md) for migration instructions.

## Table of Contents

- [Basic Usage](#basic-usage)
- [Layouts](#layouts)
- [Resource vs Query](#resource-vs-query)
- [Column Configuration](#column-configuration)
- [Action Columns](#action-columns)
- [Theming](#theming)
- [Localization](#localization)
- [Testing](#testing)

**See also:** [Filters](filters.md) | [Sorting](sorting.md) | [Advanced Features](advanced.md)

## Basic Usage

### Minimal Collection

The simplest possible collection displays data in a table (the default layout):

```heex
<Cinder.collection resource={MyApp.User} actor={@current_user}>
  <:col :let={user} field="name">{user.name}</:col>
  <:col :let={user} field="email">{user.email}</:col>
</Cinder.collection>
```

### With Filtering and Sorting

Add `filter` and `sort` attributes to enable interactive filtering and sorting:

```heex
<Cinder.collection resource={MyApp.User} actor={@current_user}>
  <:col :let={user} field="name" filter sort>{user.name}</:col>
  <:col :let={user} field="email" filter>{user.email}</:col>
  <:col :let={user} field="created_at" sort>{user.created_at}</:col>
</Cinder.collection>
```

Cinder automatically detects the appropriate filter type based on your Ash resource's field types:

- String fields → text filter
- Boolean fields → boolean filter (radio buttons)
- Date/datetime fields → date range filter
- Integer/decimal fields → number range filter
- Enum fields → select filter with options from the enum

## Layouts

Cinder supports three layouts: **table** (default), **list**, and **grid**. All layouts share the same filtering, sorting, search, and pagination functionality.

### Table Layout

Traditional HTML table with sortable column headers. This is the default when no `layout` is specified:

```heex
<Cinder.collection resource={MyApp.User} actor={@current_user}>
  <:col :let={user} field="name" filter sort>{user.name}</:col>
  <:col :let={user} field="email" filter>{user.email}</:col>
</Cinder.collection>
```

### List Layout

Vertical list for custom item rendering. Requires an `<:item>` slot to define how each record is displayed:

```heex
<Cinder.collection resource={MyApp.User} actor={@current_user} layout={:list}>
  <:col field="name" filter sort search />
  <:col field="email" filter />
  <:col field="status" filter={:select} />

  <:item :let={user}>
    <div class="flex items-center justify-between p-4 border-b">
      <div>
        <h3 class="font-bold">{user.name}</h3>
        <p class="text-gray-600">{user.email}</p>
      </div>
      <span class="px-2 py-1 text-sm bg-gray-100 rounded">{user.status}</span>
    </div>
  </:item>
</Cinder.collection>
```

In list and grid layouts, `<:col>` slots define which fields can be filtered, sorted, and searched—they don't render visible content. The `<:item>` slot controls the visual presentation of each record.

Since lists and grids don't have table headers, **sort controls render as a button group above the content**. Customize the label with `sort_label`:

```heex
<Cinder.collection resource={MyApp.User} actor={@current_user} layout={:list} sort_label="Order by:">
  ...
</Cinder.collection>
```

### Grid Layout

Responsive card grid for visual layouts like product catalogs:

```heex
<Cinder.collection resource={MyApp.Product} actor={@current_user} layout={:grid}>
  <:col field="name" filter sort search />
  <:col field="category" filter={:select} />
  <:col field="price" sort />

  <:item :let={product}>
    <div class="p-4 border rounded-lg">
      <h3 class="font-bold text-lg">{product.name}</h3>
      <p class="text-gray-600">{product.category}</p>
      <p class="text-xl font-semibold mt-2">${product.price}</p>
    </div>
  </:item>
</Cinder.collection>
```

### Grid Columns

Control the number of columns with `grid_columns`:

```heex
<!-- Fixed 4 columns -->
<Cinder.collection resource={MyApp.Product} actor={@current_user} layout={:grid} grid_columns={4}>
  ...
</Cinder.collection>

<!-- Responsive columns -->
<Cinder.collection
  resource={MyApp.Product}
  actor={@current_user}
  layout={:grid}
  grid_columns={[xs: 1, sm: 2, md: 3, lg: 4]}
>
  ...
</Cinder.collection>
```

Available breakpoints: `xs`, `sm`, `md`, `lg`, `xl`, `2xl`

### Custom Container Class

For full control over the container styling, use `container_class`:

```heex
<Cinder.collection
  resource={MyApp.Product}
  actor={@current_user}
  layout={:grid}
  container_class="grid grid-cols-2 lg:grid-cols-4 gap-8"
>
  ...
</Cinder.collection>
```

### Click Handlers

Make rows (table) or items (list/grid) clickable with the `click` attribute:

```heex
<Cinder.collection
  resource={MyApp.User}
  actor={@current_user}
  click={fn user -> JS.navigate(~p"/users/#{user.id}") end}
>
  <:col :let={user} field="name" filter sort>{user.name}</:col>
  <:col :let={user} field="email">{user.email}</:col>
</Cinder.collection>
```

The `click` function receives the record and should return a `Phoenix.LiveView.JS` command. Rows/items with click handlers automatically get hover effects and pointer cursor styling.

For more complex interactions:

```heex
<Cinder.collection
  resource={MyApp.User}
  actor={@current_user}
  click={fn user ->
    JS.push("select_user", value: %{id: user.id})
    |> JS.add_class("selected", to: "#user-#{user.id}")
  end}
>
  ...
</Cinder.collection>
```

## Resource vs Query

Cinder supports two ways to specify data: `resource` for simple cases, `query` for advanced requirements.

### When to Use Resource

Use `resource` for straightforward collections:

```heex
<Cinder.collection resource={MyApp.User} actor={@current_user}>
  <:col :let={user} field="name" filter sort>{user.name}</:col>
  <:col :let={user} field="email" filter>{user.email}</:col>
</Cinder.collection>
```

### When to Use Query

Use `query` when you need custom read actions, base filters, or tenant isolation:

```heex
<!-- Custom read action -->
<Cinder.collection
  query={Ash.Query.for_read(MyApp.User, :active_users)}
  actor={@current_user}
>
  ...
</Cinder.collection>

<!-- Pre-filtered data (filters are additive with user filters) -->
<Cinder.collection
  query={MyApp.User |> Ash.Query.filter(department: "Engineering")}
  actor={@current_user}
>
  ...
</Cinder.collection>

<!-- Multi-tenant admin interface -->
<Cinder.collection
  query={Ash.Query.for_read(MyApp.User, :admin_read)}
  actor={@current_user}
  tenant={@tenant}
>
  ...
</Cinder.collection>
```

**Important:** Query filters act as hidden base filters—user filters from the UI are added on top. If you filter by `department: "Engineering"` in the query and the user selects "Sales" in a department filter, the result will be empty (both conditions must match).

### Automatic Label Generation

Column labels are automatically generated from field names:

- `name` → "Name"
- `email_address` → "Email Address"
- `user.name` → "User Name"
- `created_at` → "Created At"

Override with `label`:

```heex
<:col :let={user} field="name" label="Full Name">{user.name}</:col>
```

## Column Configuration

### All Column Attributes

```heex
<:col
  :let={item}
  field="field_name"           # Field name (required for filter/sort)
  label="Custom Label"         # Override auto-generated label
  filter                       # Enable filtering (true, type atom, or config)
  sort                         # Enable sorting (true or config)
  search                       # Include in global search
  class="custom-class"         # CSS class for table cells
>
  {item.field_name}
</:col>
```

### Filter Configuration Formats

```heex
<!-- Auto-detect filter type from Ash field type -->
<:col field="status" filter />

<!-- Explicit filter type -->
<:col field="status" filter={:select} />

<!-- Full configuration with options -->
<:col field="status" filter={[type: :select, options: [{"Active", "active"}, {"Inactive", "inactive"}]]} />
```

### Sort Configuration

```heex
<!-- Basic sorting (cycle: nil → asc → desc → nil) -->
<:col field="name" sort />

<!-- No neutral state (always sorted) -->
<:col field="name" sort={[cycle: [:asc, :desc]]} />

<!-- Start with descending -->
<:col field="created_at" sort={[cycle: [:desc, :asc, nil]]} />
```

## Action Columns

Add columns without a `field` attribute for custom actions:

```heex
<Cinder.collection resource={MyApp.User} actor={@current_user}>
  <:col :let={user} field="name" filter sort>{user.name}</:col>
  <:col :let={user} field="email" filter>{user.email}</:col>

  <!-- Action column: no field, just custom content -->
  <:col :let={user} label="Actions">
    <div class="flex gap-2">
      <.link navigate={~p"/users/#{user.id}"} class="text-blue-600 hover:underline">
        View
      </.link>
      <.link navigate={~p"/users/#{user.id}/edit"} class="text-green-600 hover:underline">
        Edit
      </.link>
      <button phx-click="delete" phx-value-id={user.id} class="text-red-600 hover:underline">
        Delete
      </button>
    </div>
  </:col>
</Cinder.collection>
```

Action columns cannot have `filter` or `sort` since they don't correspond to data fields.

## Theming

### Built-in Themes

Cinder includes 9 built-in themes:

```heex
<Cinder.collection resource={MyApp.User} actor={@current_user} theme="modern">
  ...
</Cinder.collection>
```

Available themes:

- `"default"` - Clean, minimal styling
- `"modern"` - Contemporary look with shadows and rounded corners
- `"compact"` - Dense layout for data-heavy views
- `"dark"` - Dark mode styling
- `"retro"` - Nostalgic cyberpunk aesthetic
- `"futuristic"` - Bold, tech-forward design
- `"flowbite"` - Flowbite-compatible styling
- `"daisy_ui"` - DaisyUI-compatible styling

Set a default theme in your config:

```elixir
# config/config.exs
config :cinder, default_theme: "modern"
```

### Custom Themes

Create reusable custom themes as modules:

```elixir
defmodule MyApp.Theme.Corporate do
  use Cinder.Theme

  # Table
  set :container_class, "bg-white shadow-lg rounded-lg border border-gray-200"
  set :th_class, "px-6 py-4 bg-blue-50 text-left font-semibold text-blue-900"
  set :td_class, "px-6 py-4 border-b border-gray-100"
  set :row_class, "hover:bg-blue-50 transition-colors"

  # Filters
  set :filter_container_class, "bg-gray-50 p-4 rounded-lg mb-4"
  set :filter_text_input_class, "w-full px-3 py-2 border rounded focus:ring-2 focus:ring-blue-500"

  # Pagination
  set :pagination_button_class, "px-4 py-2 bg-blue-600 text-white rounded hover:bg-blue-700"
end
```

Use your custom theme:

```heex
<Cinder.collection resource={MyApp.User} actor={@current_user} theme={MyApp.Theme.Corporate}>
  ...
</Cinder.collection>
```

See [Theming Guide](theming.md) for complete theme customization options and all available theme properties.

## Localization

Cinder automatically uses your Phoenix app's locale for UI elements (pagination, filter labels, buttons, etc.). See the [Localization Guide](localization.md) for complete internationalization support.

```elixir
# Set locale in mount or plug
Gettext.put_locale("nl")

# Cinder UI automatically shows Dutch text
```

Available languages: Brazilian Portuguese (pt_BR), Danish (da), Dutch (nl), English (en), German (de), Norwegian (no), Swedish (sv).

## Testing

Use `render_async/1` to wait for async data loading in tests:

```elixir
test "lists all users", %{conn: conn} do
  user = insert(:user)

  {:ok, index_live, html} = live(conn, ~p"/users")

  assert html =~ "Loading..."
  assert render_async(index_live) =~ user.name
end
```
