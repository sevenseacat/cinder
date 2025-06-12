# Cinder 2.0 - Simplified API Design & Implementation Plan

## New Architecture Overview

Since we can break the public API, we'll create a dramatically simplified and more intuitive design that eliminates complexity while maintaining all core functionality.

## Core Design Principles

1. **Convention over Configuration**: Smart defaults with minimal required configuration
2. **Composable Architecture**: Small, focused modules that work together
3. **Simple Mental Model**: Easy to understand and predict behavior
4. **Zero Config Start**: Working table with just resource and columns
5. **Progressive Enhancement**: Add features incrementally as needed

## New Simplified API

### Basic Usage (Zero Config)
```elixir
<Cinder.table
  resource={MyApp.Album}
  current_user={@current_user}
>
  <:col field="title">Title</:col>
  <:col field="artist.name">Artist</:col>
  <:col field="release_date">Released</:col>
</Cinder.table>
```

This automatically provides:
- Smart type inference for filters/sorting
- Basic pagination
- Responsive design
- Loading states

### Progressive Enhancement
```elixir
<Cinder.table
  resource={MyApp.Album}
  current_user={@current_user}
  paginate={50}
  url_sync
>
  <:col field="title" filter sort>Title</:col>
  <:col field="status" filter={:select}>Status</:col>
  <:col field="price" filter={:range}>Price</:col>
  <:col field="artist.name" sort>Artist</:col>
</Cinder.table>
```

### Advanced Configuration
```elixir
<Cinder.table
  resource={MyApp.Album}
  current_user={@current_user}
  theme="modern"
  url_sync
  on_change={&handle_table_change/1}
>
  <:col field="title" filter sort>
    <.link href={~p"/albums/#{item.id}"}>
      <%= item.title %>
    </.link>
  </:col>
  
  <:col field="genres" filter={:multi_select}>
    <%= Enum.join(item.genres, ", ") %>
  </:col>
</Cinder.table>
```

## Key API Simplifications

### 1. Single Component Function
- `Cinder.table/1` instead of `Cinder.Table.table/1`
- No need for LiveComponent module reference

### 2. Simplified Attributes
```elixir
# Old (15+ attributes)
<Cinder.Table.table
  id="my-table"
  query={MyApp.Album}
  query_opts={[load: [:artist]]}
  current_user={@current_user}
  page_size={25}
  url_filters={@url_filters}
  url_page={@url_page}
  url_sort={@url_sort}
  on_state_change={:state_changed}
  theme={%{...}}
>

# New (3-5 attributes)
<Cinder.table
  resource={MyApp.Album}
  current_user={@current_user}
  url_sync
  on_change={&handle_table_change/1}
>
```

### 3. Simplified Column Configuration
```elixir
# Old (complex slot attributes)
<:col 
  key="title" 
  label="Title" 
  sortable 
  filterable 
  filter_type={:text}
  filter_options={[placeholder: "Search..."]}
  sort_fn={fn query, direction -> ... end}
/>

# New (simple boolean flags)
<:col field="title" filter sort>Title</:col>
<:col field="status" filter={:select}>Status</:col>
<:col field="price" filter={:range}>Price</:col>
```

## New Module Structure

### Core Architecture
```
lib/cinder/
├── cinder.ex              # Main public API
└── internal/
    ├── component.ex        # Main LiveComponent (simplified)
    ├── column.ex           # Column parsing and configuration
    ├── filters/
    │   ├── filters.ex      # Filter coordination
    │   ├── text.ex         # Text filter
    │   ├── select.ex       # Select filter
    │   ├── range.ex        # Range filters (date/number)
    │   └── multi_select.ex # Multi-select filter
    ├── query/
    │   ├── builder.ex      # Query building coordination
    │   ├── filter.ex       # Apply filters to queries
    │   ├── sort.ex         # Apply sorting to queries
    │   └── paginate.ex     # Pagination logic
    ├── url/
    │   ├── sync.ex         # URL synchronization
    │   └── codec.ex        # Encode/decode URL state
    └── theme/
        ├── theme.ex        # Theme management
        └── presets.ex      # Built-in themes
```

### Public API Surface
```elixir
# lib/cinder.ex - The ONLY public module users import
defmodule Cinder do
  use Phoenix.Component
  
  # Main table function - only public API
  def table(assigns)
  
  # Optional: Theme helpers
  def theme(name_or_config)
end
```

## Implementation Plan

### Phase 1: Core Infrastructure (Week 1)
1. **New Main Module** (`lib/cinder.ex`)
   - Single `table/1` function
   - Simplified attribute parsing
   - Column configuration parsing

2. **Internal Component** (`lib/cinder/internal/component.ex`)
   - Simplified LiveComponent (~200 lines)
   - Focus on coordination, not implementation
   - Clean state management

3. **Column System** (`lib/cinder/internal/column.ex`)
   - Parse new column syntax
   - Infer types from Ash resources
   - Generate filter/sort configurations

### Phase 2: Filter System (Week 1)
1. **Filter Architecture** (`lib/cinder/internal/filters/`)
   - Simple, focused filter implementations
   - Each filter type in separate module
   - Consistent interface across all filters

2. **Smart Type Inference**
   - Automatically detect appropriate filter types
   - Override with explicit configuration when needed
   - Support for custom filter types

### Phase 3: Query & URL Management (Week 1)
1. **Query Builder** (`lib/cinder/internal/query/`)
   - Clean separation of query building logic
   - Composable query transformations
   - Optimized for performance

2. **URL Synchronization** (`lib/cinder/internal/url/`)
   - Automatic URL sync with `url_sync` flag
   - Clean encoding/decoding
   - Browser history support

### Phase 4: Polish & Themes (Week 1)
1. **Theme System** (`lib/cinder/internal/theme/`)
   - Preset themes: `:default`, `:modern`, `:minimal`
   - Custom theme support
   - CSS variable-based customization

2. **Documentation & Examples**
   - Updated README with new API
   - Migration guide from old API
   - Comprehensive examples

## New File Structure After Refactoring

```
lib/cinder/
├── cinder.ex                    # Main public API (150 lines)
└── internal/
    ├── component.ex             # Main LiveComponent (200 lines)
    ├── column.ex                # Column parsing (100 lines)
    ├── filters/
    │   ├── filters.ex           # Filter coordination (100 lines)
    │   ├── text.ex              # Text filter (80 lines)
    │   ├── select.ex            # Select filter (100 lines)
    │   ├── range.ex             # Range filters (120 lines)
    │   └── multi_select.ex      # Multi-select (100 lines)
    ├── query/
    │   ├── builder.ex           # Query building (150 lines)
    │   ├── filter.ex            # Filter application (100 lines)
    │   ├── sort.ex              # Sorting logic (80 lines)
    │   └── paginate.ex          # Pagination (80 lines)
    ├── url/
    │   ├── sync.ex              # URL synchronization (100 lines)
    │   └── codec.ex             # URL encoding/decoding (120 lines)
    └── theme/
        ├── theme.ex             # Theme management (80 lines)
        └── presets.ex           # Built-in themes (100 lines)
```

**Total**: ~1,560 lines across 16 focused modules vs 1,664 lines in 1 massive file

## Benefits of New Design

### For Users
- **5x Simpler API**: From 15+ attributes to 3-5
- **Zero Config Start**: Working table with just resource + columns
- **Intuitive**: Column config matches mental model
- **Progressive**: Add features as needed

### for Developers
- **16 Focused Modules**: Each under 200 lines
- **Clear Separation**: Each module has single responsibility
- **Easy Testing**: Isolated, testable components
- **Easy Extension**: Plugin architecture for custom features

### for Maintainers
- **Single Public API**: Only `Cinder.table/1` is public
- **Internal Organization**: Clean internal structure
- **Breaking Changes**: Only affect internal modules
- **Documentation**: Simpler to document and understand

## Migration Strategy

1. **Implement New API**: Build new architecture alongside old
2. **Update Tests**: Comprehensive test suite for new API
3. **Update Documentation**: New README, guides, examples
4. **Remove Old Code**: Delete old implementation
5. **Release**: Version 2.0 with breaking changes

## Success Criteria

- [ ] Main public API: Single `table/1` function
- [ ] Column config: Simple boolean flags
- [ ] Zero config: Working table with minimal setup
- [ ] All modules: Under 200 lines each
- [ ] Test coverage: 90%+ maintained
- [ ] Performance: Equal or better than current
- [ ] Documentation: Complete rewrite with new examples

This design provides the same functionality with dramatically reduced complexity while maintaining extensibility and performance.