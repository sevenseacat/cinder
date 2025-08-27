# Cinder Usage Rules

Cinder is a powerful, intelligent data table component for Phoenix LiveView applications with seamless Ash Framework integration.

## Basic Table Usage

### Simple Resource Table
```heex
<Cinder.Table.table resource={MyApp.User} actor={@current_user}>
  <:col :let={user} field="name" filter sort>{user.name}</:col>
  <:col :let={user} field="email" filter>{user.email}</:col>
  <:col :let={user} field="created_at" sort>{user.created_at}</:col>
</Cinder.Table.table>
```

### Advanced Query Usage
```heex
<!-- Pre-configured query -->
<Cinder.Table.table query={MyApp.User |> Ash.Query.filter(active: true)} actor={@current_user}>
  <:col :let={user} field="name" filter sort>{user.name}</:col>
</Cinder.Table.table>

<!-- Custom read action -->
<Cinder.Table.table query={Ash.Query.for_read(MyApp.User, :active_users)} actor={@current_user}>
  <:col :let={user} field="name" filter sort>{user.name}</:col>
</Cinder.Table.table>
```

## Field Notation

### Relationship Fields (Dot Notation)
```heex
<:col field="department.name" filter sort>Department</:col>
<:col field="profile.address.city" filter>City</:col>
```

### Embedded Resource Fields (Double Underscore)
```heex
<:col field="settings__country" filter>Country</:col>
<:col field="profile__address__street" filter>Street</:col>
```

## Column Configuration

### Required Attributes
- `field` (for data columns) - omit for action columns
- Slot content for cell data display using `:let` binding

### Optional Attributes
- `filter` - enables filtering (auto-detects type from Ash resource)
- `sort` - enables sorting
- `filter={:specific_type}` - override filter type
- `filter={[type: :select, options: [...]]}` - unified filter configuration (recommended)
- `filter_options={[key: value]}` - configure filter behavior (deprecated, use unified syntax)
- `label="Custom Label"` - override auto-generated column header

### Action Columns (No Field)
```heex
<:col :let={user} label="Actions">
  <.link patch={~p"/users/#{user.id}/edit"}>Edit</.link>
</:col>
```

### Filter Configuration Examples

**Basic filtering (auto-detected type):**
```heex
<:col field="status" filter>Status</:col>
```

**Unified syntax with custom options:**
```heex
<:col field="status" filter={[type: :select, prompt: "All Statuses"]}>Status</:col>
<:col field="price" filter={[type: :number_range, min: 0, max: 1000]}>Price</:col>
<:col field="tags" filter={[type: :multi_select, prompt: "Select tags...", match_mode: :any]}>Tags</:col>
```

**Legacy syntax (deprecated but supported):**
```heex
<:col field="status" filter={:select} filter_options={[prompt: "All Statuses"]}>Status</:col>
```

## Table Configuration

### Required Parameters
- `resource={Resource}` OR `query={query}` - data source
- `actor={@current_user}` - for Ash authorization

### Key Optional Parameters
- `theme="modern"` - built-in theme (default, modern, retro, futuristic, dark, daisy_ui, flowbite, compact, pastel)
- `page_size={25}` - fixed page size, or `page_size={[default: 25, options: [10, 25, 50]]}` - configurable with dropdown
- `url_state={@url_state}` - enable URL synchronization
- `row_click={fn item -> JS.navigate(~p"/path/#{item.id}") end}` - row interactivity
- `query_opts={[timeout: 30_000]}` - Ash query options
- `scope={scope}` - Ash authorization scope

## URL State Management

Enable bookmarkable URLs:

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

## Built-in Filter Types

Cinder automatically detects filter types from Ash resource attributes:
- **Text**: `:string`, `:atom` fields → contains/starts_with/ends_with
- **Select**: enum attributes → dropdown selection
- **Boolean**: `:boolean` fields → yes/no/all options
- **Date Range**: `:date`, `:utc_datetime`, `:naive_datetime` → date pickers
- **Number Range**: `:integer`, `:float`, `:decimal` → min/max inputs
- **Multi-Select**: array fields → multiple selection with AND/OR logic

## Custom Filters

### 1. Configure in config.exs
```elixir
config :cinder, :filters, [
  slider: MyApp.Filters.Slider,
  color_picker: MyApp.Filters.ColorPicker
]
```

### 2. Setup in application.ex
```elixir
def start(_type, _args) do
  Cinder.setup()  # Registers all configured filters
  # ... rest of application startup
end
```

### 3. Create Filter Module
```elixir
defmodule MyApp.Filters.Slider do
  use Cinder.Filter

  @impl true
  def render(column, current_value, theme, assigns) do
    # HEEx template for filter UI
  end

  @impl true
  def process(raw_value, column) do
    # Transform form input to filter value
  end

  @impl true
  def validate(filter_value), do: true

  @impl true
  def default_options, do: [min: 0, max: 100]

  @impl true
  def empty?(value), do: is_nil(value)
end
```

### 4. Use in Tables
```heex
<:col :let={product} field="price" filter={[type: :slider, min: 0, max: 1000]}>
  ${product.price}
</:col>
```

## Table Refresh Functions

```elixir
# Import for convenience
import Cinder.Table.Refresh

def handle_event("delete", %{"id" => id}, socket) do
  # ... delete logic ...
  {:noreply, refresh_table(socket, "table-id")}
end

# Or use fully qualified
{:noreply, Cinder.Table.Refresh.refresh_table(socket, "table-id")}
{:noreply, Cinder.Table.Refresh.refresh_tables(socket, ["table1", "table2"])}
```

## Theming

### Global Theme Configuration
```elixir
# config/config.exs
config :cinder, default_theme: "modern"
```

### Per-Table Theme
```heex
<Cinder.Table.table theme="dark" resource={MyApp.User} actor={@current_user}>
```

## Testing

Use `render_async` to wait for data to load before checking for the data on page.

```elixir
{:ok, index_live, html} = live(conn, ~p"/users")
assert html =~ "Loading..."
assert render_async(index_live) =~ "User Name"
```
