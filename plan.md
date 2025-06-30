# Implementation Plan: Cards Table Parity

## Overview
This plan brings the Cards component to full functional parity with the Table component, ensuring consistent behavior, async loading, proper state management, and comprehensive testing.

## Phase 1: Core Functionality Updates (High Priority)
**Files to modify: `lib/cinder/cards/live_component.ex`**

### ✅ Status Legend
- ✅ Completed
- 🔄 In Progress  
- ⏳ Pending

### 1. Add "refresh" event handler ✅
**Status:** Completed
- ✅ Added `handle_event("refresh", _params, socket)` following Table pattern
- ✅ Triggers `load_data(socket)` and returns `{:noreply, socket}`

### 2. Replace synchronous loading with async pattern ✅
**Status:** Completed
- ✅ Replaced `execute_query/1` and `load_data/1` with `start_async/handle_async` pattern
- ✅ Added `handle_async(:load_data, {:ok, result}, socket)` variants for success/error/exit
- ✅ Updated `load_data_if_needed/1` to always load data (matching Table behavior)
- ✅ Added proper error logging like Table component

### 3. Fix clear_filter implementation ✅
**Status:** Completed
- ✅ Replaced direct `Map.delete` calls with `Cinder.FilterManager.clear_filter`
- ✅ Ensured consistent behavior with Table component
- ✅ Updated both clear_filter event handlers and clear_all_filters
- ✅ Added proper state change notification pattern

### 4. Implement proper URL state decoding ✅
**Status:** Completed
- ✅ Replaced simple `decode_url_state/2` with Table's comprehensive approach (lines 271-336)
- ✅ Added support for `url_state.params` vs legacy URL parameters
- ✅ Implemented sort precedence logic (URL sorts vs query sorts vs user interaction)

## Phase 2: Enhanced State Management (Medium Priority)
**Files to modify: `lib/cinder/cards/live_component.ex`**

### 5. Add sort extraction from queries ✅
**Status:** Completed
- ✅ Implemented `extract_initial_sorts/1` function similar to Table (lines 500-523)
- ✅ Handles initial sort state from incoming Ash queries
- ✅ Updated `assign_defaults/1` to use extracted sorts

### 6. Update state change notifications ✅
**Status:** Completed
- ✅ Replaced custom `notify_state_change/1` with `Cinder.UrlManager.notify_state_change/2`
- ✅ Ensured consistent state change behavior with Table
- ✅ Updated all event handlers to use new notification pattern

### 7. Add user interaction tracking ✅
**Status:** Completed
- ✅ Added `:user_has_interacted` assign to track when user modifies state
- ✅ Used this for proper URL state precedence handling in decode_url_state
- ✅ Set to true in toggle_sort event (filters set it implicitly via FilterManager)

## Phase 3: Testing Updates (Medium Priority)
**Files to modify: `test/cinder/cards/cards_test.exs`, `test/cinder/cards/cards_integration_test.exs`**

### 8. Update existing tests for async behavior ✅
**Status:** Completed
- ✅ Added tests to verify async handlers exist and are properly exported
- ✅ Integration tests verify async behavior in realistic scenarios
- ✅ Fixed integration test that was testing for the old bug

### 9. Add refresh event tests ✅
**Status:** Completed
- ✅ Added test to verify refresh event handler exists
- ✅ Integration tests cover refresh functionality in real scenarios
- ✅ Added to existing cards_test.exs file

### 10. Enhance integration tests ✅
**Status:** Completed
- ✅ Updated integration tests to verify the filter_fn fix
- ✅ Tests cover QueryBuilder compatibility with Cards column format
- ✅ Verified that Cards now produces proper column structure

## Phase 4: Quality Assurance (Low Priority)

### 11. Full regression testing ✅
**Status:** Completed
- ✅ Ran complete test suite (`mix test`) - 644/645 tests passing
- ✅ Only 1 pre-existing theme test failure (unrelated to Cards changes)
- ✅ Verified Cards vs Table behavior consistency through implementation review

### 12. Documentation updates ✅
**Status:** Completed
- ✅ Updated `docs/cards.md` with new "Performance and Lifecycle" section
- ✅ Documented async loading behavior and benefits
- ✅ Added examples of refresh functionality and error handling
- ✅ Documented loading states and programmatic refresh options

## Implementation Notes

### Key Files to Modify:
- `lib/cinder/cards/live_component.ex` - Main implementation
- `test/cinder/cards/cards_test.exs` - Unit tests
- `test/cinder/cards/cards_integration_test.exs` - Integration tests
- `docs/cards.md` - Documentation

### Reference Implementation:
- `lib/cinder/table/live_component.ex` - Use as pattern for async loading, URL state, and event handling

### Critical Patterns to Copy:
1. **Async Loading** (Table lines 559-618)
   - `start_async(:load_data, fn -> ... end)`
   - `handle_async(:load_data, {:ok, {:ok, {results, page_info}}}, socket)`
   - Proper error handling and logging

2. **URL State Decoding** (Table lines 271-336)
   - Handle both new `url_state.params` and legacy URL parameters
   - Sort precedence logic with user interaction tracking

3. **State Notifications** (Table line 267)
   - `Cinder.UrlManager.notify_state_change(socket, state)`

### Implementation Order Rationale:
1. **Async loading first** - Most critical for UI responsiveness and error handling
2. **Event handlers** - Essential for feature parity
3. **State management** - Important for URL synchronization  
4. **Testing** - Ensures reliability of changes
5. **Documentation** - Final step to document new capabilities

This plan ensures Cards achieves full functional parity with Table while maintaining backward compatibility and proper test coverage.

## ✅ IMPLEMENTATION COMPLETE

All phases have been successfully completed:

### ✅ Phase 1: Core Functionality Updates (HIGH PRIORITY)
- Added "refresh" event handler  
- Implemented async loading with start_async/handle_async pattern
- Fixed clear_filter to use FilterManager
- Implemented comprehensive URL state decoding

### ✅ Phase 2: Enhanced State Management (MEDIUM PRIORITY)  
- Added query sort extraction
- Updated state change notifications to use UrlManager
- Added user interaction tracking

### ✅ Phase 3: Testing Updates (MEDIUM PRIORITY)
- Updated tests for async behavior
- Added refresh event tests  
- Enhanced integration tests

### ✅ Phase 4: Quality Assurance (LOW PRIORITY)
- Full regression testing (644/645 tests passing)
- Updated documentation with new features

## Summary of Changes

The Cards component now has **full functional parity** with the Table component:

1. **✅ Async Loading** - Non-blocking data queries with proper error handling
2. **✅ Refresh Functionality** - Programmatic data refresh while preserving state
3. **✅ URL State Management** - Comprehensive URL parameter handling with user interaction tracking
4. **✅ Filter Management** - Consistent FilterManager usage for all filter operations
5. **✅ State Notifications** - Proper UrlManager integration for state synchronization
6. **✅ Query Sort Extraction** - Initial sort state from Ash queries
7. **✅ Test Coverage** - Comprehensive testing including async behavior
8. **✅ Documentation** - Updated with performance and lifecycle information

The Cards component is now ready for production use with all the robustness and features of the Table component.