# Examples

This document provides comprehensive examples and detailed reference for all Cinder table features. For a quick start, see the [README](../README.md).

## Overview

Cinder supports two parameter styles:
- **`resource`** - Simple usage with Ash resource modules
- **`query`** - Advanced usage with pre-configured Ash queries

Choose `resource` for most cases, `query` for complex requirements like custom read actions, base filters, or admin interfaces.

## Table of Contents

- [Basic Usage](#basic-usage)
- [Resource vs Query](#resource-vs-query)
- [Column Configuration](#column-configuration)
- [Filter Types](#filter-types)
- [Sorting](#sorting)
- [Theming](#theming)
- [URL State Management](#url-state-management)
- [Relationship Fields](#relationship-fields)
- [Custom Content](#custom-content)
- [Advanced Configuration](#advanced-configuration)
- [Performance Optimization](#performance-optimization)

## Basic Usage

### Minimal Table

The simplest possible table:

```elixir
<Cinder.Table.table resource={MyApp.User} actor={@current_user}>
  <:col :let={user} field="name">{user.name}</:col>
  <:col :let={user} field="email">{user.email}</:col>
</Cinder.Table.table>
```

## Resource vs Query

Cinder supports two ways to specify what data to query: `resource` parameter (simple) or `query` parameter (advanced).

### When to Use Resource

Use the `resource` parameter for straightforward tables:

```elixir
<!-- Simple table with default read action -->
<Cinder.Table.table resource={MyApp.User} actor={@current_user}>
  <:col :let={user} field="name" filter sort>{user.name}</:col>
  <:col :let={user} field="email" filter>{user.email}</:col>
</Cinder.Table.table>
```

**Best for:**
- Getting started quickly
- Standard use cases without custom requirements
- Default read actions
- Simple authorization scenarios

### When to Use Query

Use the `query` parameter for advanced scenarios:

```elixir
<!-- Custom read action -->
<Cinder.Table.table query={Ash.Query.for_read(MyApp.User, :active_users)} actor={@current_user}>
  <:col :let={user} field="name" filter sort>{user.name}</:col>
  <:col :let={user} field="email" filter>{user.email}</:col>
</Cinder.Table.table>

<!-- Pre-filtered data -->
<Cinder.Table.table query={MyApp.User |> Ash.Query.filter(department: "Engineering")} actor={@current_user}>
  <:col :let={user} field="name" filter sort>{user.name}</:col>
  <:col :let={user} field="department.name" filter>{user.department.name}</:col>
</Cinder.Table.table>

<!-- Admin interface with complex authorization -->
<Cinder.Table.table
  query={MyApp.User
    |> Ash.Query.for_read(:admin_read, %{}, actor: @actor, authorize?: @authorizing)
    |> Ash.Query.set_tenant(@tenant)
    |> Ash.Query.filter(active: true)}
  actor={@current_user}>
  <:col :let={user} field="name" filter sort>{user.name}</:col>
  <:col :let={user} field="email" filter>{user.email}</:col>
  <:col :let={user} field="last_login" sort>{user.last_login}</:col>
</Cinder.Table.table>
```

**Best for:**
- Custom read actions (e.g., `:active_users`, `:admin_only`)
- Pre-filtering data with base filters
- Custom authorization settings
- Tenant-specific queries
- Admin interfaces with complex requirements
- Integration with existing Ash query pipelines

### Automatic Label Generation

Cinder automatically generates human-readable labels from field names:

```elixir
<Cinder.Table.table resource={MyApp.User} actor={@current_user}>
  <:col :let={user} field="first_name">{user.first_name}</:col>      <!-- "First Name" -->
  <:col :let={user} field="email_address">{user.email_address}</:col>   <!-- "Email Address" -->
  <:col :let={user} field="created_at">{user.created_at}</:col>      <!-- "Created At" -->
  <:col :let={user} field="is_active">{user.is_active}</:col>       <!-- "Is Active" -->
  <:col :let={user} field="phone_number">{user.phone_number}</:col>    <!-- "Phone Number" -->
</Cinder.Table.table>
```

### Custom Labels

Override auto-generated labels when needed:

```elixir
<Cinder.Table.table resource={MyApp.User} actor={@current_user}>
  <:col :let={user} field="name" label="Full Name">{user.name}</:col>
  <:col :let={user} field="email" label="Email Address">{user.email}</:col>
  <:col :let={user} field="created_at" label="Joined">{user.created_at}</:col>
  <:col :let={user} field="is_active" label="Status">{user.is_active}</:col>
</Cinder.Table.table>
```

## Column Configuration

### All Column Attributes

Demonstration of every available column attribute:

```elixir
<Cinder.Table.table resource={MyApp.Product} actor={@current_user}>
  <!-- Basic column with all common attributes -->
  <:col
    :let={product}
    field="name"
    label="Product Name"
    filter={:text}
    sort={true}
    class="w-1/4 font-semibold"
  >
    {product.name}
  </:col>

  <!-- Column with custom filter options -->
  <:col
    :let={product}
    field="category"
    filter={:select}
    filter_options={[
      options: [{"Electronics", "electronics"}, {"Books", "books"}, {"Clothing", "clothing"}],
      prompt: "All Categories"
    ]}
    sort
  >
    {product.category}
  </:col>

  <!-- Number column with range filter -->
  <:col
    :let={product}
    field="price"
    filter={:number_range}
    filter_options={[
      min: 0,
      max: 1000,
      step: 0.01
    ]}
    sort
    class="text-right"
  >
    ${product.price}
  </:col>

  <!-- Boolean column with custom labels -->
  <:col
    :let={product}
    field="in_stock"
    filter={:boolean}
    filter_options={[
      labels: %{
        all: "Any Stock Status",
        true: "In Stock",
        false: "Out of Stock"
      }
    ]}
  >
    {if product.in_stock, do: "In Stock", else: "Out of Stock"}
  </:col>
</Cinder.Table.table>
```

## Filter Types

Cinder automatically detects the right filter type based on your Ash resource attributes:

- **String fields** → Text search
- **Enum fields** → Select dropdown
- **Boolean fields** → True/false/any radio buttons
- **Date/DateTime fields** → Date range picker
- **Integer/Decimal fields** → Number range inputs
- **Array fields** → Multi-select tag interface

You can also explicitly specify filter types: `:text`, `:select`, `:multi_select`, `:multi_checkboxes`, `:boolean`, `:date_range`, `:number_range`

### Multi-Select Options

For multiple selection filtering, choose between:

- **`:multi_select`** - Modern tag-based interface with dropdown (default for arrays)
- **`:multi_checkboxes`** - Traditional checkbox interface

### Text Filter

```elixir
<Cinder.Table.table resource={MyApp.Article} actor={@current_user}>
  <!-- Basic text filter -->
  <:col :let={article} field="title" filter>{article.title}</:col>

  <!-- Text filter with custom placeholder -->
  <:col
    :let={article}
    field="content"
    filter={:text}
    filter_options={[placeholder: "Search article content..."]}
  >
    {String.slice(article.content, 0, 100)}...
  </:col>

  <!-- Case-sensitive text filter -->
  <:col
    :let={article}
    field="author_name"
    filter={:text}
    filter_options={[
      placeholder: "Author name...",
      case_sensitive: true
    ]}
  >
    {article.author_name}
  </:col>
</Cinder.Table.table>
```

### Select Filter

```elixir
<Cinder.Table.table resource={MyApp.Order} actor={@current_user}>
  <!-- Basic select filter (auto-detects enum options) -->
  <:col :let={order} field="status" filter>{String.capitalize(order.status)}</:col>

  <!-- Select filter with custom options -->
  <:col
    :let={order}
    field="priority"
    filter={:select}
    filter_options={[
      options: [
        {"Low Priority", "low"},
        {"Normal Priority", "normal"},
        {"High Priority", "high"},
        {"Urgent", "urgent"}
      ],
      prompt: "Any Priority"
    ]}
  >
    <span class={[
      "px-2 py-1 text-xs font-semibold rounded-full",
      order.priority == "urgent" && "bg-red-100 text-red-800",
      order.priority == "high" && "bg-orange-100 text-orange-800",
      order.priority == "normal" && "bg-blue-100 text-blue-800",
      order.priority == "low" && "bg-gray-100 text-gray-800"
    ]}>
      {String.capitalize(order.priority)}
    </span>
  </:col>

  <!-- Select with boolean options -->
  <:col
    :let={order}
    field="is_paid"
    filter={:select}
    filter_options={[
      options: [{"Paid", true}, {"Unpaid", false}],
      prompt: "Payment Status"
    ]}
  >
    {if order.is_paid, do: "Paid", else: "Unpaid"}
  </:col>
</Cinder.Table.table>
```

### Multi-Select Filter

```elixir
<Cinder.Table.table resource={MyApp.Book} actor={@current_user}>
  <!-- Multi-select for tags -->
  <:col
    field="tags"
    filter={:multi_select}
    filter_options={[
      options: [
        {"Fiction", "fiction"},
        {"Non-Fiction", "non_fiction"},
        {"Science Fiction", "sci_fi"},
        {"Romance", "romance"},
        {"Mystery", "mystery"},
        {"Biography", "biography"}
      ]
    ]}
  >
    {Enum.join(book.tags, ", ")}
  </:col>

  <!-- Multi-select for categories -->
  <:col
    :let={book}
    field="categories"
    filter={:multi_select}
    filter_options={[
      options: [
        {"Bestseller", "bestseller"},
        {"New Release", "new_release"},
        {"Award Winner", "award_winner"},
        {"Staff Pick", "staff_pick"}
      ]
    ]}
  >
    <div class="flex flex-wrap gap-1">
      {for category <- book.categories do}
        <span class="px-2 py-1 text-xs bg-blue-100 text-blue-800 rounded-full">
          {String.capitalize(String.replace(category, "_", " "))}
        </span>
      {/for}
    </div>
  </:col>
</Cinder.Table.table>
```

### Boolean Filter

```elixir
<Cinder.Table.table resource={MyApp.User} actor={@current_user}>
  <!-- Basic boolean filter -->
  <:col :let={user} field="is_active" filter>
    {if user.is_active, do: "Active", else: "Inactive"}
  </:col>

  <!-- Boolean filter with custom labels -->
  <:col
    :let={user}
    field="email_verified"
    filter={:boolean}
    filter_options={[
      labels: %{
        all: "Any Verification Status",
        true: "Email Verified",
        false: "Email Not Verified"
      }
    ]}
  >
    <span class={[
      "px-2 py-1 text-xs font-semibold rounded-full",
      user.email_verified && "bg-green-100 text-green-800",
      !user.email_verified && "bg-red-100 text-red-800"
    ]}>
      {if user.email_verified, do: "Verified", else: "Not Verified"}
    </span>
  </:col>

  <!-- Boolean filter for subscription -->
  <:col
    :let={user}
    field="has_subscription"
    filter={:boolean}
    filter_options={[
      labels: %{
        all: "All Users",
        true: "Subscribers",
        false: "Free Users"
      }
    ]}
  >
    {if user.has_subscription, do: "Subscriber", else: "Free User"}
  </:col>
</Cinder.Table.table>
```

### Date Range Filter

```elixir
<Cinder.Table.table resource={MyApp.Event} actor={@current_user}>
  <!-- Basic date range filter -->
  <:col :let={event} field="created_at" filter={:date_range}>
    {Calendar.strftime(event.created_at, "%B %d, %Y")}
  </:col>

  <!-- Date range with custom format -->
  <:col
    :let={event}
    field="event_date"
    filter={:date_range}
    filter_options={[
      format: "YYYY-MM-DD",
      placeholder_from: "Start date",
      placeholder_to: "End date"
    ]}
  >
    {Calendar.strftime(event.event_date, "%Y-%m-%d")}
  </:col>

  <!-- DateTime range filter -->
  <:col
    :let={event}
    field="updated_at"
    filter={:date_range}
    filter_options={[
      include_time: true
    ]}
  >
    {Calendar.strftime(event.updated_at, "%B %d, %Y at %I:%M %p")}
  </:col>
</Cinder.Table.table>
```

### Number Range Filter

```elixir
<Cinder.Table.table resource={MyApp.Property} actor={@current_user}>
  <!-- Basic number range -->
  <:col :let={property} field="price" filter={:number_range}>
    ${Number.Currency.number_to_currency(property.price)}
  </:col>

  <!-- Number range with min/max limits -->
  <:col
    :let={property}
    field="square_feet"
    filter={:number_range}
    filter_options={[
      min: 500,
      max: 10000,
      step: 100,
      placeholder_min: "Min sq ft",
      placeholder_max: "Max sq ft"
    ]}
  >
    {Number.Delimit.number_to_delimited(property.square_feet)} sq ft
  </:col>

  <!-- Decimal number range -->
  <:col
    :let={property}
    field="rating"
    filter={:number_range}
    filter_options={[
      min: 0.0,
      max: 5.0,
      step: 0.1
    ]}
  >
    <div class="flex items-center">
      {for i <- 1..5 do}
        <svg class={[
          "w-4 h-4",
          i <= property.rating && "text-yellow-400",
          i > property.rating && "text-gray-300"
        ]} fill="currentColor" viewBox="0 0 20 20">
          <path d="M9.049 2.927c.3-.921 1.603-.921 1.902 0l1.07 3.292a1 1 0 00.95.69h3.462c.969 0 1.371 1.24.588 1.81l-2.8 2.034a1 1 0 00-.364 1.118l1.07 3.292c.3.921-.755 1.688-1.54 1.118l-2.8-2.034a1 1 0 00-1.175 0l-2.8 2.034c-.784.57-1.838-.197-1.539-1.118l1.07-3.292a1 1 0 00-.364-1.118L2.98 8.72c-.783-.57-.38-1.81.588-1.81h3.461a1 1 0 00.951-.69l1.07-3.292z"></path>
        </svg>
      {/for}
      <span class="ml-1 text-sm text-gray-600">{property.rating}</span>
    </div>
  </:col>
</Cinder.Table.table>
```

## Sorting

### Basic Sorting

```elixir
<Cinder.Table.table resource={MyApp.User} actor={@current_user}>
  <!-- Sortable columns -->
  <:col :let={user} field="name" sort>{user.name}</:col>
  <:col :let={user} field="email" sort>{user.email}</:col>
  <:col :let={user} field="created_at" sort>{user.created_at}</:col>

  <!-- Non-sortable column -->
  <:col :let={user} field="bio">{user.bio}</:col>
</Cinder.Table.table>
```

### Combined Filter and Sort

```elixir
<Cinder.Table.table resource={MyApp.Product} actor={@current_user}>
  <:col :let={product} field="name" filter sort>{product.name}</:col>
  <:col :let={product} field="price" filter={:number_range} sort>${product.price}</:col>
  <:col :let={product} field="category" filter={:select} sort>{product.category}</:col>
  <:col :let={product} field="created_at" filter={:date_range} sort>{product.created_at}</:col>
</Cinder.Table.table>
```

## Theming

### Built-in Themes

```elixir
<!-- Default theme -->
<Cinder.Table.table
  resource={MyApp.User}
  actor={@current_user}
  theme="default"
>
  <:col :let={user} field="name" filter sort>{user.name}</:col>
</Cinder.Table.table>

<!-- Modern theme -->
<Cinder.Table.table
  resource={MyApp.User}
  actor={@current_user}
  theme="modern"
>
  <:col :let={user} field="name" filter sort>{user.name}</:col>
</Cinder.Table.table>

<!-- Minimal theme -->
<Cinder.Table.table
  resource={MyApp.User}
  actor={@current_user}
  theme="minimal"
>
  <:col :let={user} field="name" filter sort>{user.name}</:col>
</Cinder.Table.table>
```

### Custom Theme - Complete Example

```elixir
<Cinder.Table.table
  resource={MyApp.User}
  actor={@current_user}
  theme={%{
    # Container styling
    container_class: "bg-white shadow-xl rounded-2xl overflow-hidden border border-gray-200",

    # Table structure
    table_class: "w-full border-collapse",
    thead_class: "bg-gradient-to-r from-blue-600 to-blue-700",
    tbody_class: "divide-y divide-gray-100",

    # Header styling
    th_class: "px-6 py-4 text-left text-sm font-bold text-white uppercase tracking-wider",
    th_sortable_class: "px-6 py-4 text-left text-sm font-bold text-white uppercase tracking-wider cursor-pointer hover:bg-blue-800 transition-colors",

    # Cell styling
    td_class: "px-6 py-4 whitespace-nowrap text-sm text-gray-900",
    tr_class: "hover:bg-gray-50 transition-colors",

    # Filter styling
    filter_container_class: "bg-blue-50 border-b border-blue-200 p-6",
    filter_row_class: "grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4",
    filter_col_class: "flex flex-col space-y-2",
    filter_label_class: "text-sm font-semibold text-blue-900",
    filter_text_input_class: "w-full px-3 py-2 border border-blue-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500",
    filter_select_input_class: "w-full px-3 py-2 border border-blue-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500",
    filter_clear_button_class: "text-sm text-blue-600 hover:text-blue-800 font-medium",

    # Pagination styling
    pagination_wrapper_class: "flex items-center justify-between px-6 py-4 bg-gray-50 border-t border-gray-200",
    pagination_info_class: "text-sm text-gray-700",
    pagination_nav_class: "flex space-x-2",
    pagination_button_class: "px-3 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-md hover:bg-gray-50",
    pagination_button_active_class: "px-3 py-2 text-sm font-medium text-white bg-blue-600 border border-blue-600 rounded-md",
    pagination_button_disabled_class: "px-3 py-2 text-sm font-medium text-gray-400 bg-gray-100 border border-gray-300 rounded-md cursor-not-allowed",

    # Loading and empty states
    loading_class: "text-center py-12 text-gray-500",
    empty_class: "text-center py-12 text-gray-500",

    # Sort indicators
    sort_asc_class: "inline-block w-4 h-4 ml-1 text-white",
    sort_desc_class: "inline-block w-4 h-4 ml-1 text-white"
  }}
>
  <:col :let={user} field="name" filter sort>{user.name}</:col>
  <:col :let={user} field="email" filter sort>{user.email}</:col>
</Cinder.Table.table>
```

## URL State Management

### Complete LiveView Setup

```elixir
defmodule MyAppWeb.UsersLive do
  use MyAppWeb, :live_view
  use Cinder.Table.UrlSync

  def mount(_params, _session, socket) do
    current_user = get_current_user(socket)
    {:ok, assign(socket, :current_user, current_user)}
  end

  def handle_params(params, uri, socket) do
    socket = Cinder.Table.UrlSync.handle_params(socket, params, uri)
    {:noreply, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="container mx-auto px-4 py-8">
      <h1 class="text-3xl font-bold mb-8">Users</h1>

      <Cinder.Table.table
        resource={MyApp.User}
        actor={@current_user}
        url_state={@url_state}
        id="users-table"
        page_size={25}
      >
        <:col :let={user} field="name" filter sort>{user.name}</:col>
        <:col :let={user} field="email" filter>{user.email}</:col>
        <:col :let={user} field="department.name" filter sort>{user.department.name}</:col>
        <:col :let={user} field="is_active" filter={:boolean}>
          {if user.is_active, do: "Active", else: "Inactive"}
        </:col>
      </Cinder.Table.table>
    </div>
    """
  end
end
```

### URL State Management with Query Parameter

You can also use pre-configured queries with URL sync:

```elixir
defmodule MyAppWeb.ActiveUsersLive do
  use MyAppWeb, :live_view
  use Cinder.Table.UrlSync

  def mount(_params, _session, socket) do
    current_user = get_current_user(socket)
    {:ok, assign(socket, :current_user, current_user)}
  end

  def handle_params(params, uri, socket) do
    socket = Cinder.Table.UrlSync.handle_params(socket, params, uri)
    {:noreply, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="container mx-auto px-4 py-8">
      <h1 class="text-3xl font-bold mb-8">Active Users</h1>

      <Cinder.Table.table
        query={MyApp.User |> Ash.Query.filter(active: true)}
        actor={@current_user}
        url_state={@url_state}
        id="active-users-table"
      >
        <:col :let={user} field="name" filter sort>{user.name}</:col>
        <:col :let={user} field="email" filter>{user.email}</:col>
        <:col :let={user} field="last_login" sort>{user.last_login}</:col>
      </Cinder.Table.table>
    </div>
    """
  end
end
```

### URL Examples

With URL sync enabled, your table state is preserved in the URL:

```
# Basic filtering
/users?name=john&department.name=engineering

# With date range
/users?name=smith&created_at_from=2024-01-01&created_at_to=2024-12-31

# With pagination and sorting
/users?email=gmail&page=3&sort=-created_at

# Complex state
/users?name=admin&department.name=IT&is_active=true&page=2&sort=name,-created_at
```

## Relationship Fields

### Basic Relationships

```elixir
<Cinder.Table.table resource={MyApp.Album} actor={@current_user}>
  <:col :let={album} field="title" filter sort>{album.title}</:col>
  <:col :let={album} field="artist.name" filter sort>{album.artist.name}</:col>
  <:col :let={album} field="artist.country" filter>{album.artist.country}</:col>
  <:col :let={album} field="record_label.name" filter>{album.record_label.name}</:col>
</Cinder.Table.table>
```

### Deep Relationships

```elixir
<Cinder.Table.table resource={MyApp.Employee} actor={@current_user}>
  <:col :let={employee} field="name" filter sort>{employee.name}</:col>
  <:col :let={employee} field="department.name" filter sort>{employee.department.name}</:col>
  <:col :let={employee} field="department.manager.name" filter>{employee.department.manager.name}</:col>
  <:col :let={employee} field="office.building.address" filter>{employee.office.building.address}</:col>
</Cinder.Table.table>
```

### Relationship Filters with Custom Options

```elixir
<Cinder.Table.table resource={MyApp.Order} actor={@current_user}>
  <:col :let={order} field="number" filter sort>#{order.number}</:col>
  <:col :let={order} field="customer.name" filter sort>{order.customer.name}</:col>

  <!-- Select filter on relationship enum -->
  <:col
    :let={order}
    field="customer.tier"
    filter={:select}
    filter_options={[
      options: [{"Bronze", "bronze"}, {"Silver", "silver"}, {"Gold", "gold"}],
      prompt: "Any Tier"
    ]}
  >
    <span class={[
      "px-2 py-1 text-xs font-semibold rounded-full",
      order.customer.tier == "gold" && "bg-yellow-100 text-yellow-800",
      order.customer.tier == "silver" && "bg-gray-100 text-gray-800",
      order.customer.tier == "bronze" && "bg-orange-100 text-orange-800"
    ]}>
      {String.capitalize(order.customer.tier)}
    </span>
  </:col>

  <!-- Date range on relationship -->
  <:col
    :let={order}
    field="customer.created_at"
    filter={:date_range}
    sort
  >
    {Calendar.strftime(order.customer.created_at, "%B %Y")}
  </:col>
</Cinder.Table.table>
```

### Advanced Examples

#### Progress Bars and Indicators

```elixir
<Cinder.Table.table resource={MyApp.Project} actor={@current_user}>
  <:col :let={project} field="name" filter sort>
    {project.name}
  </:col>

  <!-- Progress bar -->
  <:col :let={project} field="completion_percentage" filter={:number_range} sort>
    <div class="flex items-center space-x-2">
      <div class="flex-1 bg-gray-200 rounded-full h-2">
        <div
          class="bg-blue-600 h-2 rounded-full transition-all duration-300"
          style={"width: #{project.completion_percentage}%"}
        >
        </div>
      </div>
      <span class="text-sm text-gray-600 min-w-0">
        {project.completion_percentage}%
      </span>
    </div>
  </:col>

  <!-- Health indicator -->
  <:col :let={project} field="health_status" filter={:select}>
    <div class="flex items-center space-x-2">
      <div class={[
        "w-3 h-3 rounded-full",
        project.health_status == "healthy" && "bg-green-400",
        project.health_status == "warning" && "bg-yellow-400",
        project.health_status == "critical" && "bg-red-400"
      ]}>
      </div>
      <span class="text-sm capitalize">
        {project.health_status}
      </span>
    </div>
  </:col>
</Cinder.Table.table>
```

#### Image Thumbnails and Rich Content

```elixir
<Cinder.Table.table resource={MyApp.Product} actor={@current_user}>
  <!-- Product with thumbnail -->
  <:col :let={product} field="name" filter sort class="w-1/3">
    <div class="flex items-center space-x-3">
      {if product.image_url do}
        <img
          src={product.image_url}
          alt={product.name}
          class="w-12 h-12 rounded-lg object-cover flex-shrink-0"
        />
      {else}
        <div class="w-12 h-12 bg-gray-200 rounded-lg flex items-center justify-center flex-shrink-0">
          <svg class="w-6 h-6 text-gray-400" fill="currentColor" viewBox="0 0 20 20">
            <path fill-rule="evenodd" d="M4 3a2 2 0 00-2 2v10a2 2 0 002 2h12a2 2 0 002-2V5a2 2 0 00-2-2H4zm12 12H4l4-8 3 6 2-4 3 6z" clip-rule="evenodd"></path>
          </svg>
        </div>
      {/if}
      <div class="min-w-0 flex-1">
        <div class="text-sm font-medium text-gray-900 truncate">
          {product.name}
        </div>
        <div class="text-sm text-gray-500 truncate">
          SKU: {product.sku}
        </div>
      </div>
    </div>
  </:col>

  <!-- Price with currency formatting -->
  <:col :let={product} field="price" filter={:number_range} sort class="text-right">
    <div class="text-right">
      <div class="text-lg font-semibold text-gray-900">
        {Money.to_string(product.price)}
      </div>
      {if product.sale_price do}
        <div class="text-sm text-red-600 line-through">
          {Money.to_string(product.sale_price)}
        </div>
      {/if}
    </div>
  </:col>

  <!-- Stock status with inventory count -->
  <:col :let={product} field="inventory_count" filter={:number_range} sort>
    <div class="text-center">
      <div class={[
        "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium",
        product.inventory_count > 50 && "bg-green-100 text-green-800",
        product.inventory_count > 10 && product.inventory_count <= 50 && "bg-yellow-100 text-yellow-800",
        product.inventory_count <= 10 && "bg-red-100 text-red-800"
      ]}>
        {product.inventory_count} in stock
      </div>
    </div>
  </:col>
</Cinder.Table.table>
```

## Advanced Configuration

### Complete Configuration Example

Every available option demonstrated:

```elixir
<Cinder.Table.table
  # Required attributes
  resource={MyApp.User}
  actor={@current_user}

  # Component configuration
  id="advanced-users-table"
  class="my-custom-table-wrapper border rounded-lg"

  # Data configuration
  page_size={50}
  query_opts={[
    load: [:profile, :department, :manager],
    select: [:id, :name, :email, :created_at, :is_active]
  ]}

  # URL state management
  url_state={@url_state}

  # UI configuration
  theme="modern"
  show_filters={true}
  show_pagination={true}

  # Custom messages
  loading_message="Loading users, please wait..."
  empty_message="No users found matching your search criteria"

  # Callbacks (if needed for custom behavior)
  on_state_change={&handle_table_state_change/1}
>
  <!-- Text column with all options using :let -->
  <:col
    :let={user}
    field="name"
    label="Full Name"
    filter={:text}
    filter_options={[
      placeholder: "Search by name...",
      case_sensitive: false
    ]}
    sort={true}
    class="w-1/4 font-semibold"
  >
    <div class="flex items-center space-x-2">
      <div class="w-8 h-8 bg-blue-500 rounded-full flex items-center justify-center">
        <span class="text-white text-xs font-semibold">
          {String.first(user.name)}
        </span>
      </div>
      <span>{user.name}</span>
    </div>
  </:col>

  <!-- Email with mailto link using :let -->
  <:col
    :let={user}
    field="email"
    filter={:text}
    filter_options={[placeholder: "Email address..."]}
    sort
    class="w-1/4"
  >
    <a href={"mailto:#{user.email}"} class="text-blue-600 hover:underline">
      {user.email}
    </a>
  </:col>

  <!-- Relationship with select filter -->
  <:col
    :let={user}
    field="department.name"
    filter={:select}
    filter_options={[
      options: [
        {"Engineering", "engineering"},
        {"Marketing", "marketing"},
        {"Sales", "sales"},
        {"Support", "support"}
      ],
      prompt: "All Departments"
    ]}
    sort
  >
    {user.department.name}
  </:col>

  <!-- Date with range filter using :let -->
  <:col
    :let={user}
    field="created_at"
    label="Member Since"
    filter={:date_range}
    filter_options={[
      format: "MM/DD/YYYY",
      placeholder_from: "Start date",
      placeholder_to: "End date"
    ]}
    sort
  >
    <div class="text-sm">
      <div class="font-medium">
        {Calendar.strftime(user.created_at, "%B %d, %Y")}
      </div>
      <div class="text-gray-500">
        {Calendar.strftime(user.created_at, "%H:%M")}
      </div>
    </div>
  </:col>

  <!-- Boolean with custom labels using :let -->
  <:col
    :let={user}
    field="is_active"
    filter={:boolean}
    filter_options={[
      labels: %{
        all: "All Users",
        true: "Active Users",
        false: "Inactive Users"
      }
    ]}
  >
    <span class={[
      "px-2 py-1 text-xs font-semibold rounded-full",
      user.is_active && "bg-green-100 text-green-800",
      !user.is_active && "bg-red-100 text-red-800"
    ]}>
      {if user.is_active, do: "Active", else: "Inactive"}
    </span>
  </:col>

  <!-- Actions column using :let -->
  <:col :let={user} field="actions" class="text-right w-32">
    <div class="flex gap-1 justify-end">
      <.link
        navigate={~p"/users/#{user.id}"}
        class="p-1 text-blue-600 hover:text-blue-800"
        title="View user"
      >
        <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
          <path d="M10 12a2 2 0 100-4 2 2 0 000 4z"></path>
          <path fill-rule="evenodd" d="M.458 10C1.732 5.943 5.522 3 10 3s8.268 2.943 9.542 7c-1.274 4.057-5.064 7-9.542 7S1.732 14.057.458 10zM14 10a4 4 0 11-8 0 4 4 0 018 0z" clip-rule="evenodd"></path>
        </svg>
      </.link>
      <.link
        navigate={~p"/users/#{user.id}/edit"}
        class="p-1 text-green-600 hover:text-green-800"
        title="Edit user"
      >
        <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
          <path d="M13.586 3.586a2 2 0 112.828 2.828l-.793.793-2.828-2.828.793-.793zM11.379 5.793L3 14.172V17h2.828l8.38-8.379-2.83-2.828z"></path>
        </svg>
      </.link>
    </div>
  </:col>
</Cinder.Table.table>
```

## Performance Optimization

### Efficient Data Loading

```elixir
<Cinder.Table.table
  resource={MyApp.Order}
  actor={@current_user}
  # Preload only what you need
  query_opts={[
    load: [
      :customer,
      :order_items,
      items: [:product]
    ],
    # Select only required fields for better performance
    select: [
      :id, :number, :status, :total_amount, :created_at,
      customer: [:name, :email],
      order_items: [:quantity, product: [:name, :price]]
    ]
  ]}
  # Optimize page size for your data
  page_size={25}
>
  <:col field="number" filter sort>Order #</:col>
  <:col field="customer.name" filter sort>Customer</:col>
  <:col field="total_amount" filter={:number_range} sort>Total</:col>
</Cinder.Table.table>
```

### Strategic Filtering

Only enable filters where users actually need them:

```elixir
<Cinder.Table.table resource={MyApp.Product} actor={@current_user}>
  <!-- Internal ID - no filter needed -->
  <:col :let={product} field="id" sort>{product.id}</:col>

  <!-- User-searchable fields -->
  <:col :let={product} field="name" filter sort>{product.name}</:col>
  <:col :let={product} field="category" filter sort>{product.category}</:col>
  <:col :let={product} field="price" filter={:number_range} sort>${product.price}</:col>

  <!-- Display-only field -->
  <:col :let={product} field="sku">{product.sku}</:col>
</Cinder.Table.table>
```

### Custom Query Optimization

```elixir
<Cinder.Table.table
  resource={MyApp.User}
  actor={@current_user}
  query_opts={[
    # Efficient loading of relationships
    load: [:department, :profile],

    # Limit fields for better performance
    select: [:id, :name, :email, :created_at, :is_active],

    # Custom filters for complex queries
    filter: [is_active: true],

    # Sorting optimization
    sort: [:name]
  ]}
>
  <:col :let={user} field="name" filter sort>{user.name}</:col>
  <:col :let={user} field="email" filter>{user.email}</:col>
  <:col :let={user} field="department.name" filter sort>{user.department.name}</:col>
</Cinder.Table.table>
```

This comprehensive guide demonstrates every available feature and option in Cinder. The combination of intelligent defaults and extensive customization options makes Cinder suitable for simple data display as well as complex, feature-rich table implementations.
