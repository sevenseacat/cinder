# Cinder

A powerful, flexible data table component for Phoenix LiveView applications. Cinder provides rich filtering, sorting, and pagination capabilities with seamless integration into Ash Framework resources.

## Features

- **Rich Filtering System**: Support for text, select, multi-select, date ranges, number ranges, and boolean filters
- **Automatic Type Inference**: Automatically detects appropriate filter types from Ash resource attributes
- **Real-time Updates**: Form-based filtering with live updates and debouncing
- **URL State Management**: Persist filter state in URL for shareable, bookmarkable filtered views
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

### Relationship Filtering

Filter on related data:

```elixir
<:col key="artist.name" label="Artist Name" filterable>
  <%= item.artist.name %>
</:col>
```

### Pre-applied Filters

Start with filters already active by passing them through URL parameters or initial state in your LiveView.

## URL State Management

Enable URL synchronization to persist filter state across page reloads and allow shareable filtered URLs:

```elixir
# In your LiveView
<Cinder.Table.table
  id="my-table"
  query={MyApp.Music.Album}
  current_user={@current_user}
  url_filters={@url_filters}
  on_filter_change={:filter_changed}
>
  <!-- columns -->
</Cinder.Table.table>
```

Handle filter change events to update the URL:

```elixir
def handle_info({:filter_changed, _table_id, encoded_filters}, socket) do
  # Get current path and update URL with new filter state
  current_path = socket.assigns.current_path || "/"

  new_url = if Enum.empty?(encoded_filters) do
    current_path
  else
    current_path <> "?" <> URI.encode_query(encoded_filters)
  end

  {:noreply, push_patch(socket, to: new_url)}
end

def handle_params(params, url, socket) do
  # Extract current path and filter parameters
  uri = URI.parse(url)
  current_path = uri.path || "/"
  filter_params = Map.drop(params, ["live_action"])

  socket =
    socket
    |> assign(:current_path, current_path)
    |> assign(:url_filters, filter_params)

  {:noreply, socket}
end
```

### Helper Function

For easier setup, you can copy this helper function to your LiveView:

```elixir
# Add this to your LiveView module
defp handle_table_filter_change(socket, encoded_filters) do
  current_path = socket.assigns.current_path || "/"

  new_url = if Enum.empty?(encoded_filters) do
    current_path
  else
    current_path <> "?" <> URI.encode_query(encoded_filters)
  end

  push_patch(socket, to: new_url)
end

# Then use it in your filter change handler
def handle_info({:filter_changed, _table_id, encoded_filters}, socket) do
  {:noreply, handle_table_filter_change(socket, encoded_filters)}
end
```

### Filter URL Format

Filters are encoded in the URL as query parameters:

- **Text filters**: `?title=search_term`
- **Select filters**: `?status=active`
- **Multi-select filters**: `?genres=rock,pop,jazz`
- **Date ranges**: `?release_date=2020-01-01,2023-12-31`
- **Number ranges**: `?price=10.00,99.99`
- **Boolean filters**: `?featured=true`

Example filtered URL:
```
/albums?status=active&genres=rock,pop&price=10.00,50.00&featured=true
```

## Event Handling

The component can emit custom events that you can handle in your LiveView:

```elixir
def handle_info({:table_updated, table_id, data}, socket) do
  # Handle table updates (if using custom events)
  {:noreply, socket}
end
```

## Requirements

- Phoenix LiveView 0.20+
- Ash Framework 3.0+
- Elixir 1.14+

## Contributing

Contributions are welcome! Please read our contributing guidelines and submit pull requests to our GitHub repository.

## License

This project is licensed under the MIT License - see the LICENSE file for details.
