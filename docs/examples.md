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
- [Filter-Only Slots](#filter-only-slots)
- [Searching](#searching)
- [Sorting](#sorting)
- [Custom Filter Functions](#custom-filter-functions)
- [Theming](#theming)
- [URL State Management](#url-state-management)
- [Relationship Fields](#relationship-fields)
- [Embedded Resources](#embedded-resources)
- [Interactive Tables](#interactive-tables)
- [Action Columns](#action-columns)
- [Table Refresh](#table-refresh)
- [Performance Optimization](#performance-optimization)
- [Testing](#testing)

## Filter-Only Slots

Filter-only slots allow you to add filtering capabilities for fields that you don't want to display as columns in your table. This is perfect for keeping your table clean while providing powerful filtering options.

### Basic Filter-Only Slots

```elixir
<Cinder.Table.table resource={MyApp.User} actor={@current_user}>
  <!-- Display columns -->
  <:col :let={user} field="name" filter sort>{user.name}</:col>
  <:col :let={user} field="email">{user.email}</:col>

  <!-- Filter-only slots - not displayed in table -->
  <:filter field="created_at" type="date_range" label="Registration Date" />
  <:filter field="department" type="select" options={["Engineering", "Sales"]} />
  <:filter field="active" type="boolean" label="Active Users" />
</Cinder.Table.table>
```

### Auto-Detection

Just like column filters, filter-only slots support automatic type detection based on your Ash resource attributes:

```elixir
<Cinder.Table.table resource={MyApp.User} actor={@current_user}>
  <:col :let={user} field="name">{user.name}</:col>
  <:col :let={user} field="email">{user.email}</:col>

  <!-- These will auto-detect appropriate filter types -->
  <:filter field="age" />           <!-- number_range for integer -->
  <:filter field="created_at" />    <!-- date_range for datetime -->
  <:filter field="active" />        <!-- boolean for boolean -->
  <:filter field="department" />    <!-- text for string -->
</Cinder.Table.table>
```

### Custom Labels and Options

Customize the filter appearance with labels and options:

```elixir
<Cinder.Table.table resource={MyApp.Product} actor={@current_user}>
  <:col :let={product} field="name" filter sort>{product.name}</:col>
  <:col :let={product} field="price" sort>{product.price}</:col>

  <!-- Custom labels and select options -->
  <:filter field="category" type="select"
           label="Product Category"
           options={[{"Electronics", "electronics"}, {"Books", "books"}, {"Clothing", "clothing"}]} />

  <:filter field="created_at" type="date_range" label="Launch Date" />

  <:filter field="in_stock" type="boolean" label="Available Now" />
</Cinder.Table.table>
```

### Complex Filter Scenarios

Filter-only slots work great for administrative interfaces where you need many filtering options:

```elixir
<Cinder.Table.table resource={MyApp.Order} actor={@current_admin}>
  <!-- Essential display columns -->
  <:col :let={order} field="id" sort>#{order.id}</:col>
  <:col :let={order} field="customer.email">{order.customer.email}</:col>
  <:col :let={order} field="total" sort>{order.total}</:col>

  <!-- Extensive filtering without cluttering the display -->
  <:filter field="status" type="select"
           options={[{"Pending", "pending"}, {"Shipped", "shipped"}, {"Delivered", "delivered"}]} />

  <:filter field="created_at" type="date_range" label="Order Date" />

  <:filter field="customer.country" type="select"
           label="Customer Country"
           options={[{"US", "us"}, {"CA", "ca"}, {"UK", "uk"}]} />

  <:filter field="payment_method" type="select"
           options={[{"Credit Card", "card"}, {"PayPal", "paypal"}, {"Bank Transfer", "bank"}]} />

  <:filter field="total" type="number_range" label="Order Value" />

  <:filter field="discount_applied" type="boolean" label="Has Discount" />
</Cinder.Table.table>
```

### Relationship and Embedded Field Filtering

Filter-only slots support the same relationship and embedded field syntax as regular columns:

```elixir
<Cinder.Table.table resource={MyApp.User} actor={@current_user}>
  <:col :let={user} field="name">{user.name}</:col>
  <:col :let={user} field="email">{user.email}</:col>

  <!-- Relationship filtering -->
  <:filter field="department.name" type="select"
           label="Department"
           options={[{"Engineering", "engineering"}, {"Sales", "sales"}]} />

  <:filter field="manager.name" type="text" label="Manager" />

  <!-- Embedded resource filtering -->
  <:filter field="profile__country" type="select" label="Country" />
  <:filter field="settings__timezone" type="select" label="Timezone" />
</Cinder.Table.table>
```

### Field Conflict Prevention

Cinder prevents you from defining the same field in both a column (with filtering enabled) and a filter-only slot:

```elixir
<!-- This will raise an error -->
<Cinder.Table.table resource={MyApp.User} actor={@current_user}>
  <:col :let={user} field="name" filter>{user.name}</:col>  <!-- Filter enabled -->
  <:filter field="name" type="text" />  <!-- Conflict! -->
</Cinder.Table.table>
```

## Basic Usage

### Minimal Table

The simplest possible table:

```elixir
<Cinder.Table.table resource={MyApp.User} actor={@current_user}>
  <:col :let={user} field="name">{user.name}</:col>
  <:col :let={user} field="email">{user.email}</:col>
</Cinder.Table.table>
```

### With Filter-Only Fields

Add filtering on fields without displaying them in the table:

```elixir
<Cinder.Table.table resource={MyApp.User} actor={@current_user}>
  <:col :let={user} field="name" filter sort>{user.name}</:col>
  <:col :let={user} field="email">{user.email}</:col>

  <!-- Filter on these fields without showing them as columns -->
  <:filter field="created_at" type="date_range" label="Registration Date" />
  <:filter field="department" type="select" options={["Engineering", "Sales", "Marketing"]} />
  <:filter field="last_login" />  <!-- Auto-detects as date_range -->
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
    filter={[
      type: :select,
      options: [{"Electronics", "electronics"}, {"Books", "books"}, {"Clothing", "clothing"}],
      prompt: "All Categories"
    ]}
  >
    {product.category}
  </:col>

  <!-- Number column with range filter -->
  <:col
    :let={product}
    field="price"
    filter={[
      type: :number_range,
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
    filter={[
      type: :boolean,
      labels: %{
        all: "Any Stock Status",
        true: "In Stock",
        false: "Out of Stock"
      }
    ]}
  >
    {if product.in_stock, do: "In Stock", else: "Out of Stock"}
  </:col>

  <!-- Column with custom sort cycle -->
  <:col
    :let={product}
    field="updated_at"
    sort={[cycle: [nil, :desc_nils_last, :asc_nils_first]]}
    label="Last Updated"
  >
    {product.updated_at}
  </:col>

  <!-- Column with standard filter function -->
  <:col
    :let={product}
    field="status"
    filter={[
      type: :select,
      options: [{"Active", "active"}, {"Discontinued", "discontinued"}],
      fn: &filter_product_status/2
    ]}
  >
    {product.status}
  </:col>

  <!-- Column with both custom sort and filter -->
  <:col
    :let={product}
    field="priority"
    sort={&sort_by_business_priority/2}
    filter={[type: :select, fn: &filter_by_priority_level/2]}
  >
    {product.priority}
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

You can also explicitly specify filter types: `:text`, `:select`, `:multi_select`, `:multi_checkboxes`, `:boolean`, `:checkbox`, `:date_range`, `:number_range`

> **💡 Advanced Filtering:** For complex filtering logic (like business rules or custom operators), see [Custom Filter Functions](#custom-filter-functions) for examples of custom filter functions.

### Filter Format Options

Cinder supports multiple filter specification formats:

**Simple formats:**
- `filter={:select}` (atom format)
- `filter="select"` (string format)

**Unified format with options (recommended):**
- `filter={[type: :select, options: [...], prompt: "Choose..."]}` (atom type)
- `filter={[type: "select", options: [...], prompt: "Choose..."]}` (string type)
- `filter={[type: :select, options: [...], fn: &custom_filter/2]}` (with filter function)

**Legacy format (deprecated):**
- `filter={:select} filter_options={[options: [...]]}`

The unified format is recommended as it keeps all filter configuration in one place and is consistent with other table options like `page_size`.

## Legacy Format

For backward compatibility, the old separate parameter format is still supported but will log a deprecation warning:

```elixir
<!-- This still works but logs a deprecation warning -->
<:col field="status" filter={:select} filter_options={[options: [{"A", "a"}]]} />

<!-- Use this instead -->
<:col field="status" filter={[type: :select, options: [{"A", "a"}]]} />
```

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
    filter={[type: :text, placeholder: "Search article content..."]}
  >
    {String.slice(article.content, 0, 100)}...
  </:col>

  <!-- Text filter with case sensitivity -->
  <:col
    :let={article}
    field="author_name"
    filter={[type: :text, placeholder: "Author name...", case_sensitive: true]}
  >
    {article.author_name}
  </:col>

  <!-- Checkbox filter for boolean field -->
  <:col :let={article} field="published" filter={[type: :checkbox, label: "Published only"]}>
    {if article.published, do: "✓", else: "✗"}
  </:col>

  <!-- Checkbox filter for non-boolean field -->
  <:col :let={article} field="priority" filter={[type: :checkbox, value: "high", label: "High priority only"]}>
    {article.priority}
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
    filter={[
      type: :select,
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
    filter={[
      type: :select,
      options: [{"Paid", true}, {"Unpaid", false}],
      prompt: "Payment Status"
    ]}
  >
    {if order.is_paid, do: "Paid", else: "Unpaid"}
  </:col>
</Cinder.Table.table>
```

### Multi-Select Filter

#### Basic Multi-Select (ANY Logic)

By default, multi-select filters use "ANY" logic - records are shown if they contain at least one of the selected values:

```elixir
<Cinder.Table.table resource={MyApp.Book} actor={@current_user}>
  <!-- Multi-select for tags with default ANY logic -->
  <:col
    field="tags"
    filter={[
      type: :multi_select,
      options: [
        {"Fiction", "fiction"},
        {"Non-Fiction", "non_fiction"},
        {"Science Fiction", "sci_fi"},
        {"Romance", "romance"},
        {"Biography", "biography"}
      ]
    ]}
  />
  >
    {Enum.join(book.tags, ", ")}
  </:col>
</Cinder.Table.table>
```

#### Multi-Select with ALL Logic

Use `match_mode: :all` to show only records that contain ALL selected values:

```elixir
<Cinder.Table.table resource={MyApp.Book} actor={@current_user}>
  <!-- Multi-select requiring ALL selected tags -->
  <:col
    field="tags"
    filter={[
      type: :multi_select,
      options: [
        {"Fiction", "fiction"},
        {"Bestseller", "bestseller"},
        {"Award Winner", "award_winner"},
        {"New Release", "new_release"}
      ],
      match_mode: :all
    ]}
  />
  >
    <div class="flex flex-wrap gap-1">
      {for tag <- book.tags do}
        <span class="px-2 py-1 text-xs bg-green-100 text-green-800 rounded-full">
          {String.capitalize(String.replace(tag, "_", " "))}
        </span>
      {/for}
    </div>
  </:col>

  <!-- Multi-select for categories with ANY logic (explicit) -->
  <:col
    :let={book}
    field="categories"
    filter={[
      type: :multi_select,
      options: [
        {"Bestseller", "bestseller"},
        {"New Release", "new_release"},
        {"Award Winner", "award_winner"}
      ],
      match_mode: :any
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

#### Multi-Checkboxes with Match Mode

The `multi_checkboxes` filter also supports the same `match_mode` options:

```elixir
<Cinder.Table.table resource={MyApp.Book} actor={@current_user}>
  <!-- Multi-checkboxes with ANY logic (default) -->
  <:col
    field="genres"
    filter={[
      type: :multi_checkboxes,
      options: [
        {"Science Fiction", "sci_fi"},
        {"Fantasy", "fantasy"},
        {"Mystery", "mystery"},
        {"Romance", "romance"}
      ]
    ]}
  >
    {Enum.join(book.genres, ", ")}
  </:col>

  <!-- Multi-checkboxes with ALL logic -->
  <:col
    field="awards"
    filter={[
      type: :multi_checkboxes,
      options: [
        {"Hugo Award", "hugo"},
        {"Nebula Award", "nebula"},
        {"World Fantasy Award", "wfa"}
      ],
      match_mode: :all
    ]}
  >
    <div class="flex flex-wrap gap-1">
      {for award <- book.awards do}
        <span class="px-2 py-1 text-xs bg-yellow-100 text-yellow-800 rounded-full">
          {award}
        </span>
      {/for}
    </div>
  </:col>
</Cinder.Table.table>
```

#### Match Mode Comparison

Both `multi_select` and `multi_checkboxes` support the same match mode options:

- **`match_mode: :any`** (default): Shows records containing **at least one** of the selected values
  - Example: Selecting "Fiction" and "Romance" shows books tagged with either "Fiction" OR "Romance" (or both)

- **`match_mode: :all`**: Shows records containing **all** of the selected values
  - Example: Selecting "Fiction" and "Bestseller" shows only books tagged with both "Fiction" AND "Bestseller"

This is particularly useful for:
- **ANY mode**: Finding books in multiple genres or categories
- **ALL mode**: Finding books that meet multiple criteria (e.g., "Fiction" AND "Award Winner")

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
    filter={[
      type: :boolean,
      labels: %{
        all: "Any Verification Status",
        true: "Verified",
        false: "Unverified"
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
    filter={[
      type: :boolean,
      labels: %{
        all: "All Users",
        true: "Subscribers",
        false: "Non-subscribers"
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
    filter={[
      type: :date_range,
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
    filter={[type: :date_range, include_time: true]}
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
    filter={[
      type: :number_range,
      min: 500,
      max: 10000,
      step: 100
    ]}
  >
    {Number.Delimit.number_to_delimited(property.square_feet)} sq ft
  </:col>

  <!-- Decimal number range -->
  <:col
    :let={product}
    field="rating"
    filter={[
      type: :number_range,
      min: 0.0,
      max: 5.0,
      step: 0.5
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

## Filter-Only Slots

Filter-only slots allow you to add filtering capabilities for fields that you don't want to display as columns in your table. This keeps your table clean and focused while providing powerful filtering options.

### Basic Filter-Only Slots

```elixir
<Cinder.Table.table resource={MyApp.User} actor={@current_user}>
  <!-- Display columns -->
  <:col :let={user} field="name" filter sort>{user.name}</:col>
  <:col :let={user} field="email">{user.email}</:col>

  <!-- Filter-only slots - appear in filter controls but not as columns -->
  <:filter field="created_at" type="date_range" label="Registration Date" />
  <:filter field="department" type="select" options={["Engineering", "Sales", "Marketing"]} />
  <:filter field="last_login" type="date_range" />
</Cinder.Table.table>
```

### Auto-Detection of Filter Types

When you don't specify a `type`, Cinder automatically detects the appropriate filter based on the field's Ash resource type:

```elixir
<Cinder.Table.table resource={MyApp.Product} actor={@current_user}>
  <:col :let={product} field="name">{product.name}</:col>
  <:col :let={product} field="price">${product.price}</:col>

  <!-- Auto-detected filter types -->
  <:filter field="created_at" />          <!-- becomes :date_range -->
  <:filter field="stock_count" />         <!-- becomes :number_range -->
  <:filter field="is_featured" />         <!-- becomes :boolean -->
  <:filter field="tags" />                <!-- becomes :multi_select for arrays -->
</Cinder.Table.table>
```

### Custom Labels

Provide custom labels for better UX:

```elixir
<Cinder.Table.table resource={MyApp.Order} actor={@current_user}>
  <:col :let={order} field="number">{order.number}</:col>
  <:col :let={order} field="total">${order.total}</:col>

  <!-- Custom labels for filter-only slots -->
  <:filter field="created_at" type="date_range" label="Order Date" />
  <:filter field="customer_id" type="select" label="Customer" options={@customer_options} />
  <:filter field="status" label="Order Status" />  <!-- Auto-detects type, uses custom label -->
</Cinder.Table.table>
```

### Filter Type Specific Options

Each filter type supports different configuration options:

#### Text Filters

```elixir
<:filter 
  field="description" 
  type="text"
  operator="starts_with"        <!-- :contains (default), :starts_with, :ends_with, :equals -->
  case_sensitive={true}         <!-- default: false -->
  placeholder="Search text..."  <!-- custom placeholder -->
/>
```

#### Select Filters

```elixir
<:filter 
  field="status" 
  type="select"
  options={[{"Active", "active"}, {"Inactive", "inactive"}]}  <!-- required -->
  prompt="Choose status..."     <!-- optional "Choose..." text -->
/>
```

#### Multi-Select Filters

```elixir
<!-- Dropdown interface -->
<:filter 
  field="tags" 
  type="multi_select"
  options={["urgent", "backend", "frontend"]}
  match_mode="any"              <!-- :any (OR logic, default) or :all (AND logic) -->
  prompt="Select tags..."       <!-- optional prompt text -->
/>

<!-- Checkbox list interface -->
<:filter 
  field="categories" 
  type="multi_checkboxes"
  options={[{"Category A", "cat_a"}, {"Category B", "cat_b"}]}
  match_mode="all"              <!-- :any (OR logic, default) or :all (AND logic) -->
/>
```

#### Boolean Filters

```elixir
<:filter 
  field="is_published" 
  type="boolean"
  labels={%{                    <!-- custom labels for radio buttons -->
    all: "All Articles", 
    true: "Published Only", 
    false: "Drafts Only"
  }}
/>
```

#### Checkbox Filters

```elixir
<!-- Boolean field -->
<:filter 
  field="featured" 
  type="checkbox" 
  label="Featured items only"   <!-- required label text -->
/>

<!-- Non-boolean field with custom value -->
<:filter 
  field="priority" 
  type="checkbox"
  value="high"                  <!-- value to filter by when checked -->
  label="High priority only"    <!-- required label text -->
/>
```

#### Date Range Filters

```elixir
<:filter 
  field="created_at" 
  type="date_range"
  format="date"                 <!-- :date (default) or :datetime -->
  include_time={false}          <!-- default: false -->
/>

<!-- With time selection -->
<:filter 
  field="event_datetime" 
  type="date_range"
  format="datetime"
  include_time={true}
/>
```

#### Number Range Filters

```elixir
<:filter 
  field="price" 
  type="number_range"
  step={0.01}                   <!-- step increment (default: 1) -->
  min={0}                       <!-- minimum allowed value -->
  max={9999.99}                 <!-- maximum allowed value -->
/>
```

#### Complete Example with Mixed Filter Types

```elixir
<Cinder.Table.table resource={MyApp.Product} actor={@current_user}>
  <:col :let={product} field="name">{product.name}</:col>
  <:col :let={product} field="price">${product.price}</:col>
  
  <!-- Text search with custom operator -->
  <:filter field="description" type="text" operator="contains" placeholder="Search descriptions..." />
  
  <!-- Multi-select categories with AND logic -->
  <:filter field="categories" type="multi_select" options={@category_options} match_mode="all" />
  
  <!-- Boolean with custom labels -->
  <:filter field="in_stock" type="boolean" labels={%{all: "All Items", true: "In Stock", false: "Out of Stock"}} />
  
  <!-- Checkbox for featured items -->
  <:filter field="featured" type="checkbox" label="Featured products only" />
  
  <!-- Date range for creation date -->
  <:filter field="created_at" type="date_range" label="Created Date" />
  
  <!-- Number range for price with constraints -->
  <:filter field="price" type="number_range" min={0} max={10000} step={10} />
</Cinder.Table.table>
```

### Field Conflict Prevention

You cannot use the same field in both a column filter and a filter-only slot:

```elixir
<!-- This will raise an error -->
<Cinder.Table.table resource={MyApp.User} actor={@current_user}>
  <:col :let={user} field="name" filter>{user.name}</:col>  <!-- Filter enabled -->
  <:filter field="name" type="text" />                      <!-- Conflict! -->
</Cinder.Table.table>

<!-- Instead, choose one approach -->
<Cinder.Table.table resource={MyApp.User} actor={@current_user}>
  <!-- Option 1: Column with filter -->
  <:col :let={user} field="name" filter>{user.name}</:col>

  <!-- Option 2: Display column + filter-only slot -->
  <:col :let={user} field="name">{user.name}</:col>  <!-- No filter -->
  <:filter field="name" type="text" />               <!-- Filter-only -->
</Cinder.Table.table>
```

### Relationship and Embedded Fields

Filter-only slots work with relationship and embedded fields:

```elixir
<Cinder.Table.table resource={MyApp.Order} actor={@current_user}>
  <:col :let={order} field="number">{order.number}</:col>
  <:col :let={order} field="total">${order.total}</:col>

  <!-- Relationship field filters -->
  <:filter field="customer.company_name" type="text" label="Company" />
  <:filter field="customer.region" type="select" options={@regions} />

  <!-- Embedded field filters -->
  <:filter field="billing_address__country" type="select" options={@countries} />
  <:filter field="shipping_address__postal_code" type="text" label="Shipping ZIP" />
</Cinder.Table.table>
```

### When to Use Filter-Only Slots

**Use filter-only slots when:**
- You want to filter by fields that would clutter the table display
- You need many filter options but limited column space
- Filtering fields are for search/discovery but not primary data display
- You want to keep the table focused on the most important information

**Examples:**
- **User Management**: Display name/email, filter by registration date, department, role, last login
- **E-commerce**: Display product name/price, filter by category, brand, stock status, creation date
- **CRM**: Display contact name/company, filter by lead source, stage, assigned user, activity date
- **Content Management**: Display title/author, filter by publication date, tags, status, category

## Searching

Cinder provides global search functionality that automatically enables when columns have the `search` attribute. This allows searching across multiple columns from a single field.

### Auto-Enable Search

Search automatically appears when any column has `search`:

```elixir
<Cinder.Table.table resource={MyApp.Album} actor={@current_user}>
  <:col :let={album} field="title" filter search>{album.title}</:col>
  <:col :let={album} field="artist.name" filter search>{album.artist.name}</:col>
  <:col :let={album} field="genre" filter>{album.genre}</:col>
</Cinder.Table.table>
```

### Custom Search Configuration

Customize search label and placeholder:

```elixir
<Cinder.Table.table
  resource={MyApp.Product}
  search={[label: "Find Products", placeholder: "Search by name or SKU..."]}
  actor={@current_user}
>
  <:col :let={product} field="name" search>{product.name}</:col>
  <:col :let={product} field="sku" search>{product.sku}</:col>
  <:col :let={product} field="price" filter>{product.price}</:col>
</Cinder.Table.table>
```

### Search with Relationships

Search works across relationship fields:

```elixir
<Cinder.Table.table resource={MyApp.Order} actor={@current_user}>
  <:col :let={order} field="number" search>{order.number}</:col>
  <:col :let={order} field="customer.name" search>{order.customer.name}</:col>
  <:col :let={order} field="customer.email" search>{order.customer.email}</:col>
</Cinder.Table.table>
```

### Custom Search Functions

For advanced search requirements, provide a custom search function as part of the search configuration:

```elixir
defmodule MyApp.CustomSearch do
  def advanced_search(query, searchable_columns, search_term) do
    # Any logic here to filter the query and return the updated query
  end
end

<Cinder.Table.table
  resource={MyApp.User}
  search={[
    label: "Find Users",
    placeholder: "Search by name, email, or role...",
    fn: &MyApp.CustomSearch.advanced_search/3
  ]}
  actor={@current_user}
>
  <:col :let={user} field="name" search>{user.name}</:col>
  <:col :let={user} field="email" search>{user.email}</:col>
  <:col :let={user} field="role">{user.role}</:col>
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

### Custom Sort Cycles

You can define custom sort cycles that control the order of sort states when clicking column headers:

```elixir
<Cinder.Table.table resource={MyApp.Invoice} actor={@current_user}>
  <!-- Most recent first when clicked -->
  <:col :let={invoice} field="created_at" sort={[cycle: [nil, :desc_nils_last, :asc_nils_first]]}>
    {invoice.created_at}
  </:col>

  <!-- Standard Ash sort directions with custom cycle -->
  <:col :let={invoice} field="priority" sort={[cycle: [nil, :desc_nils_first, :asc_nils_last]]}>
    {invoice.priority}
  </:col>

  <!-- Standard Ash sort directions -->
  <:col :let={invoice} field="payment_date" sort={[cycle: [nil, :desc_nils_first, :asc]]}>
    {invoice.payment_date}
  </:col>
</Cinder.Table.table>
```

**Default Cycle:** `[nil, :asc, :desc]` (unsorted → ascending → descending → unsorted)

**Ash Built-in Directions:** `:asc_nils_first`, `:desc_nils_first`, `:asc_nils_last`, `:desc_nils_last`

Sort cycles work perfectly with Ash's built-in null handling directions, providing intuitive UI with standard up/down arrow indicators.

> **💡 Advanced Sorting:** Sort cycles with Ash built-in directions cover most sorting needs. For complex business logic, consider using Ash calculations or pre-sorting your queries.

## Custom Filter Functions

Custom filter functions enable complex filtering logic:

```elixir
defmodule MyAppWeb.InvoicesLive do
  require Ash.Query

  # Custom filter with business logic
  def filter_invoice_status(query, filter_config) do
    %{value: status} = filter_config

    case status do
      "overdue" ->
        # Complex business rule: overdue = past due date AND unpaid
        today = Date.utc_today()
        query
        |> Ash.Query.filter(due_date < ^today)
        |> Ash.Query.filter(payment_status == :unpaid)

      "pending_approval" ->
        # Another business rule: needs manager approval
        query
        |> Ash.Query.filter(status == :draft)
        |> Ash.Query.filter(approval_required == true)

      _ ->
        # Standard equality for other statuses
        Ash.Query.filter(query, status == ^status)
    end
  end

  def render(assigns) do
    ~H"""
    <Cinder.Table.table resource={MyApp.Invoice} actor={@current_user}>
      <!-- Custom filter function -->
      <:col :let={invoice} field="status" filter={[
        type: :select,
        options: [
          {"Active", "active"},
          {"Overdue", "overdue"},
          {"Pending Approval", "pending_approval"}
        ],
        fn: &filter_invoice_status/2
      ]}>
        {invoice.status}
      </:col>

      <!-- Standard filters still work -->
      <:col :let={invoice} field="customer_name" filter>
        {invoice.customer_name}
      </:col>
    </Cinder.Table.table>
    """
  end
end
```

### Function Signatures

Custom filter functions must follow this signature:

- **Filter functions:** `filter_fn(query :: Ash.Query.t(), filter_config :: map()) :: Ash.Query.t()`

The functions receive actual `Ash.Query` structs and should use `Ash.Query` functions like `Ash.Query.filter/2` to modify the query.

### Mixed Standard and Custom

You can mix standard sorting, sort cycles, and custom filter functions:

```elixir
<Cinder.Table.table resource={MyApp.Order} actor={@current_user}>
  <!-- Standard sort and filter -->
  <:col :let={order} field="order_number" sort filter>
    {order.order_number}
  </:col>

  <!-- Custom sort cycle with null handling -->
  <:col :let={order} field="priority" sort={[cycle: [nil, :desc_nils_first, :asc_nils_last]]}>
    {order.priority}
  </:col>

  <!-- Custom filter function -->
  <:col :let={order} field="status" filter={[type: :select, fn: &filter_complex_status/2]}>
    {order.status}
  </:col>

  <!-- Sort cycle with custom filter -->
  <:col :let={order} field="created_at"
        sort={[cycle: [nil, :desc_nils_last, :asc_nils_first]]}
        filter={[type: :date_range, fn: &filter_business_dates/2]}>
    {order.created_at}
  </:col>
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
    socket = Cinder.Table.UrlSync.handle_params(params, uri, socket)
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
    socket = Cinder.Table.UrlSync.handle_params(params, uri, socket)
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
    filter={[
      type: :select,
      options: [{"Bronze", "bronze"}, {"Silver", "silver"}, {"Gold", "gold"}],
      prompt: "All Tiers"
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

## Embedded Resources

Cinder provides full support for embedded resources using double underscore notation (`__`). Embedded fields are automatically detected and typed, including automatic enum detection for select filters.

### Basic Embedded Fields

```elixir
<Cinder.Table.table resource={MyApp.Album} actor={@current_user}>
  <:col :let={album} field="title" filter sort>{album.title}</:col>

  <!-- Embedded resource fields use __ notation -->
  <:col :let={album} field="publisher__name" filter>{album.publisher.name}</:col>
  <:col :let={album} field="publisher__country" filter>{album.publisher.country}</:col>
  <:col :let={album} field="metadata__genre" filter>{album.metadata.genre}</:col>
</Cinder.Table.table>
```

### Nested Embedded Fields

```elixir
<Cinder.Table.table resource={MyApp.User} actor={@current_user}>
  <:col :let={user} field="name" filter sort>{user.name}</:col>

  <!-- Deep nested embedded fields -->
  <:col :let={user} field="settings__notifications__email" filter>
    {if user.settings.notifications.email, do: "✓", else: "✗"}
  </:col>
  <:col :let={user} field="profile__address__country" filter>{user.profile.address.country}</:col>
  <:col :let={user} field="preferences__theme__color" filter>{user.preferences.theme.color}</:col>
</Cinder.Table.table>
```

### Automatic Enum Detection

When embedded fields use `Ash.Type.Enum`, Cinder automatically detects them and creates select filters:

```elixir
# In your embedded resource
defmodule MyApp.Publisher do
  use Ash.Resource, data_layer: :embedded

  attributes do
    attribute :name, :string
    attribute :country, MyApp.Country  # Enum type
  end
end

defmodule MyApp.Country do
  use Ash.Type.Enum, values: ["Australia", "India", "Japan", "England", "Canada"]
end
```

```elixir
<!-- This automatically becomes a select filter with enum values -->
<Cinder.Table.table resource={MyApp.Album} actor={@current_user}>
  <:col :let={album} field="title" filter sort>{album.title}</:col>
  <:col :let={album} field="publisher__country" filter>{album.publisher.country}</:col>
</Cinder.Table.table>
```

### Mixed Relationships and Embedded Fields

You can combine relationship navigation (dot notation) with embedded fields (double underscore):

```elixir
<Cinder.Table.table resource={MyApp.Order} actor={@current_user}>
  <:col :let={order} field="number" filter sort>#{order.number}</:col>

  <!-- Relationship + embedded field -->
  <:col :let={order} field="customer.profile__country" filter>
    {order.customer.profile.country}
  </:col>
  <:col :let={order} field="shipping.address__postal_code" filter>
    {order.shipping.address.postal_code}
  </:col>
</Cinder.Table.table>
```

## Interactive Tables

### Row Click Functionality

Make entire rows clickable for navigation or actions. When `row_click` is provided, rows will be styled as clickable with hover effects and cursor changes.

#### Basic Navigation

```elixir
<Cinder.Table.table
  resource={MyApp.User}
  actor={@current_user}
  row_click={fn user -> JS.navigate(~p"/users/#{user.id}") end}
>
  <:col :let={user} field="name" filter sort>{user.name}</:col>
  <:col :let={user} field="email" filter>{user.email}</:col>
  <:col :let={user} field="role" filter={:select}>{user.role}</:col>
</Cinder.Table.table>
```

#### Custom JavaScript Actions

```elixir
<Cinder.Table.table
  resource={MyApp.Product}
  actor={@current_user}
  row_click={fn product -> JS.push("select_product") |> JS.push_focus() end}
>
  <:col :let={product} field="name" filter sort>{product.name}</:col>
  <:col :let={product} field="price" filter={:number_range} sort>${product.price}</:col>
</Cinder.Table.table>
```

**Note:** The `row_click` function receives the row item as its argument and should return a Phoenix.LiveView.JS command. When provided, rows automatically receive `cursor-pointer` styling to indicate they are interactive.

## Action Columns

Action columns allow you to add buttons, links, and other interactive elements to your tables without requiring a database field. Simply omit the `field` attribute to create an action column.

### Basic Action Column

```elixir
<Cinder.Table.table resource={MyApp.User} actor={@current_user}>
  <:col :let={user} field="name" filter sort>{user.name}</:col>
  <:col :let={user} field="email" filter>{user.email}</:col>
  <:col :let={user} field="role" filter={:select}>{user.role}</:col>

  <!-- Action column - no field required -->
  <:col :let={user} label="Actions" class="text-right">
    <.link patch={~p"/users/#{user.id}"} class="text-blue-600 hover:text-blue-800 mr-3">
      Edit
    </.link>
    <.link
      href={~p"/users/#{user.id}"}
      method="delete"
      class="text-red-600 hover:text-red-800"
      data-confirm="Are you sure?"
    >
      Delete
    </.link>
  </:col>
</Cinder.Table.table>
```

**Note:** Action columns cannot have `filter` or `sort` attributes since they don't correspond to database fields. If you try to add these attributes without a `field`, you'll get a validation error.

## Table Refresh

Refresh table data after CRUD operations while maintaining filters, sorting, and pagination state. This is essential when performing operations that modify the data displayed in your tables.

### Basic Refresh

After deleting, updating, or creating records, refresh the specific table:

```elixir
defmodule MyAppWeb.UsersLive do
  use MyAppWeb, :live_view
  import Cinder.Table.Refresh # <--

  def render(assigns) do
    ~H"""
    <Cinder.Table.table id="users-table" resource={MyApp.User} actor={@current_user}>
      <:col :let={user} field="name" filter sort>{user.name}</:col>
      <:col :let={user} field="email" filter>{user.email}</:col>
      <:col :let={user} field="active" filter>{if user.active, do: "Active", else: "Inactive"}</:col>

      <!-- Action column with refresh functionality -->
      <:col :let={user} label="Actions">
        <button phx-click="delete_user" phx-value-id={user.id}>
          Delete
        </button>
      </:col>
    </Cinder.Table.table>
    """
  end

  def handle_event("delete_user", %{"id" => id}, socket) do
    MyApp.User
    |> Ash.get!(id, actor: socket.assigns.current_user)
    |> Ash.destroy!(actor: socket.assigns.current_user)

    # Refresh the specific table - maintains filters, sorting, pagination
    {:noreply, refresh_table(socket, "users-table")}
  end
end
```

### Multiple Table Refresh

When operations affect multiple tables, refresh them all by providing a list of table IDs:

```elixir
refresh_tables(socket, ["users-table", "audit-logs-table"])
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

### Pagination Configuration

When using configurable page sizes, ensure your Ash action supports pagination to prevent memory issues:

```elixir
# In your resource
defmodule MyApp.User do
  use Ash.Resource

  actions do
    read :read do
      pagination offset?: true, default_limit: 25
    end
  end
end
```

```elixir
<Cinder.Table.table
  resource={MyApp.User}
  actor={@current_user}
  # Configurable page sizes - requires action with pagination
  page_size={[default: 25, options: [10, 25, 50, 100]]}
>
  <:col field="name" filter sort>Name</:col>
  <:col field="email" filter sort>Email</:col>
</Cinder.Table.table>
```

**Important**: Without pagination configured in your Ash action, Cinder will load ALL records into memory, potentially causing out-of-memory crashes with large datasets. See the [Ash pagination guide](https://hexdocs.pm/ash/pagination.html) for complete documentation.

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
    # Query building options
    load: [:department, :profile],
    select: [:id, :name, :email, :created_at, :is_active],
    
    # Execution options
    timeout: :timer.seconds(30),
    authorize?: false,
    max_concurrency: 10
  ]}
>
  <:col :let={user} field="name" filter sort>{user.name}</:col>
  <:col :let={user} field="email" filter>{user.email}</:col>
  <:col :let={user} field="department.name" filter sort>{user.department.name}</:col>
</Cinder.Table.table>
```

**Supported Query Options:**
- **Query Building**: `:select`, `:load` 
- **Execution**: `:timeout`, `:authorize?`, `:max_concurrency`

### Default Filters and Sorting

Use the `query` parameter with pre-built Ash.Query for defaults, but understand how they interact with table UI:

#### Default Base Filters (Additive)
```elixir
# Base filters that are ALWAYS applied, invisible to users
<Cinder.Table.table
  query={MyApp.User |> Ash.Query.filter(is_active: true, company_id: @company.id)}
  actor={@current_user}
>
  <:col :let={user} field="name" filter sort>{user.name}</:col>
  <:col :let={user} field="department" filter>{user.department}</:col>
</Cinder.Table.table>
```
- Query filters act as **hidden base filters**
- Table filter UI adds **additional filters** on top
- Result: `is_active: true AND company_id: X AND [user's table filters]`
- **Use case**: Security filters, tenant isolation, business rules

#### Default Sort Order (Replaced)
```elixir
# Initial sort that users can override
<Cinder.Table.table
  query={MyApp.User |> Ash.Query.sort([:name, :created_at])}
  actor={@current_user}
>
  <:col :let={user} field="name" filter sort>{user.name}</:col>
  <:col :let={user} field="created_at" sort>{user.created_at}</:col>
</Cinder.Table.table>
```
- Query sorts show as **initial table sort indicators**
- When user clicks any column sort, query sorts are **completely replaced**
- Result: Either query sorts OR user's table sorts (never both)
- **Use case**: Sensible default ordering that users can change

#### Important: Don't Mix Filter Sources
```elixir
# ❌ AVOID: This creates conflicting filters
<Cinder.Table.table
  query={MyApp.User |> Ash.Query.filter(department: "Engineering")}
  actor={@current_user}
>
  <!-- User sees empty department filter, but query already filters by Engineering -->
  <:col :let={user} field="department" filter>{user.department}</:col>
</Cinder.Table.table>
```
If user sets department filter to "Sales", result is: `department = "Engineering" AND department = "Sales"` (no results).

**Better approach for visible defaults**: Use URL state or LiveView assigns to populate filter UI.

## Testing

When creating LiveView tests for pages with Cinder tables use [`render_async`](https://hexdocs.pm/phoenix_live_view/Phoenix.LiveViewTest.html#render_async/2) to wait for data to load before checking for the data on page.

```elixir
test "lists all user", %{conn: conn} do
  user = insert(:user)

  {:ok, index_live, html} = live(conn, ~p"/users")

  assert html =~ "Listing Users"
  assert html =~ "Loading..."
  assert render_async(index_live) =~ user.name
end
```
