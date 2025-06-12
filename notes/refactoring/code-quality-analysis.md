# Cinder Table Component - Code Quality Analysis & Refactoring Plan

## Current State Analysis

### Major Issues

1. **Massive Monolithic Component** (1,664 lines)
   - Single responsibility principle violated
   - Difficult to maintain, test, and extend
   - Hard to onboard new developers
   - Performance implications from large component re-renders

2. **Complex API Surface**
   - Too many concerns mixed in one component
   - 15+ attributes on main component
   - Difficult to understand what's required vs optional
   - Poor discoverability of features

3. **Tight Coupling**
   - Filter logic tightly coupled with rendering
   - URL management mixed with component state
   - Theme logic scattered throughout
   - No clear separation of concerns

4. **Testing Challenges**
   - Hard to unit test individual pieces
   - Integration tests become complex
   - Difficult to mock specific behaviors
   - Poor test isolation

5. **Extension Difficulties**
   - Adding new filter types requires modifying core component
   - Custom behaviors require deep knowledge of internals
   - No plugin architecture

## Proposed Refactoring Structure

### 1. Extract Filter System

**New Structure:**
```
lib/cinder/filters/
├── base.ex              # Filter behavior and common functions
├── text.ex              # Text filter implementation
├── select.ex            # Select/dropdown filter
├── multi_select.ex      # Multi-select checkboxes
├── boolean.ex           # Boolean radio buttons
├── date_range.ex        # Date range picker
├── number_range.ex      # Number range inputs
└── registry.ex          # Filter type registry
```

**Benefits:**
- Each filter type is self-contained and testable
- Easy to add new filter types
- Clear separation of filter logic from rendering
- Plugin architecture for custom filters

### 2. Extract URL State Management

**New Structure:**
```
lib/cinder/url/
├── state_manager.ex     # Main URL state coordination
├── encoder.ex           # Encode table state to URL params
├── decoder.ex           # Decode URL params to table state
└── format.ex            # URL format constants and utilities
```

**Benefits:**
- URL logic separated from component concerns
- Reusable across different table instances
- Easier to test URL encoding/decoding
- Clear API for state serialization

### 3. Extract Theme System

**New Structure:**
```
lib/cinder/theme/
├── theme.ex             # Theme struct and utilities
├── default.ex           # Default theme definitions
└── builder.ex           # Theme merging and building
```

**Benefits:**
- Theme logic centralized
- Easy to create and share theme presets
- Better type safety with structs
- Extensible theme system

### 4. Extract Query Building

**New Structure:**
```
lib/cinder/query/
├── builder.ex           # Main query building coordination
├── filter_applier.ex    # Apply filters to Ash queries
├── sorter.ex            # Apply sorting to queries
└── paginator.ex         # Handle pagination logic
```

**Benefits:**
- Query logic separated from UI concerns
- Reusable query building outside of LiveView
- Easier to test query transformations
- Better performance optimization opportunities

### 5. Component Composition

**New Structure:**
```
lib/cinder/components/
├── table.ex             # Main table wrapper (simplified)
├── header.ex            # Table header with sorting
├── filters.ex           # Filter controls container
├── pagination.ex        # Pagination controls
├── loading.ex           # Loading states
└── empty_state.ex       # Empty/error states
```

**Benefits:**
- Smaller, focused components
- Better reusability
- Easier to customize individual pieces
- Clearer component hierarchy

## Detailed Refactoring Plan

### Phase 1: Extract Filter System
1. Create filter behavior with common interface
2. Implement individual filter types as separate modules
3. Create filter registry for type lookup
4. Update main component to use filter system
5. Add comprehensive tests for each filter type

### Phase 2: Extract URL Management
1. Create URL state manager with encode/decode functions
2. Move all URL-related logic from main component
3. Create clear API for state synchronization
4. Add tests for URL encoding/decoding scenarios

### Phase 3: Extract Theme System
1. Create theme struct with type specifications
2. Move theme merging logic to dedicated module
3. Create theme builder with validation
4. Add theme presets and examples

### Phase 4: Extract Query Building
1. Create query builder with clear API
2. Move filter application logic
3. Move sorting logic
4. Move pagination logic
5. Add comprehensive query building tests

### Phase 5: Component Decomposition
1. Break main component into smaller pieces
2. Create focused sub-components
3. Establish clear component hierarchy
4. Maintain backward compatibility

### Phase 6: API Simplification
1. Reduce main component attributes
2. Create builder pattern for complex configurations
3. Add configuration validation
4. Improve documentation and examples

## Proposed New API

### Simplified Main Component
```elixir
<Cinder.Table.table
  id="my-table"
  resource={MyApp.Album}
  current_user={@current_user}
  config={@table_config}
  state={@table_state}
  on_change={&handle_table_change/2}
>
  <:col key="title" label="Title" />
  <:col key="artist.name" label="Artist" />
</Cinder.Table.table>
```

### Configuration Builder
```elixir
config = 
  Cinder.Config.new()
  |> Cinder.Config.add_filter(:title, type: :text)
  |> Cinder.Config.add_filter(:status, type: :select, options: [...])
  |> Cinder.Config.enable_sorting([:title, :created_at])
  |> Cinder.Config.set_pagination(page_size: 25)
  |> Cinder.Config.apply_theme(:modern)
```

### Custom Filter Types
```elixir
defmodule MyApp.CustomFilter do
  @behaviour Cinder.Filters.Base
  
  def render(assigns), do: ~H[...]
  def apply_filter(query, config), do: ...
  def encode_value(value), do: ...
  def decode_value(encoded), do: ...
end

# Register custom filter
Cinder.Filters.Registry.register(:custom, MyApp.CustomFilter)
```

## Benefits of Refactoring

### For Developers
- **Easier to Understand**: Each module has a single, clear responsibility
- **Easier to Test**: Isolated modules with clear interfaces
- **Easier to Extend**: Plugin architecture for custom behaviors
- **Better IDE Support**: Smaller files, better autocomplete

### For Users
- **Simpler API**: Less configuration required for common cases
- **More Flexible**: Easy to customize specific behaviors
- **Better Performance**: Smaller components, more targeted updates
- **Better Documentation**: Focused docs for each concern

### For Maintenance
- **Reduced Complexity**: Smaller, focused modules
- **Better Error Handling**: Isolated error boundaries
- **Easier Debugging**: Clear separation of concerns
- **Future-Proof**: Extensible architecture

## Migration Strategy

1. **Backward Compatibility**: Maintain existing API during transition
2. **Gradual Migration**: Extract modules one at a time
3. **Comprehensive Testing**: Ensure no regressions
4. **Documentation Updates**: Update docs as modules are extracted
5. **Deprecation Warnings**: Guide users to new patterns

## Timeline Estimate

- **Phase 1-2**: 1-2 weeks (Filters & URL management)
- **Phase 3-4**: 1 week (Theme & Query building)
- **Phase 5-6**: 1-2 weeks (Component decomposition & API)
- **Testing & Documentation**: 1 week
- **Total**: 4-6 weeks

## Success Metrics

- [ ] Main component under 200 lines
- [ ] Each module under 150 lines
- [ ] 90%+ test coverage maintained
- [ ] No breaking changes to public API
- [ ] Documentation completeness
- [ ] Performance maintained or improved