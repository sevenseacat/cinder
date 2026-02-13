# Examples

This document provides comprehensive examples and detailed reference for all Cinder collection features. For a quick start, see the [README](../README.md).

> **Note:** This documentation uses the unified `Cinder.collection` API. If you're upgrading from an older version, see the [Upgrading Guide](upgrading.md) for migration instructions.

## Table of Contents

- [Basic Usage](#basic-usage)
- [Layouts](#layouts)
- [Resource vs Query](#resource-vs-query)
- [Column Configuration](#column-configuration)
- [Filter Types](#filter-types)
- [Filter-Only Slots](#filter-only-slots)
- [Global Search](#global-search)
- [Sorting](#sorting)
- [Custom Filter Functions](#custom-filter-functions)
- [Theming](#theming)
- [URL State Management](#url-state-management)
- [Relationship Fields](#relationship-fields)
- [Embedded Resources](#embedded-resources)
- [Action Columns](#action-columns)
- [Collection Refresh](#collection-refresh)
- [Loading, Empty & Error States](#loading-empty-error-states)
- [Performance Optimization](#performance-optimization)
- [Localization](#localization)
- [Selection & Bulk Actions](#selection--bulk-actions)
- [Testing](#testing)

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

## Filter Types

Cinder automatically detects the appropriate filter type based on your Ash resource's field types. You can also explicitly specify filter types when needed.

### Automatic Type Detection

When you use `filter` without specifying a type, Cinder inspects your Ash resource:

| Ash Field Type                        | Filter Type     | UI Component                    |
| ------------------------------------- | --------------- | ------------------------------- |
| `:string`, `:ci_string`               | `:text`         | Text input with contains search |
| `:boolean`                            | `:boolean`      | Radio buttons (Yes/No)          |
| `:date`, `:datetime`, `:utc_datetime` | `:date_range`   | From/To date pickers            |
| `:integer`, `:decimal`, `:float`      | `:number_range` | Min/Max number inputs           |
| `Ash.Type.Enum`                       | `:select`       | Dropdown with enum values       |
| `{:array, _}`                         | `:multi_select` | Multi-select for array fields   |

### Text Filter

Default for string fields. Performs case-insensitive contains search:

```heex
<!-- Basic text filter (auto-detected for string fields) -->
<:col :let={article} field="title" filter>{article.title}</:col>

<!-- With custom placeholder -->
<:col
  :let={article}
  field="content"
  filter={[type: :text, placeholder: "Search content..."]}
>
  {String.slice(article.content, 0, 100)}...
</:col>

<!-- Case-sensitive search -->
<:col
  :let={article}
  field="author_name"
  filter={[type: :text, case_sensitive: true]}
>
  {article.author_name}
</:col>
```

### Select Filter

Dropdown for single-value selection. **Automatically populated for Ash enum fields:**

```heex
<!-- Enum field: options auto-populated from MyApp.UserRole enum -->
<:col :let={user} field="role" filter>{user.role}</:col>

<!-- Explicit options for non-enum fields -->
<:col
  :let={user}
  field="status"
  filter={[type: :select, options: [
    {"Active", "active"},
    {"Pending", "pending"},
    {"Suspended", "suspended"}
  ]]}
>
  {user.status}
</:col>

<!-- With custom prompt text -->
<:col
  :let={user}
  field="department"
  filter={[type: :select, options: @departments, prompt: "All Departments"]}
>
  {user.department}
</:col>
```

### Multi-Select Filter

For filtering by multiple values. Two UI styles available:

**Tag-based dropdown (`:multi_select`):**

```heex
<:col
  :let={product}
  field="tags"
  filter={[type: :multi_select, options: @available_tags]}
>
  {Enum.join(product.tags, ", ")}
</:col>
```

**Checkbox list (`:multi_checkboxes`):**

```heex
<:col
  :let={user}
  field="roles"
  filter={[type: :multi_checkboxes, options: [
    {"Admin", "admin"},
    {"Editor", "editor"},
    {"Viewer", "viewer"}
  ]]}
>
  {Enum.join(user.roles, ", ")}
</:col>
```

**Match Mode:** Control AND vs OR logic for multiple selections:

```heex
<!-- Match ANY selected value (default) - records with tag A OR tag B -->
<:col field="tags" filter={[type: :multi_select, options: @tags, match_mode: :any]} />

<!-- Match ALL selected values - records with tag A AND tag B -->
<:col field="tags" filter={[type: :multi_select, options: @tags, match_mode: :all]} />
```

### Boolean Filter

Radio buttons for true/false filtering:

```heex
<!-- Basic boolean filter -->
<:col :let={user} field="is_active" filter={:boolean}>
  {if user.is_active, do: "Active", else: "Inactive"}
</:col>

<!-- Custom labels -->
<:col
  :let={user}
  field="verified"
  filter={[type: :boolean, labels: %{true: "Verified", false: "Unverified"}]}
>
  {if user.verified, do: "✓", else: "✗"}
</:col>
```

### Radio Group Filter

Radio buttons for selecting one value from a set of mutually exclusive options. Unlike boolean (which is limited to true/false), radio group supports arbitrary options:

```heex
<!-- Status filter with custom options -->
<:col
  :let={order}
  field="status"
  filter={[type: :radio_group, options: [
    {"Pending", "pending"},
    {"Shipped", "shipped"},
    {"Delivered", "delivered"}
  ]]}
>
  {order.status}
</:col>
```

The boolean filter delegates to radio group internally — use `:boolean` for true/false fields and `:radio_group` when you need custom options.

### Checkbox Filter

Single checkbox for "show only X" filtering:

```heex
<!-- Boolean field: filters for true when checked -->
<:col :let={article} field="published" filter={[type: :checkbox, label: "Published only"]}>
  {if article.published, do: "✓", else: "✗"}
</:col>

<!-- Non-boolean field: filters for specific value when checked -->
<:col :let={article} field="priority" filter={[type: :checkbox, value: "high", label: "High priority only"]}>
  {article.priority}
</:col>
```

### Date Range Filter

From/To date pickers for date filtering:

```heex
<!-- Auto-detected for date/datetime fields -->
<:col :let={order} field="created_at" filter sort>{order.created_at}</:col>

<!-- Include time selection -->
<:col
  :let={order}
  field="shipped_at"
  filter={[type: :date_range, include_time: true]}
>
  {order.shipped_at}
</:col>
```

### Number Range Filter

Min/Max inputs for numeric filtering:

```heex
<!-- Auto-detected for integer/decimal fields -->
<:col :let={product} field="price" filter sort>{product.price}</:col>

<!-- With constraints -->
<:col
  :let={product}
  field="quantity"
  filter={[type: :number_range, min: 0, max: 10000, step: 10]}
>
  {product.quantity}
</:col>
```

### Autocomplete Filter

Searchable dropdown for fields with many options. Options are filtered server-side as you type:

```heex
<!-- Basic autocomplete with static options -->
<:col
  :let={order}
  field="customer_id"
  filter={[type: :autocomplete, options: @customers]}
>
  {order.customer.name}
</:col>

<!-- With custom placeholder and result limit -->
<:col
  :let={order}
  field="product_id"
  filter={[
    type: :autocomplete,
    options: @products,
    placeholder: "Search products...",
    max_results: 15
  ]}
>
  {order.product.name}
</:col>
```

Options are `{label, value}` tuples, same as the select filter. The `max_results` option (default: 10) limits how many matching options are shown at once.

## Filter-Only Slots

Add filtering capability for fields without displaying them as columns. Useful for filtering by metadata or keeping tables focused:

```heex
<Cinder.collection resource={MyApp.Order} actor={@current_user}>
  <:col :let={order} field="order_number">{order.order_number}</:col>
  <:col :let={order} field="total">${order.total}</:col>

  <!-- Filter-only slots: filter UI appears, but no column in table -->
  <:filter field="created_at" type="date_range" label="Order Date" />
  <:filter field="status" type="select" options={["pending", "shipped", "delivered"]} />
  <:filter field="customer_name" type="text" placeholder="Customer name..." />
</Cinder.collection>
```

### Filter Slot Attributes

```heex
<:filter
  field="field_name"           # Required
  type="filter_type"           # Optional, auto-detected if not provided
  label="Custom Label"         # Optional
  options={[...]}              # For select/multi-select
  placeholder="..."            # For text filters
  operator={:contains}         # For text filters
  case_sensitive={true}        # For text filters
  match_mode={:any}            # For multi-select
  min={0}                      # For number range
  max={100}                    # For number range
  step={1}                     # For number range
  include_time={true}          # For date range
  fn={&custom_filter/2}        # Custom filter function
/>
```

### When to Use Filter-Only Slots

- Filter by metadata (created_at, updated_at) without cluttering the display
- Add filters for fields shown elsewhere on the page
- Create admin interfaces with many filter options
- Keep tables focused on essential information

## Global Search

Search provides a single text input that filters across multiple columns simultaneously. This is different from individual column filters—search queries all marked columns at once using OR logic.

### How Search Works

When a user types in the search box, Cinder filters records where **any** of the searchable columns contain the search term. For example, searching "smith" might match:

- A user named "John Smith"
- A user with email "smith@example.com"
- A user in the "Blacksmith" department

### Enabling Search

Search automatically appears when any column has the `search` attribute:

```heex
<Cinder.collection resource={MyApp.User} actor={@current_user}>
  <!-- These columns are searchable -->
  <:col :let={user} field="name" filter search>{user.name}</:col>
  <:col :let={user} field="email" filter search>{user.email}</:col>

  <!-- This column is filterable but NOT searchable -->
  <:col :let={user} field="role" filter>{user.role}</:col>
</Cinder.collection>
```

### Custom Search Configuration

Customize the search UI:

```heex
<Cinder.collection
  resource={MyApp.Album}
  actor={@current_user}
  search={[label: "Find Albums", placeholder: "Search by title or artist..."]}
>
  <:col :let={album} field="title" search>{album.title}</:col>
  <:col :let={album} field="artist.name" search>{album.artist.name}</:col>
</Cinder.collection>
```

### Disable Search

Even if columns have `search`, you can disable the search UI:

```heex
<Cinder.collection resource={MyApp.Album} actor={@current_user} search={false}>
  <:col :let={album} field="title" search>{album.title}</:col>
</Cinder.collection>
```

### Custom Search Function

For advanced search logic (fuzzy matching, weighted results, etc.):

```heex
<Cinder.collection
  resource={MyApp.Album}
  actor={@current_user}
  search={[fn: &MyApp.CustomSearch.advanced_search/3]}
>
  ...
</Cinder.collection>
```

```elixir
defmodule MyApp.CustomSearch do
  require Ash.Query

  def advanced_search(query, searchable_columns, search_term) do
    # searchable_columns is a list of column configs with :field keys
    # Return a modified Ash.Query
    Ash.Query.filter(query, fragment("? ILIKE ?", name, ^"%#{search_term}%"))
  end
end
```

## Sorting

### Basic Sorting

Add `sort` to make columns sortable. Click column headers to cycle through sort states:

```heex
<Cinder.collection resource={MyApp.User} actor={@current_user}>
  <:col :let={user} field="name" sort>{user.name}</:col>
  <:col :let={user} field="email">{user.email}</:col>
  <:col :let={user} field="created_at" sort>{user.created_at}</:col>
</Cinder.collection>
```

### Sort Cycles

The default cycle is: unsorted → ascending → descending → unsorted

Customize with `cycle`:

```heex
<!-- No neutral state: always sorted one way or the other -->
<:col field="name" sort={[cycle: [:asc, :desc]]} />

<!-- Start descending (good for dates where newest-first is common) -->
<:col field="created_at" sort={[cycle: [:desc, :asc, nil]]} />

<!-- Ash null-handling directions -->
<:col field="completed_at" sort={[cycle: [:desc_nils_last, :asc_nils_first, nil]]} />
```

### Sort Mode

By default, clicking multiple column headers creates multi-column sorting ("sort by A, then by B"). Use `sort_mode` to change this behavior:

```heex
<!-- Default: additive sorting (clicking B while sorted by A gives "A then B") -->
<Cinder.collection resource={MyApp.User} actor={@current_user}>
  <:col :let={user} field="name" sort>{user.name}</:col>
  <:col :let={user} field="created_at" sort>{user.created_at}</:col>
</Cinder.collection>

<!-- Exclusive: clicking a column replaces existing sorts -->
<Cinder.collection resource={MyApp.User} actor={@current_user} sort_mode="exclusive">
  <:col :let={user} field="name" sort>{user.name}</:col>
  <:col :let={user} field="created_at" sort>{user.created_at}</:col>
</Cinder.collection>
```

Sort modes:
- `"additive"` (default) - New sorts are added to existing ones
- `"exclusive"` - Clicking a column replaces all existing sorts

### Default Sort Order

Provide a default sort via the `query` parameter. User sorting replaces (not adds to) the default:

```heex
<Cinder.collection
  query={MyApp.User |> Ash.Query.sort(created_at: :desc)}
  actor={@current_user}
>
  <:col :let={user} field="name" sort>{user.name}</:col>
  <:col :let={user} field="created_at" sort>{user.created_at}</:col>
</Cinder.collection>
```

#### Default Sort on Embedded Fields

For embedded fields, use `Cinder.QueryBuilder.apply_sorting/2` with the double underscore notation:

```heex
<Cinder.collection
  query={MyApp.User |> Cinder.QueryBuilder.apply_sorting([{"profile__last_name", :asc}])}
  actor={@current_user}
>
  <:col :let={user} field="profile__last_name" sort>{user.profile.last_name}</:col>
</Cinder.collection>
```

## Custom Filter Functions

For complex filtering logic that goes beyond simple field matching:

```heex
<Cinder.collection resource={MyApp.Invoice} actor={@current_user}>
  <:col
    :let={invoice}
    field="status"
    filter={[type: :select, options: @statuses, fn: &filter_invoice_status/2]}
  >
    {invoice.status}
  </:col>
</Cinder.collection>
```

```elixir
require Ash.Query

def filter_invoice_status(query, %{value: "overdue"}) do
  # Custom business logic: "overdue" means pending AND past due date
  today = Date.utc_today()
  Ash.Query.filter(query, status == "pending" and due_date < ^today)
end

def filter_invoice_status(query, %{value: status}) do
  # Standard equality for other values
  Ash.Query.filter(query, status == ^status)
end
```

### Function Signature

Custom filter functions receive:

1. `query` - The current `Ash.Query`
2. `filter_config` - Map containing `:value` and other filter options

Return a modified `Ash.Query`.

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

## Localization

Cinder automatically uses your Phoenix app's locale for UI elements (pagination, filter labels, buttons, etc.). See the [Localization Guide](localization.md) for complete internationalization support.

```elixir
# Set locale in mount or plug
Gettext.put_locale("nl")

# Cinder UI automatically shows Dutch text
```

Available languages: English (en), Dutch (nl), Swedish (sv).

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
