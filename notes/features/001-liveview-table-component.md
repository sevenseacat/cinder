# Feature 001: LiveView Table Component for Ash Queries

## Plan

### Overview
Build a reusable LiveView component (`Cinder.Table`) that automatically generates interactive data tables from Ash queries with support for sorting, filtering, searching, and pagination.

### Core Requirements
1. **Component Interface**: LiveComponent that accepts Ash resource/query and renders HTML table
2. **Column Configuration**: Flexible column definitions with support for:
   - Custom content rendering via slots
   - Sorting (automatic and custom functions)
   - Filtering (automatic and custom options)
   - Searching (automatic and custom functions)
3. **Data Management**:
   - Ash query execution with actor support
   - Pagination using Ash's built-in pagination
   - URL state management for filters/sorts/search
4. **Theming**: Highly customizable CSS classes and layouts
5. **Testability**: PhoenixTest integration for end-to-end testing

### Implementation Phases

#### Phase 1: Core Component Structure
- Create `Cinder.Table` LiveComponent module
- Define basic component interface and slot structure
- Implement basic HTML table rendering
- Set up component state management

#### Phase 2: Data Loading and Pagination
- Implement Ash query execution with actor support
- Add pagination support using Ash.Page
- Create pagination UI component
- Handle page navigation

#### Phase 3: Sorting Implementation
- Add sorting state management
- Implement column header click handlers
- Support for attribute-based sorting
- Support for expression-based sorting (dot notation)
- Custom sort function integration
- URL state synchronization for sorts

#### Phase 4: Filtering System
- Design filter state management
- Implement filter UI above table
- Auto-detect filter types:
  - Enum attributes → dropdown
  - Boolean attributes → tri-state selector
  - Array attributes → matching any item in list
  - Belongs_to relationships → dropdown with related data
  - Custom options support
- URL state synchronization for filters

#### Phase 5: Search Functionality
- Add search input UI
- Implement text search for searchable columns
- Support custom search functions
- Combine search with existing filters
- URL state synchronization for search

#### Phase 6: Theming and Customization
- Define comprehensive theming system
- Allow custom classes for all HTML elements
- Support custom pagination layouts
- Create default theme
- Documentation for theming

#### Phase 7: URL State Management
- Implement URL parameter encoding/decoding
- Handle browser back/forward navigation
- Maintain filter/sort/search state in URL
- Handle initial page load with URL parameters

#### Phase 8: Testing Infrastructure
- Set up PhoenixTest integration
- Create test helpers for table interactions
- Write comprehensive test suite covering all features
- Performance testing for large datasets

### Technical Architecture

#### Component Structure
```
Cinder.Table (LiveComponent)
├── State Management
│   ├── Query parameters (filters, sorts, search, page)
│   ├── Column definitions
│   └── Pagination info
├── Data Layer
│   ├── Ash query building
│   ├── Query execution
│   └── Result processing
├── UI Components
│   ├── Table headers (with sort indicators)
│   ├── Filter controls
│   ├── Search input
│   ├── Table body
│   └── Pagination controls
└── Event Handling
    ├── Sort toggles
    ├── Filter changes
    ├── Search input
    └── Page navigation
```

#### State Schema
```elixir
%{
  # Core data
  resource: MyApp.Album,
  query_opts: [load: [:artist]],
  current_user: %User{},

  # UI state
  page_size: 100,
  current_page: 1,
  sort_by: [{:title, :asc}],
  filters: %{genre: "fiction", category: ["sci-fi", "fantasy"]},
  search_term: "foundation",

  # Results
  page: %Ash.Page{},
  columns: [...],

  # Config
  theme: %{table_class: "table", th_class: "th", ...}
}
```

#### Column Definition Schema
```elixir
%{
  key: "title" | :title | "author.name",
  label: "Title",
  sortable: true,
  searchable: true,
  filterable: true,
  options: ["Short", "Medium", "Long"],
  display_field: :name,
  sort_fn: &sort_by_publisher/2,
  search_fn: &search_publishers/1,
  slot_content: rendered_slot
}
```

### Dependencies
- Phoenix LiveView (existing)
- Ash Framework (existing)
- PhoenixTest (for testing)

### Deliverables
1. `Cinder.Table` LiveComponent module
2. Helper modules for query building and state management
3. Default theme/styling
4. Comprehensive documentation
5. Test suite with PhoenixTest integration
6. Usage examples

## Testing Plan

### Manual Testing (iex Console)
1. **Basic Table Rendering**
   ```elixir
   # Test basic table with simple columns
   # Verify HTML structure and data display
   ```

2. **Sorting Functionality**
   ```elixir
   # Test clicking column headers
   # Verify sort state changes and data reordering
   # Test custom sort functions
   ```

3. **Filtering System**
   ```elixir
   # Test dropdown filters for different attribute types
   # Verify filter combinations
   # Test custom filter options
   ```

4. **Search Functionality**
   ```elixir
   # Test text search across searchable columns
   # Test custom search functions
   # Verify search combined with filters
   ```

5. **Pagination**
   ```elixir
   # Test page navigation
   # Verify pagination info display
   # Test different page sizes
   ```

6. **URL State Management**
   ```elixir
   # Test URL updates on state changes
   # Test initial page load with URL parameters
   # Test browser navigation
   ```

### Automated Testing
1. **Unit Tests** (ExUnit)
   - Query building functions
   - State management helpers
   - Column configuration parsing
   - Filter/sort logic

2. **Integration Tests** (PhoenixTest)
   - Full table rendering
   - Interactive sorting (click headers)
   - Filter interactions (dropdowns, inputs)
   - Search functionality
   - Pagination navigation
   - URL state persistence
   - Multi-column operations

3. **Performance Tests**
   - Large dataset handling
   - Complex query performance
   - Memory usage with pagination

### Test Data Setup
- Create test Ash resources (Album, Artist, Publisher, Category)
- Seed test database with variety of data
- Mock functions for custom sort/search operations
- Test with different user permissions

### Testing Scenarios
1. **Happy Path**: Basic table with all features working
2. **Edge Cases**: Empty results, single row, large datasets
3. **Error Handling**: Invalid queries, network issues, permission errors
4. **Accessibility**: Keyboard navigation, screen readers
5. **Cross-browser**: Different browsers and devices

## Log

### Phase 1: Core Component Structure - COMPLETE ✅

**Implementation Details:**
- Created `Cinder.Table` function component module with full documentation
- Implemented basic component structure with slots for column definitions
- Added comprehensive theming system with default classes
- Created column definition parsing logic with proper validation
- Added support for sortable, searchable, and filterable column attributes
- Implemented consistent `{}` LiveView syntax throughout

**Key Design Decisions:**
- Used Phoenix.Component function component for Phase 1 (will convert to LiveComponent in Phase 2)
- Required `key` attribute for all column slots using proper attr definitions
- Implemented comprehensive theming via CSS class configuration
- Column definitions parsed from slots with sensible defaults using Map.get/3
- State management structure prepared for future phases
- Proper handling of empty and loading states

**API Improvements:**
- Made `key` attribute required for all columns via slot attribute definitions
- Consistent use of `{}` syntax for all LiveView expressions
- Clean, documented function component interface

**Files Created/Modified:**
- `lib/cinder/table.ex` - Main component module (function component)
- `test/cinder/table_test.exs` - Comprehensive component tests
- Updated `lib/cinder.ex` with library documentation

**Testing:**
- 10 unit tests passing for component structure
- Tests cover column parsing, theming, empty states, required attributes
- All warnings resolved
- Clean compilation with no errors

**Architecture Notes:**
- Component ready for LiveComponent conversion in Phase 2 when state management needed
- Theme system fully functional and customizable
- Column parsing robust with proper error handling
- API validates required fields at compile time

### Phase 2: Data Loading and Pagination - COMPLETE ✅

**Implementation Details:**
- Converted to LiveComponent architecture for state management
- Added function component wrapper that delegates to LiveComponent
- Implemented pagination UI controls with Previous/Next buttons
- Added page navigation event handling (`goto_page`)
- Created pagination info display (Page X of Y, showing start-end of total)
- **IMPLEMENTED FULL ASH QUERY EXECUTION** with actor support
- Added comprehensive theming for pagination components
- Separated LiveComponent into dedicated file structure

**Key Design Decisions:**
- Hybrid approach: Function component wrapper + LiveComponent for state
- Pagination-first design - UI ready for real data
- Event-driven page navigation with `phx-target` for component isolation
- Comprehensive pagination info display for user feedback
- **Async data loading** using `start_async/3` pattern for proper LiveComponent async operations
- **Full Ash integration** with proper actor authorization
- Clean separation between UI and data layer

**Architecture Improvements:**
- LiveComponent lifecycle properly implemented (mount/update/render)
- State management for current_page, page_size, loading state
- Pagination controls conditionally rendered (only show if multiple pages)
- Theme system extended with pagination-specific classes
- Component isolation using `@myself` for events
- **Proper module structure** with LiveComponent in separate file
- **Ash query building** with support for load, select, filter options

**Ash Integration Features:**
- **Full query execution** using `Ash.Query.for_read/3` with actor
- **Query options support**: load, select, filter capabilities
- **Pagination support** using `Ash.Query.limit/2` and `Ash.Query.offset/2`
- **Actor authorization** - current_user passed as actor to all queries
- **Error handling** for failed queries with user feedback
- **Async loading** using `start_async/3` to prevent blocking the UI during data fetch
- **Multiple result formats** - handles both list results and paginated results

**Files Created/Modified:**
- `lib/cinder/table.ex` - Function component wrapper
- `lib/cinder/table/live_component.ex` - **NEW** - Full LiveComponent with Ash integration
- `test/cinder/table_test.exs` - Comprehensive test suite

**Testing:**
- **14 tests passing** covering all functionality
- Tests cover basic rendering, theming, loading states, pagination UI
- **Ash integration tests** for query options and actor support
- All warnings resolved and code cleaned up
- Component properly handles async loading behavior

**Pagination Features Implemented:**
- Previous/Next button navigation
- Page info display (Page X of Y)
- Item count display (showing start-end of total)
- Conditional rendering (only show if multiple pages exist)
- Proper event handling with component targeting
- Theme customization for all pagination elements
- **Real data pagination** with Ash query limit/offset

**Data Loading Features:**
- **Ash resource querying** with `Ash.Query.for_read/3`
- **Actor-based authorization** using current_user
- **Query options processing** (load, select, filter)
- **Async data loading** with loading states
- **Error handling** with user-friendly messages
- **Multiple page info builders** for different result types
- **Proper state management** throughout loading lifecycle

**Critical Fixes Applied:**
- **FIXED async loading issue** - replaced `send(self(), ...)` with `start_async/3`
- **Proper LiveComponent async pattern** - uses `handle_async/3` callbacks
- **No parent LiveView dependencies** - component handles all async operations internally
- **ELIMINATED socket copying warnings** - extracted all variables before async operations
- **Simplified icon system** - clean heroicon approach instead of complex fallbacks
- **Production ready** - eliminates all LiveView warnings and complexity

### Phase 3: Sorting Implementation - COMPLETE ✅

**Implementation Details:**
- **Interactive column sorting** with clickable headers for sortable columns
- **Three-state sort cycling**: none → ascending → descending → none
- **Visual sort indicators** with SVG arrows showing current sort direction
- **Multi-column sorting support** with proper sort state management
- **Custom sort functions** for complex sorting logic
- **Dot notation support** for relationship field sorting (e.g., "artist.name")
- **Page reset on sort** - automatically returns to page 1 when sorting changes
- **SMOOTH SORTING EXPERIENCE** - eliminated flickering during async loading with smart state management
- **Column-specific classes** - each column can specify custom CSS classes for th/td elements

**Key Design Decisions:**
- **Click-to-sort interface** - sortable columns have cursor-pointer and click handlers
- **Visual feedback** - clear sort arrows indicate current sort state (asc/desc/none)
- **Ash Query integration** - sorts applied directly to Ash queries for database-level sorting
- **Event isolation** - sort events properly targeted to component with `phx-target={@myself}`
- **State management** - sort state stored in `sort_by` assign as list of `{key, direction}` tuples
- **Performance optimized** - async loading variables extracted to prevent socket copying

**Sorting Features Implemented:**
- **Attribute sorting** - direct sorting on resource attributes
- **Relationship sorting** - dot notation support (e.g., "artist.name")
- **Custom sort functions** - `sort_fn` attribute for complex sorting logic
- **Visual indicators** - customizable sort arrows showing direction
- **Multi-column sorts** - maintains sort order across multiple columns
- **Sort state cycling** - click toggles through none/asc/desc states
- **Page reset** - returns to page 1 when sort changes
- **Customizable sort arrows** - support for heroicons with custom classes
- **Column classes** - individual columns can specify CSS classes for granular styling

**Architecture Improvements:**
- **Enhanced event handling** with `toggle_sort` event
- **Improved query building** with `apply_sorting/3` function
- **Expression sort support** for relationship fields
- **Clean state management** for sort direction tracking
- **Performance optimizations** - eliminated all socket copying in async operations
- **Simplified icon system** - clean heroicon class-based sort arrow configuration
- **Heroicon integration** - simple `<span class={[icon_name, icon_class]} />` approach
- **ANTI-FLICKERING IMPLEMENTATION** - data remains visible during async loading

**Smooth Sorting Implementation:**
The component now provides a professional-grade sorting experience:

1. **Current data stays visible** - no jarring "Loading..." replacement during sort operations
2. **Subtle loading indicators** - positioned spinner overlay shows loading state without hiding content
3. **Immediate visual feedback** - sort arrows update instantly when clicked (opacity changes to 75%)
4. **Progressive enhancement** - sort indicators pulse during loading to show activity
5. **Smooth transitions** - new data appears seamlessly when async operation completes

**Technical Implementation:**
```elixir
def update(%{loading: true} = assigns, socket) do
  # Keep existing data visible while loading
  {:ok, assign(socket, Map.take(assigns, [:loading]))}
end

def update(assigns, socket) do
  # Only update full data when it arrives
  {:ok, assign(socket, assigns)}
end
```

**Visual Enhancements:**
- Container positioned relatively for overlay loading indicator
- Table body dims to 75% opacity during loading (content still visible)
- Sort headers dim to 75% opacity during loading
- Active sort arrows pulse with animation during loading
- Top-right positioned loading spinner with SVG animation
- No content replacement or empty states during sorting

**Files Modified:**
- `lib/cinder/table/live_component.ex` - Added sorting logic and UI
- `test/cinder/table_test.exs` - Added comprehensive sorting tests

**Testing:**
- **28 tests passing** covering all functionality including smooth sorting and column classes
- **Comprehensive sort tests** - clickable headers, visual indicators, custom functions
- **Multi-column sort tests** - multiple sortable columns
- **Dot notation tests** - relationship field sorting
- **Event handling verification** - proper click handlers and targets
- **Sort arrow customization tests** - theme-based icon configuration
- **Smooth sorting tests** - verifies anti-flickering implementation
- **Column class tests** - verifies custom CSS classes applied to th/td elements
- **All warnings resolved** - clean compilation

**Complete API with Column Classes:**
```elixir
<.table 
  id="albums" 
  query={Album} 
  current_user={@current_user}
  theme={%{
    # Customize sort arrows with heroicons
    sort_asc_icon_name: "hero-arrow-up",
    sort_desc_icon_name: "hero-arrow-down",
    sort_asc_icon_class: "w-4 h-4 text-green-500",
    sort_desc_icon_class: "w-4 h-4 text-red-500",
    sort_none_icon_class: "w-4 h-4 text-gray-400"
  }}
>
  <:col :let={album} key="id" label="ID" class="w-16 text-center font-mono">
    {album.id}
  </:col>

  <:col :let={album} key="title" label="Title" sortable class="min-w-0 truncate">
    {album.title}
  </:col>

  <:col :let={album} key="artist.name" label="Artist" sortable class="text-left">
    {album.artist.name}
  </:col>

  <:col :let={album} key="price" label="Price" sortable class="text-right tabular-nums w-24">
    ${album.price}
  </:col>

  <:col :let={album} key="publisher" label="Label" sortable sort_fn={&sort_by_publisher/2} class="text-sm text-gray-600">
    {album.publisher.name}
  </:col>
</.table>

# Column classes are applied to both th and td elements
# Combined with theme classes: class={[@theme.th_class, column.class]}
# Icons rendered as: <span class={[icon_name, icon_class]} />
```

**Next Phase Dependencies:**
- Phase 4 will implement filtering functionality
- **Sorting integration complete and ready** for filtering extensions
- Component state structure prepared for filter state management
- Query building framework supports additional query modifications

## Conclusion

*Final design decisions and architecture will be documented here upon completion*
