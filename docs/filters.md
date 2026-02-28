# Filters

This guide covers all filter types, search, and controls customization. For basic setup, see [Getting Started](getting-started.md).

## Table of Contents

- [Filter Types](#filter-types)
- [Filter-Only Slots](#filter-only-slots)
- [Collapsible Filters](#collapsible-filters)
- [Global Search](#global-search)
- [Custom Filter Functions](#custom-filter-functions)
- [Custom Controls Layout](#custom-controls-layout)

**See also:** [Sorting](sorting.md) | [Custom Filters](custom-filters.md)

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

## Collapsible Filters

For tables with many filters, you can make the filter section collapsible. The filter header (label, active count, "Clear all") stays visible while the filter inputs toggle on click—entirely client-side with no server round-trip.

### Per-Component

```heex
<!-- Filters start collapsed -->
<Cinder.collection resource={MyApp.User} actor={@current_user} show_filters={:toggle}>
  <:col :let={user} field="name" filter sort>{user.name}</:col>
  <:col :let={user} field="email" filter>{user.email}</:col>
  <:col :let={user} field="status" filter={:select}>{user.status}</:col>
</Cinder.collection>

<!-- Filters start expanded (with toggle button to collapse) -->
<Cinder.collection resource={MyApp.User} actor={@current_user} show_filters={:toggle_open}>
  ...
</Cinder.collection>
```

String values `"toggle"` and `"toggle_open"` are also accepted.

### Global Default

Set the default for all collections in your config, so you don't have to add `show_filters` to every component:

```elixir
# config/config.exs
config :cinder, show_filters: :toggle
```

Individual collections can still override:

```heex
<!-- This collection always shows filters (overrides global :toggle) -->
<Cinder.collection resource={MyApp.User} actor={@current_user} show_filters={true}>
  ...
</Cinder.collection>
```

### All `show_filters` Values

| Value | Behaviour |
|-------|-----------|
| `nil` (default) | Auto-detect: show if filterable columns or search exist |
| `true` | Always show filters |
| `false` | Never show filters |
| `:toggle` / `"toggle"` | Collapsible, starts collapsed |
| `:toggle_open` / `"toggle_open"` | Collapsible, starts expanded |

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

## Custom Controls Layout

The `:controls` slot lets you customize how filters and search are rendered while keeping Cinder's state management, URL sync, and query building intact. This is useful when you need to reorder filters, add custom content between them, or use a completely different layout.

### Basic Usage

The slot receives a controls data map via `:let`:

```heex
<Cinder.collection resource={MyApp.User} actor={@current_user}>
  <:col :let={user} field="name" filter sort search>{user.name}</:col>
  <:col :let={user} field="status" filter={:select}>{user.status}</:col>

  <:controls :let={controls}>
    <div class="flex items-center gap-4 mb-4">
      <Cinder.Controls.render_search
        search={controls.search}
        theme={controls.theme}
        target={controls.target}
      />
      <button phx-click="export">Export</button>
    </div>
    <div class="grid grid-cols-2 gap-4">
      <Cinder.Controls.render_filter
        :for={{_name, filter} <- controls.filters}
        filter={filter}
        theme={controls.theme}
        target={controls.target}
      />
    </div>
  </:controls>
</Cinder.collection>
```

### Available Helpers

- `Cinder.Controls.render_filter/1` — renders a single filter (label + input + clear button)
- `Cinder.Controls.render_search/1` — renders the search input
- `Cinder.Controls.render_header/1` — renders the default header (title, active count, clear all, toggle)

### Controls Data Map

The `:let` binding provides:

| Key | Type | Description |
|-----|------|-------------|
| `filters` | keyword list | Filters keyed by field atom, preserving column order. Access by name: `controls.filters[:status]` |
| `search` | map or nil | Search input data (value, name, label, placeholder, id), or nil when disabled |
| `active_filter_count` | integer | Number of currently active filters |
| `target` | any | LiveComponent target for `phx-target` |
| `theme` | map | Resolved theme map |
| `table_id` | string | DOM ID prefix |
| `filters_label` | string | Translated label for filters section |
| `filter_mode` | any | Current filter display mode |
| `filter_values` | map | Shared filter values (for render helpers) |
| `raw_filter_params` | map | Raw form params (for autocomplete filters) |

### Selective Rendering

Filters is a keyword list, so you can access individual filters directly by field name:

```heex
<:controls :let={controls}>
  <Cinder.Controls.render_header {controls} />
  <div class="flex gap-2">
    <Cinder.Controls.render_filter
      filter={controls.filters[:status]}
      theme={controls.theme}
      target={controls.target}
    />
    <Cinder.Controls.render_filter
      filter={controls.filters[:name]}
      theme={controls.theme}
      target={controls.target}
    />
  </div>
</:controls>
```

### Mixing Custom and Default Rendering

You can use the render helpers for some filters and your own markup for others. As long as your custom inputs use the correct `name` attribute (e.g., `name="filters[status]"` for a field called "status"), Cinder's form handling picks them up automatically:

```heex
<:controls :let={controls}>
  <Cinder.Controls.render_header {controls} />
  <div class="flex gap-4">
    <Cinder.Controls.render_filter
      filter={controls.filters[:name]}
      theme={controls.theme}
      target={controls.target}
    />
    <%!-- Custom select with your own component --%>
    <.my_custom_select
      name="filters[status]"
      value={controls.filters[:status].value}
      options={[{"Active", "active"}, {"Inactive", "inactive"}]}
    />
  </div>
</:controls>
```

### How It Works

The `:controls` slot replaces the entire controls section (header + filter inputs) but **not** the form wrapper. Cinder automatically wraps your slot content in a `<form>` with `phx-change="filter_change"`, so filter state, URL sync, and query building continue to work without any extra setup.
