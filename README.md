# Cinder

A powerful, intelligent data table component for Phoenix LiveView applications with seamless Ash Framework integration. Cinder provides rich filtering, sorting, and pagination with minimal configuration through automatic type inference and smart defaults.

## Features

- **Intelligent Defaults**: Automatic filter type detection from Ash resource attributes
- **Minimal Configuration**: 70% fewer attributes required compared to traditional table components
- **Complete URL State Management**: Filters, pagination, and sorting synchronized with browser URL
- **Relationship Support**: Dot notation for related fields (e.g., `user.department.name`)
- **Flexible Theming**: Built-in presets (default, modern, minimal) plus full customization
- **Real-time Filtering**: Six filter types with debounced updates and form-based state management
- **Multi-column Sorting**: Interactive sorting with visual indicators
- **Responsive Design**: Mobile-friendly with loading states and optimistic updates
- **Ash Integration**: Native support for Ash Framework resources and authorization

## Installation

Add `cinder` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:cinder, "~> 0.1.0"}
  ]
end
```

## Quick Start

The simplest table requires only a resource and current user:

```elixir
<Cinder.Table.table resource={MyApp.User} current_user={@current_user}>
  <:col field="name" filter sort>Name</:col>
  <:col field="email" filter>Email</:col>
  <:col field="created_at" sort>Created</:col>
</Cinder.Table.table>
```

## Key Concepts

### Automatic Type Inference

Cinder automatically selects the appropriate filter type based on your Ash resource attributes:

- **String fields** → Text filter with search
- **Enum fields** → Select dropdown with options
- **Boolean fields** → True/false/any radio buttons
- **Date/DateTime fields** → Date range picker
- **Integer/Decimal fields** → Number range inputs
- **Array fields** → Multi-select checkboxes

```elixir
# These columns automatically get the right filter types:
<:col field="name" filter>Name</:col>           <!-- Text filter -->
<:col field="status" filter>Status</:col>       <!-- Select filter (if enum) -->
<:col field="active" filter>Active</:col>       <!-- Boolean filter -->
<:col field="created_at" filter>Created</:col>  <!-- Date range filter -->
<:col field="age" filter>Age</:col>             <!-- Number range filter -->
```

### Relationship Fields

Use dot notation to display and filter by related data:

```elixir
<Cinder.Table.table resource={MyApp.Album} current_user={@current_user}>
  <:col field="title" filter sort>Album</:col>
  <:col field="artist.name" filter sort>Artist</:col>
  <:col field="artist.country" filter>Country</:col>
  <:col field="label.name" filter>Record Label</:col>
</Cinder.Table.table>
```

### Smart Label Generation

Column labels are automatically generated from field names:

- `name` → "Name"
- `email_address` → "Email Address"
- `created_at` → "Created At"
- `user.name` → "User Name"

Override when needed:

```elixir
<:col field="created_at" label="Joined" sort>Created At</:col>
```

## URL State Management

Enable automatic URL synchronization for shareable, bookmarkable table states:

### LiveView Setup

```elixir
defmodule MyAppWeb.UsersLive do
  use MyAppWeb, :live_view
  use Cinder.Table.UrlSync  # Add URL sync support

  def mount(_params, _session, socket) do
    {:ok, assign(socket, :current_user, get_current_user())}
  end

  def handle_params(params, uri, socket) do
    socket = Cinder.Table.UrlSync.handle_params(socket, params, uri)
    {:noreply, socket}
  end

  def render(assigns) do
    ~H"""
    <Cinder.Table.table 
      resource={MyApp.User} 
      current_user={@current_user}
      url_state={@url_state}
    >
      <:col field="name" filter sort>Name</:col>
      <:col field="email" filter>Email</:col>
      <:col field="department.name" filter sort>Department</:col>
      <:col field="created_at" filter={:date_range} sort>Joined</:col>
    </Cinder.Table.table>
    """
  end
end
```

This enables:
- **Browser Navigation**: Back/forward buttons work correctly
- **Bookmarkable Views**: Users can bookmark filtered/sorted states
- **Shareable Links**: Send URLs with current table state
- **State Persistence**: Survives page refreshes

Example URL with state:
```
/users?name=john&department.name=engineering&created_at_from=2024-01-01&page=2&sort=-created_at
```

## Filtering

### Automatic Filter Types

Simply add `filter` to enable intelligent filtering:

```elixir
<:col field="name" filter>Name</:col>           <!-- Text search -->
<:col field="status" filter>Status</:col>       <!-- Dropdown (if enum) -->
<:col field="active" filter>Active</:col>       <!-- True/false/any -->
<:col field="salary" filter>Salary</:col>       <!-- Min/max range -->
<:col field="hire_date" filter>Hired</:col>     <!-- Date range -->
```

### Explicit Filter Types

Override automatic detection when needed:

```elixir
<:col field="tags" filter={:multi_select}>Tags</:col>
<:col field="description" filter={:text}>Description</:col>
<:col field="priority" filter={:select}>Priority</:col>
```

Available filter types:
- `:text` - Text input with search
- `:select` - Single-value dropdown
- `:multi_select` - Multiple checkboxes
- `:boolean` - True/false/any radio buttons
- `:date_range` - From/to date inputs
- `:number_range` - Min/max number inputs

## Sorting

Enable sorting on any column:

```elixir
<:col field="name" sort>Name</:col>
<:col field="created_at" sort>Created</:col>
<:col field="user.department.name" sort>Department</:col>
```

Features:
- **Click to sort**: Headers become clickable
- **Visual indicators**: Clear arrows show sort direction
- **Three-state cycle**: None → ascending → descending → none
- **Multi-column support**: Sort by multiple fields simultaneously
- **URL persistence**: Sort state preserved in URL

## Theming

### Built-in Themes

Choose from pre-configured themes:

```elixir
<Cinder.Table.table theme="modern" resource={MyApp.User} current_user={@current_user}>
  <:col field="name" filter sort>Name</:col>
</Cinder.Table.table>

<!-- Available themes: "default", "modern", "minimal" -->
```

### Custom Themes

Create completely custom styling:

```elixir
<Cinder.Table.table 
  resource={MyApp.User} 
  current_user={@current_user}
  theme={%{
    container_class: "bg-white shadow-lg rounded-xl overflow-hidden",
    table_class: "w-full border-collapse",
    th_class: "px-6 py-4 text-left font-semibold text-gray-900 bg-gray-50 border-b",
    td_class: "px-6 py-4 border-b border-gray-200",
    filter_container_class: "bg-blue-50 border border-blue-200 rounded-lg p-4 mb-4",
    pagination_wrapper_class: "flex items-center justify-between mt-4"
  }}
>
  <:col field="name" filter sort>Name</:col>
</Cinder.Table.table>
```

## Advanced Usage

### Custom Content

Add custom content alongside field values:

```elixir
<Cinder.Table.table resource={MyApp.Order} current_user={@current_user}>
  <:col field="number" filter sort>Order #</:col>
  <:col field="customer.name" filter sort>Customer</:col>
  <:col field="total" filter={:number_range} sort>
    $<%= :erlang.float_to_binary(order.total, decimals: 2) %>
  </:col>
  <:col field="actions" class="text-center">
    <.link navigate={~p"/orders/#{order.id}"} class="text-blue-600 hover:underline">
      View
    </.link>
  </:col>
</Cinder.Table.table>
```

### Configuration Options

```elixir
<Cinder.Table.table
  resource={MyApp.User}
  current_user={@current_user}
  id="users-table"               # Component ID (default: "cinder-table")
  page_size={50}                 # Items per page (default: 25)
  theme="modern"                 # Theme preset or custom map
  url_sync                       # Enable URL state management
  query_opts={[load: [:profile]]} # Additional Ash query options
  show_filters={true}            # Show filter controls (default: auto-detect)
  show_pagination={true}         # Show pagination (default: true)
  loading_message="Loading..."   # Custom loading text
  empty_message="No data found"  # Custom empty state text
  class="my-custom-wrapper"      # Additional CSS classes
>
  <:col field="name" filter sort label="Full Name" class="w-1/3">
    Name
  </:col>
</Cinder.Table.table>
```

### Column Attributes

- `field` (required) - Field name or relationship path
- `filter` - Enable filtering (boolean or filter type atom)
- `sort` - Enable sorting (boolean)
- `label` - Column header text (auto-generated if not provided)
- `class` - CSS classes for this column

## Performance Tips

1. **Use query_opts for efficient loading**:
   ```elixir
   query_opts={[load: [:department, :manager], select: [:id, :name, :email]]}
   ```

2. **Optimize page size for your data**:
   ```elixir
   page_size={25}  # Good balance of UX and performance
   ```

3. **Enable filtering strategically**:
   ```elixir
   <:col field="id">ID</:col>                    <!-- No filter needed -->
   <:col field="name" filter sort>Name</:col>    <!-- User-searchable -->
   ```



## Requirements

- Phoenix LiveView 1.0+
- Ash Framework 3.0+
- Elixir 1.17+

## Architecture

Cinder features a modular architecture with focused, testable components:

- **Theme System** - Centralized styling with smart defaults
- **URL Manager** - State serialization and browser integration  
- **Query Builder** - Ash query construction and optimization
- **Column System** - Intelligent type inference and configuration
- **Filter Registry** - Pluggable filter types with consistent interface
- **Table Component** - Lightweight coordinator that orchestrates all systems

This design enables easy extension and customization while maintaining simplicity for common use cases.

## Examples

See [EXAMPLES.md](EXAMPLES.md) for comprehensive usage examples covering all features.

## Contributing

Contributions are welcome! Please read our contributing guidelines and submit pull requests to our GitHub repository.

## License

This project is licensed under the MIT License - see the LICENSE file for details.