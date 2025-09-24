# Cinder Usage Rules

Cinder is a data table component for Phoenix LiveView with Ash Framework integration.

## Basic Usage

```heex
<Cinder.Table.table resource={MyApp.User} actor={@current_user}>
  <:col :let={user} field="name" filter sort>{user.name}</:col>
  <:col :let={user} field="email" filter>{user.email}</:col>
  <:col :let={user} field="created_at" sort>{user.created_at}</:col>
</Cinder.Table.table>
```

## Data Sources

```heex
<!-- Resource -->
<Cinder.Table.table resource={MyApp.User} actor={@current_user}>

<!-- Pre-configured query -->
<Cinder.Table.table query={MyApp.User |> Ash.Query.filter(active: true)} actor={@current_user}>

<!-- Custom read action -->
<Cinder.Table.table query={Ash.Query.for_read(MyApp.User, :active_users)} actor={@current_user}>
```

## Field Notation

- **Direct fields**: `field="name"`
- **Relationships**: `field="department.name"`
- **Embedded resources**: `field="settings__country"` (double underscore)

## Column Configuration

### Data Columns
- `field` - required for data columns
- `filter` - enables filtering (auto-detects type)
- `sort` - enables sorting
- `search` - includes field in table search
- `label="Custom"` - override column header

### Filter Configuration
```heex
<!-- Auto-detected -->
<:col field="status" filter>Status</:col>

<!-- Specify type -->
<:col field="status" filter={:select}>Status</:col>

<!-- Unified syntax with options -->
<:col field="status" filter={[type: :select, prompt: "All Statuses", options: @statuses]}>Status</:col>
<:col field="price" filter={[type: :number_range, min: 0, max: 1000]}>Price</:col>
<:col field="tags" filter={[type: :multi_select, match_mode: :any, prompt: "Select tags"]}>Tags</:col>
<:col field="active" filter={[type: :boolean, labels: %{true: "Active", false: "Inactive"}]}>Status</:col>

<!-- Custom filter function -->
<:col field="name" filter={[type: :text, fn: &custom_name_filter/2]}>Name</:col>
```

### Sorting Configuration
```heex
<!-- Basic sorting -->
<:col field="name" sort>Name</:col>

<!-- Custom sort cycles -->
<:col field="priority" sort={[cycle: [nil, :desc_nils_first, :asc_nils_last]]}>Priority</:col>
```

### Action Columns
```heex
<:col :let={user} label="Actions">
  <.link patch={~p"/users/#{user.id}/edit"}>Edit</.link>
  <button phx-click="delete" phx-value-id={user.id}>Delete</button>
</:col>
```

## Filter-Only Slots

Filter on fields without displaying them as columns:

```heex
<Cinder.Table.table resource={MyApp.User} actor={@current_user}>
  <:col :let={user} field="name" filter sort>{user.name}</:col>
  <!-- Filter-only fields -->
  <:filter field="department.name" type="select" options={@departments} />
  <:filter field="active" type="boolean" />
  <:filter field="created_at" type="date_range" />
</Cinder.Table.table>
```

## Table Configuration

### Required
- `resource={Resource}` or `query={query}` - data source
- `actor={@current_user}` - required for Ash authorization

### Key Options
- `theme="modern"` - built-in themes: default, modern, retro, futuristic, dark, daisy_ui, flowbite, compact, pastel
- `page_size={25}` - fixed page size
- `page_size={[default: 25, options: [10, 25, 50, 100]]}` - configurable with dropdown
- `url_state={@url_state}` - enable URL synchronization
- `row_click={fn item -> JS.navigate(~p"/path/#{item.id}") end}` - row interactivity
- `query_opts={[timeout: 30_000, authorize?: false]}` - Ash query options
- `scope={scope}` - Ash authorization scope
- `tenant={tenant}` - multi-tenancy support

### Search Configuration
```heex
<!-- Auto-enabled when columns have search attribute -->
<:col :let={user} field="name" search filter>{user.name}</:col>

<!-- Custom search configuration -->
<Cinder.Table.table search={[label: "Search users", placeholder: "Enter name or email"]}>

<!-- Explicitly disable search -->
<Cinder.Table.table search={false}>
```

### Display Options
- `empty_message="No records found"` - custom empty state
- `loading_message="Loading..."` - custom loading state
- `show_filters={true}` - show/hide filter UI
- `filters_label="🔍 Filters"` - customize filter section label

## Built-in Filter Types

Auto-detected from Ash resource attributes:

- **Text** (`:text`) - string/atom fields → contains/starts_with/ends_with
  - Options: `operator`, `case_sensitive`, `placeholder`
- **Select** (`:select`) - enum attributes → dropdown
  - Options: `options`, `prompt`
- **Boolean** (`:boolean`) - boolean fields → true/false radio buttons
  - Options: `labels` map with `true`/`false` keys
- **Date Range** (`:date_range`) - date/datetime fields → date pickers
  - Options: `include_time`, `format`
- **Number Range** (`:number_range`) - numeric fields → min/max inputs
  - Options: `min`, `max`, `step`
- **Multi-Select** (`:multi_select`) - array fields → tag-based selection
  - Options: `options`, `prompt`, `match_mode` (:any/:all)
- **Multi-Checkboxes** (`:multi_checkboxes`) - array fields → checkbox interface
  - Options: `options`, `match_mode` (:any/:all)
- **Checkbox** (`:checkbox`) - single checkbox for "show only X"
  - Options: `value`, `label`

## URL State Management

Enable bookmarkable, shareable table states:

```elixir
defmodule MyAppWeb.UsersLive do
  use MyAppWeb, :live_view
  use Cinder.Table.UrlSync

  def handle_params(params, uri, socket) do
    socket = Cinder.Table.UrlSync.handle_params(params, uri, socket)
    {:noreply, socket}
  end

  def render(assigns) do
    ~H"""
    <Cinder.Table.table resource={MyApp.User} actor={@current_user} url_state={@url_state}>
      <:col :let={user} field="name" filter sort>{user.name}</:col>
    </Cinder.Table.table>
    """
  end
end
```

## Custom Filters

### 1. Configuration
```elixir
# config/config.exs
config :cinder, :filters, [
  slider: MyApp.Filters.Slider,
  color_picker: MyApp.Filters.ColorPicker
]
```

### 2. Application Setup
```elixir
# application.ex
def start(_type, _args) do
  Cinder.setup()  # Registers configured filters
  # ... rest of startup
end
```

### 3. Filter Module
```elixir
defmodule MyApp.Filters.Slider do
  @behaviour Cinder.Filter
  use Phoenix.Component

  @impl true
  def render(column, current_value, theme, assigns) do
    # Return HEEx template
  end

  @impl true
  def process(raw_value, column) do
    # Transform form input to filter value struct
    %{type: :slider, value: raw_value, operator: :between}
  end

  @impl true
  def validate(filter_value), do: true

  @impl true
  def default_options, do: [min: 0, max: 100, step: 1]

  @impl true
  def empty?(value), do: is_nil(value)

  @impl true
  def build_query(query, field, filter_value) do
    # Build Ash query filter
  end
end
```

### 4. Usage
```heex
<:col field="price" filter={[type: :slider, min: 0, max: 1000, step: 10]}>Price</:col>
```

## Table Refresh

Refresh table data while preserving state:

```elixir
import Cinder.Table.Refresh

def handle_event("delete", %{"id" => id}, socket) do
  # ... delete logic ...
  {:noreply, refresh_table(socket, "table-id")}
end

# Refresh multiple tables
{:noreply, refresh_tables(socket, ["table1", "table2"])}
```

## Theming

### Global Configuration
```elixir
# config/config.exs
config :cinder, default_theme: "modern"
```

### Per-Table Themes
```heex
<Cinder.Table.table theme="dark" resource={MyApp.User}>
```

### Available Themes
- `"default"` - minimal styling
- `"modern"` - clean, contemporary design
- `"dark"` - dark mode styling
- `"retro"` - vintage appearance
- `"futuristic"` - sci-fi inspired
- `"daisy_ui"` - DaisyUI component styles
- `"flowbite"` - Flowbite design system
- `"compact"` - dense layout
- `"pastel"` - soft color palette

## Testing

Use `render_async` for data-dependent assertions:

```elixir
{:ok, view, html} = live(conn, ~p"/users")
assert html =~ "Loading..."
assert render_async(view) =~ "John Doe"
```
