# Cinder

A powerful, flexible data table component for Phoenix LiveView applications. Cinder provides rich filtering, sorting, and pagination capabilities with seamless integration into Ash Framework resources.

## Features

- **Rich Filtering System**: Support for text, select, multi-select, date ranges, number ranges, and boolean filters
- **Automatic Type Inference**: Automatically detects appropriate filter types from Ash resource attributes
- **Real-time Updates**: Form-based filtering with live updates and debouncing
- **Complete URL State Management**: Persist filters, pagination, and sorting in URL for shareable, bookmarkable table states
- **Flexible Sorting**: Multi-column sorting with customizable sort functions
- **Pagination**: Built-in pagination with configurable page sizes
- **Themeable**: Comprehensive theming system with Tailwind CSS classes
- **Ash Integration**: Native support for Ash Framework resources and queries
- **Custom Filter Functions**: Support for complex custom filtering logic
- **Responsive Design**: Mobile-friendly responsive layout

## Installation

Add `cinder` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:cinder, "~> 0.1.0"}
  ]
end
```

## Basic Usage

```elixir
<Cinder.Table.table
  id="my-table"
  query={MyApp.Music.Album}
  current_user={@current_user}
>
  <:col key="title" label="Album Title" sortable filterable>
    <%= item.title %>
  </:col>
  <:col key="artist_name" label="Artist" filterable>
    <%= item.artist.name %>
  </:col>
  <:col key="release_date" label="Release Date" sortable>
    <%= Calendar.strftime(item.release_date, "%B %d, %Y") %>
  </:col>
</Cinder.Table.table>
```

## Filter Types

### Text Filters

For searching within text fields with case-insensitive matching:

```elixir
<:col key="title" label="Title" filterable filter_type={:text}>
  <%= item.title %>
</:col>

# With custom placeholder
<:col
  key="description"
  label="Description"
  filterable
  filter_type={:text}
  filter_options={[placeholder: "Search descriptions..."]}
>
  <%= item.description %>
</:col>
```

### Select Filters (Dropdowns)

For filtering by predefined options:

```elixir
<:col
  key="status"
  label="Status"
  filterable
  filter_type={:select}
  filter_options={[
    options: [{"Active", :active}, {"Inactive", :inactive}, {"Pending", :pending}],
    prompt: "All Statuses"
  ]}
>
  <%= item.status %>
</:col>
```

### Multi-Select Filters (Checkboxes)

For filtering by multiple values simultaneously:

```elixir
<:col
  key="genres"
  label="Genres"
  filterable
  filter_type={:multi_select}
  filter_options={[
    options: [
      {"Rock", "rock"},
      {"Pop", "pop"},
      {"Jazz", "jazz"},
      {"Classical", "classical"}
    ]
  ]}
>
  <%= Enum.join(item.genres, ", ") %>
</:col>
```

### Boolean Filters (Radio Buttons)

For true/false filtering with custom labels:

```elixir
<:col
  key="featured"
  label="Featured"
  filterable
  filter_type={:boolean}
  filter_options={[
    labels: %{all: "Any", true: "Featured", false: "Not Featured"}
  ]}
>
  <%= if item.featured, do: "Yes", else: "No" %>
</:col>
```

### Date Range Filters

For filtering by date ranges with from/to inputs:

```elixir
<:col
  key="release_date"
  label="Release Date"
  filterable
  filter_type={:date_range}
>
  <%= Calendar.strftime(item.release_date, "%Y-%m-%d") %>
</:col>
```

### Number Range Filters

For filtering by numeric ranges with min/max inputs:

```elixir
<:col
  key="price"
  label="Price"
  filterable
  filter_type={:number_range}
>
  $<%= item.price %>
</:col>
```

## Automatic Type Inference

Cinder automatically infers appropriate filter types from Ash resource attributes:

- **Ash.Type.String** → `:text` filter
- **Ash.Type.Enum** → `:select` filter with enum options
- **Ash.Type.Boolean** → `:boolean` filter
- **Ash.Type.Date** → `:date_range` filter
- **Ash.Type.Integer/Decimal/Float** → `:number_range` filter

```elixir
# This will automatically use appropriate filters based on your Ash resource
<:col key="title" label="Title" filterable>
  <%= item.title %>
</:col>
<:col key="status" label="Status" filterable>
  <%= item.status %>
</:col>
```

## Sorting

Enable sorting on columns:

```elixir
# Basic sorting
<:col key="title" label="Title" sortable>
  <%= item.title %>
</:col>

# Custom sort function
<:col
  key="artist_name"
  label="Artist"
  sortable
  sort_fn={fn query, direction ->
    # Custom sorting logic
    Ash.Query.sort(query, [{:artist, :name}, direction])
  end}
>
  <%= item.artist.name %>
</:col>

# Dot notation for relationship sorting
<:col key="artist.name" label="Artist Name" sortable>
  <%= item.artist.name %>
</:col>
```

## Custom Filter Functions

For complex filtering logic:

```elixir
<:col
  key="complex_field"
  label="Complex Filter"
  filterable
  filter_fn={fn query, filter_config ->
    # Custom filtering logic
    case filter_config.value do
      "special" ->
        Ash.Query.filter(query, special_condition == true)
      value ->
        Ash.Query.filter(query, field == ^value)
    end
  end}
>
  <%= item.complex_field %>
</:col>
```

## Theming

Customize the appearance with theme options:

```elixir
<Cinder.Table.table
  id="my-table"
  query={MyApp.Music.Album}
  current_user={@current_user}
  theme={%{
    table_class: "w-full border-collapse bg-white shadow-lg rounded-lg",
    th_class: "px-6 py-4 bg-gray-50 text-left font-semibold text-gray-900 border-b",
    td_class: "px-6 py-4 border-b border-gray-200",
    filter_container_class: "bg-blue-50 border border-blue-200 rounded-lg p-4 mb-4"
  }}
>
  <!-- columns -->
</Cinder.Table.table>
```

### Available Theme Keys

- **Table Structure**: `container_class`, `table_class`, `thead_class`, `tbody_class`, `th_class`, `td_class`
- **Filtering**: `filter_container_class`, `filter_inputs_class`, `filter_text_input_class`, `filter_select_input_class`
- **Pagination**: `pagination_wrapper_class`, `pagination_button_class`, `pagination_info_class`
- **Sorting**: `sort_asc_icon_name`, `sort_desc_icon_name`, `sort_none_icon_name`

## Advanced Features

### Pagination Configuration

```elixir
<Cinder.Table.table
  id="my-table"
  query={MyApp.Music.Album}
  current_user={@current_user}
  page_size={50}
>
  <!-- columns -->
</Cinder.Table.table>
```

Pagination controls automatically appear when data spans multiple pages. Navigation preserves filter and sort state.

### Relationship Filtering

Filter on related data:

```elixir
<:col key="artist.name" label="Artist Name" filterable>
  <%= item.artist.name %>
</:col>
```

### Pre-applied State

Start with filters, pagination, or sorting already active by passing URL parameters:

```elixir
# Navigate to a pre-filtered, sorted, paginated view
{:noreply, push_navigate(socket, to: ~p"/albums?status=active&sort=-title&page=2")}
```

## Complete URL State Management

The table component supports complete URL synchronization for filters, pagination, and sorting state. This enables shareable URLs, browser back/forward navigation, and state persistence on page refresh.

### Setup

```elixir
# In your LiveView template
<Cinder.Table.table
  id="albums-table"
  query={MyApp.Music.Album}
  current_user={@current_user}
  url_filters={@url_filters}
  url_page={@url_page}
  url_sort={@url_sort}
  on_state_change={:state_changed}
>
  <!-- columns -->
</Cinder.Table.table>
```

### LiveView Implementation

```elixir
# Handle state change notifications
def handle_info({:state_changed, table_id, state}, socket) do
  # Extract filters, pagination, and sorting from state
  url_filters = Map.drop(state, [:page, :sort])
  url_page = Map.get(state, :page)
  url_sort = Map.get(state, :sort)

  # Build query parameters
  params = url_filters
  params = if url_page, do: Map.put(params, "page", url_page), else: params
  params = if url_sort, do: Map.put(params, "sort", url_sort), else: params

  {:noreply, push_patch(socket, to: ~p"/albums?#{params}")}
end

# Pass URL parameters back to table component
def mount(params, _session, socket) do
  url_filters = Map.drop(params, ["page", "sort"])
  url_page = Map.get(params, "page")
  url_sort = Map.get(params, "sort")

  socket = assign(socket, 
    url_filters: url_filters, 
    url_page: url_page, 
    url_sort: url_sort
  )
  
  {:ok, socket}
end

# Update state when URL changes
def handle_params(params, _url, socket) do
  url_filters = Map.drop(params, ["page", "sort"])
  url_page = Map.get(params, "page")
  url_sort = Map.get(params, "sort")

  socket = assign(socket,
    url_filters: url_filters,
    url_page: url_page,
    url_sort: url_sort
  )

  {:noreply, socket}
end
```

### URL Format

The complete table state is encoded in URL parameters:

**Filters**:
- **Text filters**: `?title=search_term`
- **Select filters**: `?status=active`  
- **Multi-select filters**: `?genres=rock,pop,jazz`
- **Date ranges**: `?release_date=2020-01-01,2023-12-31`
- **Number ranges**: `?price=10.00,99.99`
- **Boolean filters**: `?featured=true`

**Pagination**:
- **Page number**: `?page=3`

**Sorting** (using Ash sort string format):
- **Single column ascending**: `?sort=title`
- **Single column descending**: `?sort=-title`
- **Multiple columns**: `?sort=-title,author,-date`

**Complete Example**:
```
/albums?status=active&genres=rock,pop&price=10.00,50.00&page=2&sort=-title,author
```

This URL represents:
- Albums with status "active"
- Genres including "rock" or "pop"  
- Price between $10.00 and $50.00
- Page 2 of results
- Sorted by title descending, then author ascending

## Event Handling

The component emits state change events that you can handle in your LiveView:

```elixir
def handle_info({:state_changed, table_id, state}, socket) do
  # Handle complete table state changes (filters, pagination, sorting)
  # See URL State Management section for full implementation
  {:noreply, socket}
end
```

## Key Features Summary

✅ **Automatic Filter Type Inference**: Detects appropriate filters from Ash resource attributes  
✅ **Complete URL State Management**: Filters, pagination, and sorting synchronized with URL  
✅ **Form-Based Filtering**: Real-time updates with optimal UX and state persistence  
✅ **Multi-Column Sorting**: With custom functions and dot notation for relationships  
✅ **Comprehensive Theming**: Customizable CSS classes for all components  
✅ **Responsive Design**: Mobile-friendly with proper loading states  
✅ **Production Ready**: Comprehensive testing and error handling  

## Requirements

- Phoenix LiveView 1.0+
- Ash Framework 3.0+
- Elixir 1.17+

## Contributing

Contributions are welcome! Please read our contributing guidelines and submit pull requests to our GitHub repository.

## License

This project is licensed under the MIT License - see the LICENSE file for details.
