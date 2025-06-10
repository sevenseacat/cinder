# Feature 004: Table Filtering System

## Plan

### Overview
Implement a comprehensive filtering system for the LiveView table component that allows users to filter data based on column values with various filter types (text, select, date range, etc.).

### Core Requirements

**Functional Requirements:**
- **Column-based filtering** - Each column can be marked as `filterable` with filter type
- **Multiple filter types** - Text, select/dropdown, date range, number range, boolean
- **Real-time filtering** - Filters applied immediately as user types/selects
- **Filter persistence** - Filters maintained during sorting and pagination
- **Clear filters** - Ability to reset individual filters or all filters
- **Visual feedback** - Clear indication of active filters and filter state
- **Ash query integration** - Filters applied at database level via Ash queries

**Filter Types to Support:**
- **Text filter** - Contains/starts with/equals text matching
- **Select filter** - Dropdown with predefined options
- **Multi-select filter** - Multiple option selection
- **Date range filter** - From/to date selection
- **Number range filter** - Min/max numeric values
- **Boolean filter** - True/false/all checkbox/radio

### Implementation Phases

#### Phase 4.1: Core Filter Infrastructure
- Extend column definition schema with filter configuration
- Add filter state management to LiveComponent
- Implement basic filter UI container
- Add filter state to query building pipeline

#### Phase 4.2: Text and Select Filters
- Implement text filter with configurable matching (contains/starts_with/equals)
- Implement single-select dropdown filter
- Add visual filter indicators and clear buttons
- Test basic filtering functionality

#### Phase 4.3: Advanced Filter Types
- Implement multi-select filter with checkboxes
- Add date range filter with date pickers
- Add number range filter with min/max inputs
- Add boolean filter with radio/checkbox options

#### Phase 4.4: Filter UX Enhancements
- Add "Clear all filters" functionality
- Implement filter count indicators
- Add filter state persistence across navigation
- Optimize filter performance with debouncing

#### Phase 4.5: Custom Filter Functions
- Support custom filter functions for complex filtering logic
- Add relationship field filtering (dot notation)
- Implement filter validation and error handling
- Add filter presets/saved filters capability

### Technical Architecture

#### Filter State Schema
```elixir
%{
  filters: %{
    "column_key" => %{
      type: :text | :select | :multi_select | :date_range | :number_range | :boolean,
      value: term(), # varies by filter type
      operator: :contains | :starts_with | :equals | :in | :between | :is
    }
  }
}
```

#### Column Filter Configuration
```elixir
%{
  key: "title",
  label: "Title",
  filterable: true,
  filter_type: :text,
  filter_options: [
    operator: :contains, # default operator
    placeholder: "Search titles...",
    case_sensitive: false
  ]
}

%{
  key: "status",
  filterable: true,
  filter_type: :select,
  filter_options: [
    options: [
      {"Active", "active"},
      {"Inactive", "inactive"},
      {"Pending", "pending"}
    ],
    prompt: "All Statuses"
  ]
}
```

#### Filter UI Structure
```
┌─────────────────────────────────────────┐
│ 🔍 Filters (2 active) [Clear All]      │
├─────────────────────────────────────────┤
│ Title: [Search box...] [X]              │
│ Status: [Dropdown ▼] [X]                │
│ Date: [From] - [To] [X]                 │
│ + Add Filter                            │
└─────────────────────────────────────────┘
```

### Dependencies
- Existing table component (Phase 1-3)
- Phoenix LiveView form helpers for filter inputs
- Date picker component (or HTML5 date inputs)
- Ash query filtering capabilities

### Deliverables
- Extended column definition schema with filter configuration
- Filter UI components and layouts
- Filter state management in LiveComponent
- Ash query integration for database-level filtering
- Comprehensive test coverage for all filter types
- Updated documentation with filter examples

## Testing Plan

### Manual Testing (iex Console)

#### Basic Filter Testing
```elixir
# Start LiveView test environment
iex -S mix phx.server

# Test text filtering
# 1. Open table with filterable text column
# 2. Type in text filter
# 3. Verify results update in real-time
# 4. Clear filter and verify all results return

# Test select filtering  
# 1. Open dropdown filter
# 2. Select different options
# 3. Verify filtering works correctly
# 4. Select "All" option to clear filter

# Test multiple filters
# 1. Apply text filter
# 2. Apply select filter
# 3. Verify both filters work together (AND logic)
# 4. Clear individual filters
# 5. Clear all filters at once
```

#### Advanced Filter Testing
```elixir
# Test date range filtering
# 1. Set "from" date only - verify results
# 2. Set "to" date only - verify results  
# 3. Set both dates - verify range filtering
# 4. Clear date filter

# Test relationship filtering
# 1. Filter on "artist.name" field
# 2. Verify relationship queries work properly
# 3. Test performance with complex relationships

# Test filter persistence
# 1. Apply filters
# 2. Sort table - verify filters persist
# 3. Change page - verify filters persist
# 4. Refresh page - verify URL state (if implemented)
```

### Automated Testing

#### Unit Tests - Filter Logic
- Filter state management and updates
- Filter value parsing and validation
- Query building with different filter types
- Filter clearing and reset functionality

#### Component Tests - Filter UI
- Filter input rendering for each type
- Filter state updates on user interaction
- Filter clear buttons functionality
- Multi-filter interaction and state

#### Integration Tests - Full Filtering
- End-to-end filtering with real data
- Filter + sort + pagination combinations
- Performance tests with large datasets
- Error handling for invalid filter values

#### Test Data Setup
```elixir
# Create test resources with filterable fields
defmodule TestAlbum do
  use Ash.Resource
  
  attributes do
    uuid_primary_key :id
    attribute :title, :string
    attribute :genre, :string  
    attribute :release_date, :date
    attribute :price, :decimal
    attribute :is_featured, :boolean
  end
  
  relationships do
    belongs_to :artist, TestArtist
    belongs_to :label, TestLabel
  end
end

# Test data with variety for filtering
test_albums = [
  %{title: "Abbey Road", genre: "rock", release_date: ~D[1969-09-26], price: 15.99, is_featured: true},
  %{title: "Kind of Blue", genre: "jazz", release_date: ~D[1959-08-17], price: 12.99, is_featured: false},
  %{title: "Nevermind", genre: "rock", release_date: ~D[1991-09-24], price: 13.99, is_featured: true}
]
```

### Testing Scenarios

#### Text Filter Scenarios
- Empty filter returns all results
- Partial text matches (contains)
- Exact text matches (equals)
- Case sensitivity handling
- Special characters in filter text
- Very long filter text

#### Select Filter Scenarios  
- All options selectable
- Empty/null value handling
- Invalid option values
- Large option lists performance
- Dynamic option loading

#### Multi-Filter Scenarios
- Multiple text filters (AND logic)
- Text + select filter combinations
- All filter types active simultaneously
- Filter conflicts and edge cases
- Performance with many active filters

#### Performance Scenarios
- Large datasets (10k+ records)
- Complex relationship filters
- Multiple concurrent users filtering
- Filter debouncing effectiveness
- Database query optimization

## Log

### Phase 4.1: Core Filter Infrastructure - COMPLETE ✅

**Implementation Results:**
- **Goal:** Set up filter state management, column schema extensions, and basic UI container
- **Status:** Foundation successfully implemented and tested
- **Duration:** ~45 minutes focused implementation

**Implementation Completed:**
1. ✅ Extended column definition schema to support filter configuration
2. ✅ Added filter state management to LiveComponent assigns and defaults  
3. ✅ Created basic filter UI container in the template
4. ✅ Extended query building pipeline to handle filter state
5. ✅ Added basic filter events and handlers (clear_all_filters, update_filter)
6. ✅ Wrote comprehensive tests for filter infrastructure

**Key Design Decisions Implemented:**
- **Filter state structure:** `%{filters: %{"column_key" => %{type: :text, value: "...", operator: :contains}}}`
- **Column configuration:** Each column supports `filterable: true`, `filter_type: :text/:select/etc.`, `filter_options: []`
- **UI positioning:** Filter controls in dedicated container above table with collapsible design
- **Event isolation:** Filter events use `phx-target={@myself}` for proper component scoping
- **Query pipeline:** New `apply_filters/3` function integrated before sorting in query chain
- **Custom filter support:** `filter_fn` attribute for complex filtering logic

**Technical Implementation:**
- **Schema extensions:** Added `filter_type`, `filter_options`, `filter_fn` to column parsing
- **State management:** Filter state preserved during sorting and pagination  
- **UI framework:** Filter container with header, count indicator, clear all button
- **Event handlers:** Infrastructure for filter updates and clearing
- **Query integration:** `apply_filters/3` function ready for specific filter implementations
- **Theme support:** Complete CSS class configuration for filter UI components

**Filter UI Structure Implemented:**
```
┌─────────────────────────────────────────┐
│ 🔍 Filters (X active) [Clear All]      │
├─────────────────────────────────────────┤
│ Title: [Filter for title]               │
│ Status: [Filter for status]             │
│ Date: [Filter for date]                 │
└─────────────────────────────────────────┘
```

**Testing Results:**
- **33 tests passing** - All existing functionality preserved
- **Filter infrastructure tests** - Column parsing, UI rendering, state management
- **Filter count tests** - Active filter indicators and clear functionality
- **Custom filter function tests** - Support for complex filtering verified
- **Edge case handling** - Columns without filter config handled properly
- **No compilation warnings** - Clean build maintained

**Files Modified:**
- `lib/cinder/table/live_component.ex` - Core infrastructure implementation
- `test/cinder/table_test.exs` - Comprehensive filter infrastructure tests

**Ready for Phase 4.2:** Text and Select Filters implementation
- Filter state management ✅
- UI container framework ✅  
- Event handling infrastructure ✅
- Query pipeline integration ✅
- Test framework established ✅

### Phase 4.2: Text and Select Filters - COMPLETE ✅

**Implementation Results:**
- **Goal:** Implement functional text and select filter inputs with real filtering logic
- **Status:** Core text and select filtering successfully implemented and tested
- **Duration:** ~30 minutes focused implementation

**Implementation Completed:**
1. ✅ Added proper `require Ash.Query` for filter macro syntax
2. ✅ Implemented functional text filter input component with real-time filtering
3. ✅ Implemented select filter dropdown with options from column configuration
4. ✅ Added individual clear buttons (X) on each active filter
5. ✅ Implemented actual database filtering with Ash query expressions
6. ✅ Added proper filter value handling and state management
7. ✅ Updated tests to match new filter input implementations

**Key Features Implemented:**
- **Text filter:** Input field with `phx-blur` event handling and configurable operators (contains/starts_with/equals)
- **Select filter:** Dropdown with options from `filter_options` configuration and prompt text
- **Individual clear buttons:** X button appears when filter has a value, uses `phx-target={@myself}`
- **Real-time updates:** Filters apply on blur (text) and change (select) events
- **Database filtering:** Proper Ash query filtering with `contains()`, `==` operators and pinned variables
- **Visual feedback:** Active filter styling, placeholder text, and clear UI state

**Technical Implementation:**
- **Ash Query Integration:** Added `require Ash.Query` for proper filter macro usage
- **Filter Syntax:** Used proper Ash expressions: `contains(^field_atom, ^value)` and `^field_atom == ^value`
- **Event Handling:** Implemented `update_filter` and `clear_filter` events with proper component targeting
- **Input Components:** Created `text_filter_input/1` and `select_filter_input/1` private functions
- **State Management:** Filter values properly stored and retrieved from component state
- **Operator Support:** Implemented `:contains`, `:starts_with`, `:equals` for text and `:equals` for select

**Filter Types Working:**
- **Text Filter:** Input field with configurable placeholder, handles blur events
- **Select Filter:** Dropdown with options array, prompt text, proper value selection
- **Individual Clear:** X buttons that clear specific filters and update UI immediately

**Database Integration:**
- **Ash Filters:** Proper use of `Ash.Query.filter/2` with expression syntax
- **Field References:** Correct atom conversion and pinned variable usage
- **Operator Support:** Contains matching for text, exact equality for selects
- **Empty Value Handling:** Filters ignored when value is empty or nil

**Testing Results:**
- **39 tests passing** - All functionality working correctly
- **Filter input tests** - Text and select inputs render properly
- **Event handling tests** - Update and clear filter events work correctly
- **Database filtering tests** - Ash query integration verified
- **Edge case handling** - Empty values, missing configs handled properly
- **No compilation warnings** - Clean build maintained

**Files Modified:**
- `lib/cinder/table/live_component.ex` - Filter input components and database filtering
- `test/cinder/table_test.exs` - Updated tests to match new implementations

**Manual Testing Verified:**
- Text input filtering with placeholder text ✅
- Select dropdown filtering with options ✅
- Individual filter clear buttons ✅
- Filter state persistence during interactions ✅
- Proper Ash query generation and execution ✅
- **Case-insensitive text search working** ✅

**Final Implementation Details:**
- **Ash.Expr.ref Usage:** Proper field references using `Ash.Expr.ref(String.to_atom(key))`
- **Filter Expressions:** Correct pinning of both field refs and values: `ilike(^field_ref, ^search_value)`
- **Case Insensitive Search:** Uses `ilike` operator with wildcard patterns for user-friendly search
- **Contains Filter:** `"%#{value}%"` pattern for substring matching
- **Starts With Filter:** `"#{value}%"` pattern for prefix matching
- **Exact Match Filter:** Direct equality comparison with `^field_ref == ^value`

**Ready for Phase 4.3:** Advanced Filter Types (multi-select, date range, number range, boolean)
- Text and select filters ✅
- Database integration ✅
- UI components working ✅
- Event handling complete ✅
- Test coverage complete ✅
- Case-insensitive filtering ✅