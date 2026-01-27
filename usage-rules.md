# Cinder Usage Rules

Cinder is a data collection component for Phoenix LiveView with Ash Framework integration. It supports table, list, and grid layouts with shared filtering, sorting, and pagination.

## Basic Usage

```heex
<Cinder.collection resource={MyApp.User} actor={@current_user}>
  <:col :let={user} field="name" filter sort>{user.name}</:col>
  <:col :let={user} field="email" filter>{user.email}</:col>
  <:col :let={user} field="created_at" sort>{user.created_at}</:col>
</Cinder.collection>
```

## Layouts

```heex
<!-- Table (default) -->
<Cinder.collection resource={MyApp.User} actor={@current_user}>
  <:col :let={user} field="name" filter sort>{user.name}</:col>
</Cinder.collection>

<!-- List -->
<Cinder.collection resource={MyApp.User} actor={@current_user} layout={:list}>
  <:col field="name" filter sort />
  <:item :let={user}>
    <div class="p-4">{user.name}</div>
  </:item>
</Cinder.collection>

<!-- Grid -->
<Cinder.collection resource={MyApp.Product} actor={@current_user} layout={:grid} grid_columns={[xs: 1, md: 2, lg: 3]}>
  <:col field="name" filter sort />
  <:item :let={product}>
    <div class="p-4 border rounded">{product.name}</div>
  </:item>
</Cinder.collection>
```

## Data Sources

```heex
<!-- Resource -->
<Cinder.collection resource={MyApp.User} actor={@current_user}>

<!-- Pre-configured query -->
<Cinder.collection query={MyApp.User |> Ash.Query.filter(active: true)} actor={@current_user}>

<!-- Custom read action -->
<Cinder.collection query={Ash.Query.for_read(MyApp.User, :active_users)} actor={@current_user}>
```

## Field Notation

- **Direct fields**: `field="name"`
- **Relationships**: `field="department.name"` (dot notation)
- **Embedded resources**: `field="settings__country"` (double underscore)

## Column Configuration

### Data Columns
- `field` - required for data columns
- `filter` - enables filtering (auto-detects type from Ash attribute)
- `sort` - enables sorting
- `search` - includes field in global search
- `label="Custom"` - override column header

### Filter Configuration
```heex
<!-- Auto-detected from Ash attribute type -->
<:col field="status" filter />

<!-- Specify type -->
<:col field="status" filter={:select} />

<!-- Full configuration -->
<:col field="status" filter={[type: :select, prompt: "All Statuses", options: @statuses]} />
<:col field="price" filter={[type: :number_range, min: 0, max: 1000]} />
<:col field="tags" filter={[type: :multi_select, match_mode: :any]} />
<:col field="active" filter={[type: :boolean, labels: %{true: "Active", false: "Inactive"}]} />

<!-- Custom filter function -->
<:col field="name" filter={[type: :text, fn: &custom_name_filter/2]} />
```

### Sorting Configuration
```heex
<!-- Basic sorting (cycle: nil → asc → desc → nil) -->
<:col field="name" sort />

<!-- Custom sort cycles -->
<:col field="priority" sort={[cycle: [:desc, :asc]]} />
<:col field="created_at" sort={[cycle: [:desc, :asc, nil]]} />
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
<Cinder.collection resource={MyApp.User} actor={@current_user}>
  <:col :let={user} field="name" filter sort>{user.name}</:col>
  
  <!-- Filter-only fields -->
  <:filter field="department.name" type="select" options={@departments} />
  <:filter field="active" type="boolean" />
  <:filter field="created_at" type="date_range" />
</Cinder.collection>
```

## Collection Configuration

### Required
- `resource={Resource}` or `query={query}` - data source
- `actor={@current_user}` - required for Ash authorization

### Key Options
- `layout={:table | :list | :grid}` - layout type (default: `:table`)
- `grid_columns={4}` or `grid_columns={[xs: 1, md: 2, lg: 3]}` - grid column count
- `theme="modern"` - built-in themes: default, modern, retro, futuristic, dark, daisy_ui, flowbite, compact
- `page_size={25}` - fixed page size
- `page_size={[default: 25, options: [10, 25, 50, 100]]}` - configurable with dropdown
- `url_state={@url_state}` - enable URL synchronization
- `click={fn item -> JS.navigate(~p"/path/#{item.id}") end}` - row/item click handler
- `query_opts={[timeout: 30_000, load: [:association]]}` - Ash query options
- `tenant={@tenant}` - multi-tenancy support

### Search Configuration
```heex
<!-- Auto-enabled when columns have search attribute -->
<:col :let={user} field="name" search filter>{user.name}</:col>

<!-- Custom search configuration -->
<Cinder.collection search={[label: "Search users", placeholder: "Enter name or email"]}>

<!-- Disable search -->
<Cinder.collection search={false}>
```

### Display Options
- `empty_message="No records found"` - custom empty state
- `loading_message="Loading..."` - custom loading state
- `show_filters={true}` - show/hide filter UI
- `filters_label="🔍 Filters"` - customize filter section label
- `sort_label="Sort by:"` - label for sort controls (list/grid layouts)

## Built-in Filter Types

Auto-detected from Ash resource attributes:

| Ash Type | Filter Type | UI |
|----------|-------------|-----|
| `:string` | `:text` | Text input with contains search |
| `:boolean` | `:boolean` | Radio buttons (Yes/No) |
| `:date`, `:datetime` | `:date_range` | From/To date pickers |
| `:integer`, `:decimal` | `:number_range` | Min/Max inputs |
| `Ash.Type.Enum` | `:select` | Dropdown with enum values |
| `{:array, _}` | `:multi_select` | Multi-select dropdown |

### Filter Type Options

- **Text**: `operator`, `case_sensitive`, `placeholder`
- **Select**: `options`, `prompt`
- **Boolean**: `labels` map with `true`/`false` keys
- **Date Range**: `include_time`
- **Number Range**: `min`, `max`, `step`
- **Multi-Select**: `options`, `prompt`, `match_mode` (`:any`/`:all`)
- **Checkbox**: `value`, `label`

## URL State Management

Enable bookmarkable, shareable collection states:

```elixir
defmodule MyAppWeb.UsersLive do
  use MyAppWeb, :live_view
  use Cinder.UrlSync

  def handle_params(params, uri, socket) do
    socket = Cinder.UrlSync.handle_params(params, uri, socket)
    {:noreply, socket}
  end

  def render(assigns) do
    ~H"""
    <Cinder.collection resource={MyApp.User} actor={@current_user} url_state={@url_state} id="users">
      <:col :let={user} field="name" filter sort>{user.name}</:col>
    </Cinder.collection>
    """
  end
end
```

## Collection Refresh

Refresh data while preserving filters, sorting, and pagination:

```elixir
import Cinder.Refresh

def handle_event("delete", %{"id" => id}, socket) do
  # ... delete logic ...
  {:noreply, refresh_table(socket, "collection-id")}
end

# Refresh multiple collections
{:noreply, refresh_tables(socket, ["collection1", "collection2"])}

# Or use top-level delegates
Cinder.refresh_table(socket, "collection-id")
```

## Custom Filters

### 1. Configuration
```elixir
# config/config.exs
config :cinder, :filters, [
  slider: MyApp.Filters.Slider
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
  def render(column, current_value, theme, assigns), do: # HEEx template

  @impl true
  def process(raw_value, column), do: %{type: :slider, value: raw_value}

  @impl true
  def validate(filter_value), do: true

  @impl true
  def default_options, do: [min: 0, max: 100, step: 1]

  @impl true
  def empty?(value), do: is_nil(value)

  @impl true
  def build_query(query, field, filter_value), do: # Ash query filter
end
```

### 4. Usage
```heex
<:col field="price" filter={[type: :slider, min: 0, max: 1000]} />
```

## Theming

### Global Configuration
```elixir
# config/config.exs
config :cinder, default_theme: "modern"
```

### Per-Collection Theme
```heex
<Cinder.collection theme="dark" resource={MyApp.User} actor={@current_user}>
```

### Available Themes
- `"default"` - minimal styling
- `"modern"` - clean, contemporary design
- `"dark"` - dark mode styling
- `"retro"` - cyberpunk aesthetic
- `"futuristic"` - sci-fi inspired
- `"daisy_ui"` - DaisyUI component styles
- `"flowbite"` - Flowbite design system
- `"compact"` - dense layout

### Custom Theme Module
```elixir
defmodule MyApp.CustomTheme do
  use Cinder.Theme

  set :container_class, "bg-white shadow rounded-lg"
  set :th_class, "px-4 py-2 text-left font-semibold"
end
```

## Selection & Bulk Actions

Enable checkbox selection and bulk operations on selected records:

```heex
<Cinder.collection resource={MyApp.User} actor={@current_user} selectable>
  <:col :let={user} field="name" filter sort>{user.name}</:col>

  <!-- Themed buttons (recommended): use label and variant for auto-styled buttons -->
  <:bulk_action action={:archive} label="Archive ({count})" variant={:primary} />
  <:bulk_action action={:export} label="Export" variant={:secondary} />
  <:bulk_action action={:destroy} label="Delete" variant={:danger} confirm="Delete {count}?" />

  <!-- Custom buttons: provide inner content for full control -->
  <:bulk_action action={&MyApp.Users.soft_delete/2} on_success={:deleted} :let={ctx}>
    <button disabled={ctx.selected_count == 0}>Delete Selected</button>
  </:bulk_action>
</Cinder.collection>
```

### Bulk Action Slot Attributes

- `action` - Ash action atom or function/2 (required)
- `label` - Button text (enables themed button, supports `{count}` interpolation)
- `variant` - Button style: `:primary` (default), `:secondary`, `:danger`
- `confirm` - Confirmation message (`{count}` interpolates selection count)
- `on_success` - Event name sent to parent on success
- `on_error` - Event name sent to parent on error
- `action_opts` - Additional Ash options (e.g., `[return_records?: true]`)

### Selection Attributes

- `selectable` - Enable checkboxes (works in table/grid/list)
- `on_selection_change` - Event name for selection state changes

### Handling Callbacks

```elixir
def handle_info({:deleted, %{count: count}}, socket) do
  {:noreply, put_flash(socket, :info, "Deleted #{count} users")}
end

def handle_info({:delete_failed, %{reason: reason}}, socket) do
  {:noreply, put_flash(socket, :error, "Failed: #{inspect(reason)}")}
end
```

## Testing

Use `render_async` for data-dependent assertions:

```elixir
{:ok, view, html} = live(conn, ~p"/users")
assert html =~ "Loading..."
assert render_async(view) =~ "John Doe"
```
