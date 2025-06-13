# Fix 004: URL Filter Restoration Issue

## Issue

URL filter parameters are not being properly restored on page load for relationship filters (e.g., `http://localhost:4000/table?artist.name=Z` doesn't apply the artist name filter).

## Root Cause

The issue is in the URL state extraction process:

1. **Parent LiveView**: Uses `Cinder.Table.UrlSync.extract_table_state(params)` to decode URL parameters
2. **Empty Columns Problem**: `extract_table_state/1` passes an empty list for columns (`columns = []`)
3. **Filter Decoding Failure**: `UrlManager.decode_filters/2` requires column metadata to properly decode filters:
   ```elixir
   column = Enum.find(columns, &(&1.key == string_key))
   if column && column.filterable && value != "" do
     # Decode filter - but this never executes with empty columns list
   ```
4. **Result**: All URL filters are ignored because no matching columns are found

### Current Flow (Broken)
```
URL params → extract_table_state(params) → decode_state(params, []) → decode_filters(params, []) → {} (empty filters)
```

### Fixed Flow
```
URL params → extract_table_state(params) → decode_state(params, columns) → decode_filters(params, columns) → proper filters
```

## Fix

The solution preserves raw URL parameters and passes them to the component where they can be decoded with actual column information:

### 1. Updated `UrlSync.handle_params/3`
- Added `:table_raw_url_params` assign to preserve original URL parameters
- Component can now access raw params for proper filter decoding

### 2. Updated `Table.table/1`
- Added `url_raw_params` attribute to pass raw params to LiveComponent
- Added helper function `get_raw_url_params/2` to extract raw params when URL sync is enabled

### 3. Updated `LiveComponent.decode_url_state/2`
- Checks for raw URL params first (preferred method)
- Uses raw params with actual columns for proper filter decoding
- Falls back to old method for backward compatibility

## Technical Details

### Files Changed
- `lib/cinder/table/url_sync.ex`: Added raw params preservation
- `lib/cinder/table.ex`: Added raw params passing to component
- `lib/cinder/table/live_component.ex`: Updated filter decoding logic

### Key Changes
```elixir
# In UrlSync.handle_params/3
socket
|> assign(:table_url_filters, table_state.filters)
|> assign(:table_url_page, table_state.current_page)
|> assign(:table_url_sort, table_state.sort_by)
|> assign(:table_current_uri, uri)
# NEW: Store raw params for proper filter decoding by component
|> assign(:table_raw_url_params, params)

# In LiveComponent.decode_url_state/2
raw_params = Map.get(assigns, :url_raw_params, %{})

if not Enum.empty?(raw_params) do
  # Use raw params with actual columns for proper filter decoding
  decoded_state = Cinder.UrlManager.decode_state(raw_params, socket.assigns.columns)
  # ... assign decoded state
```

## Testing

Added comprehensive test suite in `test/cinder/url_state_restoration_test.exs`:

- **9 new tests** covering URL state extraction, restoration, and encoding/decoding
- **Verified the bug**: Test proves `extract_table_state` loses filter information
- **Verified the fix**: Test confirms raw params preserve filter data
- **Relationship filters**: Comprehensive testing for all relationship filter types
- **Roundtrip testing**: Ensures encode → decode cycles work correctly

### Key Test Results
- ✅ Demonstrates the broken flow (filters lost due to empty columns)
- ✅ Verifies the fix works (raw params preserve filter data)
- ✅ Tests all relationship filter types (text, select, boolean, range)
- ✅ Ensures backward compatibility with existing functionality

## Validation

### Manual Testing
1. Visit URL with relationship filters: `http://localhost:4000/table?artist.name=Beatles`
2. ✅ Filter should now be properly applied on page load
3. ✅ Other URL state (pagination, sorting) continues to work
4. ✅ Filter changes update URL correctly

### Automated Testing
- **249 tests pass** (including 9 new URL restoration tests)
- **0 failures** - no regression in existing functionality
- **Comprehensive coverage** for URL state management

## Why This Wasn't Caught Earlier

1. **Missing URL Integration Tests**: Most tests focused on component functionality, not URL state restoration
2. **Complex Multi-Step Flow**: The bug occurs across multiple components (parent LiveView → UrlSync → component)
3. **Deferred Column Access**: The issue only manifests when columns aren't available during initial URL parsing
4. **Working Partial Features**: Page and sort restoration worked, masking the filter issue

## Prevention

1. **Comprehensive URL Testing**: Added full URL state restoration test suite
2. **Integration Test Coverage**: Tests now cover the complete parent → component → URL flow
3. **Raw Data Preservation**: Architecture now preserves raw data until proper context is available
4. **Backward Compatibility**: Fix maintains existing API while adding new functionality

## Conclusion

This fix resolves the critical URL filter restoration issue while maintaining backward compatibility. The solution preserves the original URL parameters until they can be properly decoded with column context, ensuring all filter types (including relationship filters) are correctly restored from URLs.

**Impact**: Users can now bookmark and share URLs with relationship filters, and page refreshes preserve all filter state correctly.