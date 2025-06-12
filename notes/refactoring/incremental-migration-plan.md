# Cinder 2.0 Incremental Migration Plan

## Overview

This plan breaks down the refactoring of Cinder from a 1,664-line monolithic component into a modular, maintainable architecture. Each step is designed to be independently testable and provides clear value while maintaining functionality.

## Current State

- **Monolithic Component**: `lib/cinder/table/live_component.ex` (1,664 lines)
- **Current API**: Complex with 15+ attributes
- **Functionality**: Complete table with sorting, filtering, pagination
- **Tests**: Existing test suite that must continue passing

## Plan

### Phase 1: Extract Theme System (Week 1, Days 1-2) ✅ COMPLETE

**Goal**: Move theme logic to dedicated module

**Steps**:
1. ✅ Create `lib/cinder/theme.ex` with theme struct and merging logic
2. ✅ Extract all theme-related code from main component
3. ✅ Update main component to use new theme module
4. ✅ Add theme presets (default, modern, minimal)

**Testing**:
- ✅ Manual: Verify existing tables still render with same styling
- ✅ Automated: Add tests for theme merging and preset loading (18 tests)
- ✅ Regression: All existing tests pass (108 tests total)

**Files Created**:
- `lib/cinder/theme.ex` (145 lines)
- `test/cinder/theme_test.exs` (270 lines)

**Files Modified**:
- `lib/cinder/table/live_component.ex` (reduced from 1,664 to 1,604 lines - 60 lines removed)

**API Changes**: None (internal only)

**Results**:
- Theme system fully extracted and tested
- Three preset themes available: default, modern, minimal
- All existing functionality preserved
- Component size reduced by 60 lines
- Zero warnings or errors

---

### Phase 2: Extract URL Management (Week 1, Days 3-4) 

**Goal**: Separate URL encoding/decoding logic

**Steps**:
1. Create `lib/cinder/url_manager.ex` for URL state management
2. Extract encode/decode functions from main component
3. Handle filter, pagination, and sort state serialization
4. Update main component to use URL manager

**Testing**:
- Manual: Verify URL updates work, browser back/forward, page refresh
- Automated: Test URL encoding/decoding with various state combinations
- Regression: All existing URL-related functionality preserved

**Files Created**:
- `lib/cinder/url_manager.ex` (~200 lines)

**Files Modified**:
- `lib/cinder/table/live_component.ex` (reduce by ~200 lines)

**API Changes**: None (internal only)

---

### Phase 3: Extract Query Building (Week 1, Days 5-7)

**Goal**: Separate Ash query construction logic

**Steps**:
1. Create `lib/cinder/query_builder.ex` for query construction
2. Extract filter application, sorting, and pagination logic
3. Create clean interface for query transformations
4. Update main component to use query builder

**Testing**:
- Manual: Verify all filters, sorting, pagination work correctly
- Automated: Test query building with various combinations
- Performance: Ensure no query performance regressions

**Files Created**:
- `lib/cinder/query_builder.ex` (~250 lines)

**Files Modified**:
- `lib/cinder/table/live_component.ex` (reduce by ~250 lines)

**API Changes**: None (internal only)

---

### Phase 4: Extract Filter System (Week 2, Days 1-3)

**Goal**: Create modular filter architecture

**Steps**:
1. Create `lib/cinder/filters/base.ex` with filter behavior
2. Create individual filter modules:
   - `lib/cinder/filters/text.ex`
   - `lib/cinder/filters/select.ex` 
   - `lib/cinder/filters/multi_select.ex`
   - `lib/cinder/filters/date_range.ex`
   - `lib/cinder/filters/number_range.ex`
3. Create `lib/cinder/filters/registry.ex` for filter management
4. Update main component to use filter system

**Testing**:
- Manual: Test each filter type individually and in combinations
- Automated: Comprehensive filter system tests
- Regression: All existing filter functionality preserved

**Files Created**:
- `lib/cinder/filters/` directory with 6 modules (~400 lines total)

**Files Modified**:
- `lib/cinder/table/live_component.ex` (reduce by ~400 lines)

**API Changes**: None (internal only)

---

### Phase 5: Extract Column System (Week 2, Days 4-5)

**Goal**: Create smart column configuration system

**Steps**:
1. Create `lib/cinder/column.ex` for column parsing and inference
2. Extract column definition logic from main component
3. Add automatic type inference from Ash resources
4. Support for relationship fields (dot notation)

**Testing**:
- Manual: Verify column rendering and configuration works
- Automated: Test column parsing with various Ash resource types
- Regression: All existing column functionality preserved

**Files Created**:
- `lib/cinder/column.ex` (~150 lines)

**Files Modified**:
- `lib/cinder/table/live_component.ex` (reduce by ~150 lines)

**API Changes**: None (internal only)

---

### Phase 6: Create New Public API (Week 2, Days 6-7)

**Goal**: Introduce simplified public API alongside existing one

**Steps**:
1. Create `lib/cinder/table_v2.ex` with new simplified API
2. Internal component uses all extracted modules
3. Support both old and new APIs simultaneously
4. Add comprehensive documentation for new API

**Testing**:
- Manual: Create example table using new API
- Automated: Full test suite for new API
- Compatibility: Old API continues to work

**Files Created**:
- `lib/cinder/table_v2.ex` (~200 lines)

**API Changes**: New optional API introduced

**New API Example**:
```elixir
<Cinder.TableV2.table
  resource={MyApp.Album}
  current_user={@current_user}
  url_sync
>
  <:col field="title" filter sort>Title</:col>
  <:col field="artist.name" sort>Artist</:col>
</Cinder.TableV2.table>
```

---

### Phase 7: Migration Documentation (Week 3, Days 1-2)

**Goal**: Provide clear migration path

**Steps**:
1. Create comprehensive migration guide
2. Update README with new API examples
3. Create side-by-side API comparison
4. Add migration warnings to old API

**Testing**:
- Manual: Follow migration guide with real application
- Documentation: Verify all examples work

**Files Created**:
- `MIGRATION_GUIDE.md`
- Updated `README.md`

**API Changes**: Deprecation warnings added to old API

---

### Phase 8: Complete Migration (Week 3, Days 3-5)

**Goal**: Replace old API with new one

**Steps**:
1. Move `lib/cinder/table_v2.ex` to `lib/cinder/table.ex`
2. Update main `lib/cinder.ex` to expose new API
3. Remove old implementation files
4. Update all internal references

**Testing**:
- Manual: Verify new API works in real applications
- Automated: Complete test suite migration
- Performance: Benchmark against old implementation

**Files Deleted**:
- Old `lib/cinder/table/live_component.ex`

**Files Modified**:
- `lib/cinder.ex` - New public API
- `lib/cinder/table.ex` - Renamed from table_v2.ex

**API Changes**: Breaking change - old API removed

---

## Final Architecture

After migration, the structure will be:

```
lib/cinder/
├── cinder.ex                    # Main public API
├── table.ex                     # Main table component (~200 lines)
├── theme.ex                     # Theme system (~100 lines)
├── url_manager.ex               # URL synchronization (~200 lines)  
├── query_builder.ex             # Query building (~250 lines)
├── column.ex                    # Column parsing (~150 lines)
└── filters/
    ├── base.ex                  # Filter behavior (~50 lines)
    ├── text.ex                  # Text filter (~70 lines)
    ├── select.ex                # Select filter (~80 lines)
    ├── multi_select.ex          # Multi-select (~80 lines)
    ├── date_range.ex            # Date range (~80 lines)
    ├── number_range.ex          # Number range (~80 lines)
    └── registry.ex              # Filter registry (~60 lines)
```

**Total**: ~1,400 lines across 12 focused modules vs 1,664 lines in 1 file

## Risk Mitigation

### Each Phase
- **Independent**: Can be completed and tested separately
- **Reversible**: Changes can be rolled back if issues arise
- **Testable**: Clear manual and automated testing criteria
- **Functional**: All existing functionality preserved

### Overall Process
- **Gradual**: No big-bang changes that could break everything
- **Compatible**: Old API works until final migration
- **Validated**: Comprehensive testing at each step
- **Documented**: Clear migration path for users

## Success Metrics

- [ ] Each extracted module under 250 lines
- [ ] All existing tests continue passing
- [ ] New API requires 70% fewer configuration attributes
- [ ] No performance regressions
- [ ] Clear migration documentation
- [ ] Complete test coverage for new modules

## Testing Plan

### Manual Testing (Each Phase)
1. **Visual Verification**: Tables render correctly with same styling
2. **Interaction Testing**: All clicks, filters, sorting work as expected
3. **URL Testing**: Browser back/forward, refresh, direct URLs work
4. **Data Testing**: Large datasets, various Ash resources, edge cases

### Automated Testing (Each Phase)
1. **Unit Tests**: New modules have comprehensive test coverage
2. **Integration Tests**: Module interactions work correctly
3. **Regression Tests**: All existing functionality preserved
4. **Performance Tests**: No significant performance degradation

### Final Integration Testing
1. **Migration Testing**: Old API to new API migration works
2. **Real Application Testing**: Test with actual Ash resources
3. **Edge Case Testing**: Complex filters, sorting, pagination combinations
4. **Browser Testing**: Multiple browsers, mobile responsiveness

This plan ensures we can refactor incrementally while maintaining stability and functionality at every step.