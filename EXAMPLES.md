# Cinder Examples

This document provides comprehensive examples of using the Cinder table component with Ash Framework.

## Table of Contents

- [Basic Usage](#basic-usage)
- [Automatic Label Generation](#automatic-label-generation)
- [Custom Labels](#custom-labels)
- [Filtering](#filtering)
- [Sorting](#sorting)
- [Combined Features](#combined-features)
- [Relationship Fields](#relationship-fields)
- [Custom Content](#custom-content)
- [Theming](#theming)
- [URL State Management](#url-state-management)
- [Advanced Configuration](#advanced-configuration)

## Basic Usage

The simplest table requires only a resource and current user:

```elixir
<Cinder.Table.table resource={MyApp.User} current_user={@current_user}>
  <:col field="name">Name</:col>
  <:col field="email">Email</:col>
</Cinder.Table.table>
```

## Automatic Label Generation

Cinder automatically generates human-readable labels from field names:

```elixir
<Cinder.Table.table resource={MyApp.User} current_user={@current_user}>
  <:col field="first_name" />      <!-- Label: "First Name" -->
  <:col field="email_address" />   <!-- Label: "Email Address" -->
  <:col field="created_at" />      <!-- Label: "Created At" -->
</Cinder.Table.table>
```

## Custom Labels

Override auto-generated labels when needed:

```elixir
<Cinder.Table.table resource={MyApp.User} current_user={@current_user}>
  <:col field="name" label="Full Name">Name</:col>
  <:col field="email" label="Email Address">Email</:col>
  <:col field="created_at" label="Joined">Created</:col>
</Cinder.Table.table>
```

## Filtering

### Automatic Filter Detection

Cinder automatically selects the appropriate filter type based on your Ash resource:

```elixir
<Cinder.Table.table resource={MyApp.User} current_user={@current_user}>
  <:col field="name" filter>Name</:col>           <!-- Text filter -->
  <:col field="age" filter>Age</:col>             <!-- Number range filter -->
  <:col field="active" filter>Active</:col>       <!-- Boolean filter -->
  <:col field="role" filter>Role</:col>           <!-- Select filter (enum) -->
</Cinder.Table.table>
```

### Explicit Filter Types

Specify filter types when you need more control:

```elixir
<Cinder.Table.table resource={MyApp.Album} current_user={@current_user}>
  <:col field="title" filter={:text}>Title</:col>
  <:col field="release_date" filter={:date_range}>Released</:col>
  <:col field="genre" filter={:select}>Genre</:col>
  <:col field="tags" filter={:multi_select}>Tags</:col>
  <:col field="price" filter={:number_range}>Price</:col>
  <:col field="available" filter={:boolean}>Available</:col>
</Cinder.Table.table>
```

## Sorting

Enable sorting on any column:

```elixir
<Cinder.Table.table resource={MyApp.User} current_user={@current_user}>
  <:col field="name" sort>Name</:col>
  <:col field="email" sort>Email</:col>
  <:col field="created_at" sort>Joined</:col>
</Cinder.Table.table>
```

## Combined Features

Most columns will use both filtering and sorting:

```elixir
<Cinder.Table.table resource={MyApp.Product} current_user={@current_user}>
  <:col field="name" filter sort>Product Name</:col>
  <:col field="price" filter={:number_range} sort>Price</:col>
  <:col field="category" filter={:select} sort>Category</:col>
  <:col field="created_at" filter={:date_range} sort>Created</:col>
</Cinder.Table.table>
```

## Relationship Fields

Use dot notation to display and filter by related fields:

```elixir
<Cinder.Table.table resource={MyApp.Album} current_user={@current_user}>
  <:col field="title" filter sort>Album</:col>
  <:col field="artist.name" filter sort>Artist</:col>           <!-- Related field -->
  <:col field="artist.country" filter>Country</:col>           <!-- Nested relationship -->
  <:col field="label.name" filter>Record Label</:col>          <!-- Another relationship -->
</Cinder.Table.table>
```

## Custom Content

Add custom content in columns alongside field values:

```elixir
<Cinder.Table.table resource={MyApp.Order} current_user={@current_user}>
  <:col field="number" filter sort>Order #</:col>
  <:col field="customer.name" filter sort>Customer</:col>
  <:col field="total_amount" filter={:number_range} sort>Total</:col>
  <:col field="status" filter={:select} sort>Status</:col>
  <:col field="items">
    Items: <%= length(order.order_items) %>
  </:col>
  <:col field="actions" class="text-center">
    <.link navigate={~p"/orders/#{order.id}"}>View</.link>
    <.link navigate={~p"/orders/#{order.id}/edit"}>Edit</.link>
  </:col>
</Cinder.Table.table>
```

## Theming

### Built-in Themes

Choose from pre-configured themes:

```elixir
<!-- Default theme -->
<Cinder.Table.table resource={MyApp.User} current_user={@current_user} theme="default">
  <:col field="name" filter sort>Name</:col>
</Cinder.Table.table>

<!-- Modern theme -->
<Cinder.Table.table resource={MyApp.User} current_user={@current_user} theme="modern">
  <:col field="name" filter sort>Name</:col>
</Cinder.Table.table>

<!-- Minimal theme -->
<Cinder.Table.table resource={MyApp.User} current_user={@current_user} theme="minimal">
  <:col field="name" filter sort>Name</:col>
</Cinder.Table.table>
```

### Custom Theming

Create completely custom styling:

```elixir
<Cinder.Table.table 
  resource={MyApp.User} 
  current_user={@current_user}
  theme={%{
    container_class: "bg-white shadow-lg rounded-xl",
    table_class: "w-full border-collapse",
    th_class: "px-6 py-4 text-left font-bold text-gray-900 bg-gray-100",
    td_class: "px-6 py-4 border-b border-gray-200",
    filter_input_class: "w-full px-3 py-2 border border-gray-300 rounded-md"
  }}
>
  <:col field="name" filter sort>Name</:col>
</Cinder.Table.table>
```

## URL State Management

Enable automatic URL synchronization to preserve table state:

### LiveView Setup

First, add the URL sync helper to your LiveView:

```elixir
defmodule MyAppWeb.UsersLive do
  use MyAppWeb, :live_view
  use Cinder.Table.UrlSync  # Add automatic URL sync support

  def mount(_params, _session, socket) do
    {:ok, assign(socket, :current_user, get_current_user())}
  end

  def handle_params(params, uri, socket) do
    # Pass the URI parameter for proper path resolution
    socket = Cinder.Table.UrlSync.handle_params(socket, params, uri)
    {:noreply, socket}
  end

  def render(assigns) do
    ~H"""
    <Cinder.Table.table 
      resource={MyApp.User} 
      current_user={@current_user}
      url_state={@url_state}
      id="users-table"
    >
      <:col field="name" filter sort>Name</:col>
      <:col field="email" filter>Email</:col>
      <:col field="created_at" filter={:date_range} sort>Joined</:col>
    </Cinder.Table.table>
    """
  end
end
```

### Benefits of URL Sync

When enabled, URL sync provides:

- **Browser Navigation**: Back/forward buttons work correctly
- **Bookmarkable States**: Users can bookmark filtered/sorted views
- **Shareable Links**: Send links with current table state
- **Page Refresh**: State persists across page reloads

Example URL with state:
```
/users?name=john&created_at_from=2024-01-01&page=2&sort=-created_at
```

## Advanced Configuration

### Complete Configuration Example

Here's a comprehensive example showing all available options:

```elixir
<Cinder.Table.table
  resource={MyApp.User}
  current_user={@current_user}
  id="advanced-users-table"
  page_size={50}
  theme="modern"
  url_state={@url_state}
  query_opts={[load: [:profile, :department]]}
  show_filters={true}
  show_pagination={true}
  loading_message="Loading users..."
  empty_message="No users found matching your criteria"
  class="my-custom-table-wrapper"
>
  <:col field="name" filter sort label="Full Name" class="w-1/4">
    <%= user.name %>
  </:col>
  
  <:col field="email" filter sort class="w-1/4">
    <a href={"mailto:#{user.email}"} class="text-blue-600 hover:underline">
      <%= user.email %>
    </a>
  </:col>
  
  <:col field="department.name" filter sort>
    Department
  </:col>
  
  <:col field="role" filter={:select} sort>
    Role
  </:col>
  
  <:col field="created_at" filter={:date_range} sort>
    Joined
  </:col>
  
  <:col field="active" filter={:boolean}>
    Status
  </:col>
  
  <:col field="actions" class="text-right">
    <div class="flex gap-2 justify-end">
      <.link 
        navigate={~p"/users/#{user.id}"} 
        class="text-blue-600 hover:text-blue-800"
      >
        View
      </.link>
      <.link 
        navigate={~p"/users/#{user.id}/edit"} 
        class="text-green-600 hover:text-green-800"
      >
        Edit
      </.link>
    </div>
  </:col>
</Cinder.Table.table>
```

### Available Attributes

**Component Level:**
- `resource` (required) - Ash resource to query
- `current_user` (required) - Current user for authorization  
- `id` - Unique component identifier (default: "cinder-table")
- `page_size` - Items per page (default: 25)
- `theme` - Theme preset string or custom theme map (default: "default")
- `url_state` - URL state object from UrlSync.handle_params, or false to disable URL synchronization
- `query_opts` - Additional Ash query options (default: [])
- `on_state_change` - Custom state change callback
- `show_filters` - Show filter controls (default: auto-detect)
- `show_pagination` - Show pagination controls (default: true)
- `loading_message` - Custom loading text
- `empty_message` - Custom empty state text
- `class` - Additional CSS classes for container

**Column Level:**
- `field` (required) - Field name or relationship path
- `filter` - Enable filtering (boolean or filter type atom)
- `sort` - Enable sorting (boolean)
- `label` - Column header text (auto-generated if not provided)
- `class` - CSS classes for this column

### Filter Types

- `:text` - Text input for string fields
- `:select` - Dropdown for enum fields
- `:multi_select` - Multi-selection for array fields
- `:boolean` - True/false/any selection
- `:date_range` - Date range picker
- `:number_range` - Min/max number inputs

### Performance Tips

1. **Use query_opts for preloading**: Load related data efficiently
   ```elixir
   query_opts={[load: [:department, :profile], select: [:id, :name, :email]]}
   ```

2. **Optimize page size**: Balance UX and performance
   ```elixir
   page_size={25}  # Good default for most cases
   ```

3. **Selective filtering**: Only enable filters on columns users actually need
   ```elixir
   <:col field="internal_id">ID</:col>  <!-- No filter needed -->
   <:col field="name" filter sort>Name</:col>  <!-- User-facing field -->
   ```

This covers the core functionality of Cinder tables. The combination of intelligent defaults and extensive customization options makes it suitable for both simple and complex data display scenarios.