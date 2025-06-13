# Table Query Error Logging

## Issue

When running queries in the Cinder table component, if something goes wrong (like an error in a calculation, invalid filter, or other Ash query issue), the table silently fails and shows no data. Developers get no feedback about what went wrong, making debugging very difficult.

**Current behavior:**
- Query errors result in empty table display
- Only a flash message is shown (which may not be visible during development)
- No console logging to help developers identify the root cause
- Especially problematic with calculation errors that raise exceptions

**Expected behavior:**
- Clear error logging to console/logs when queries fail
- Maintain current UX (don't break the table UI)
- Provide actionable error information for developers

## Root Cause Analysis

The error handling exists but is insufficient for development debugging:

1. **QueryBuilder.build_and_execute/2** - Has try/rescue that returns `{:error, error}` 
2. **LiveComponent.handle_async/3** - Handles error cases but only shows flash message
3. **No console logging** - Errors are caught but not logged for developer visibility

## Current Error Flow

```
Query Error → QueryBuilder.build_and_execute → {:error, error} → 
LiveComponent.handle_async → Flash message + empty table display
```

## Fix

**Root Cause Discovery**: The `put_flash/3` calls in LiveComponent were being silently ignored because LiveComponents cannot set flash messages - only LiveViews can. This is why no error feedback was visible.

**Solution**: Replace ineffective flash messages with proper console logging while maintaining current UX behavior:

1. **Add Logger calls** in both QueryBuilder and LiveComponent when errors occur
2. **Include error context** (resource, filters, sorting, page, query_opts, etc.) 
3. **Log at appropriate level** (warning for count failures, error for query failures)
4. **Preserve existing behavior** (empty table display)
3. **Added comprehensive error details** including actual error messages, resource names, and stacktraces for exceptions

**Changes Made**:

1. **QueryBuilder.build_and_execute/2**:
   - Added `require Logger`
   - Log query execution errors with full context
   - Log exceptions (calculation errors) with stacktrace
   - Log count query failures as warnings (non-fatal)
   - Fixed deprecated `Logger.warn` → `Logger.warning`

2. **LiveComponent async handlers**:
   - Added `require Logger` 
   - Replaced `put_flash/3` calls with `Logger.error/2`
   - Include table state context and actual error details in error logs
   - Preserve existing UX (empty table + loading state management)

3. **Added test coverage**:
   - Test verifies error logging works correctly
   - Captures log output to ensure proper error reporting
   - All existing tests continue to pass

## Testing Plan

### Manual Testing
1. Create table with calculation that raises error
2. Verify error is logged to console
3. Confirm table still shows empty state gracefully
4. Test various error scenarios (invalid filters, bad sorts, etc.)

### Automated Testing
1. ✅ Added test that captures log output during query errors
2. ✅ Verified error logging includes "Cinder table query crashed with exception"
3. ✅ Test different types of query failures (exception handling)
4. ✅ Ensured existing error handling behavior is preserved (275 tests passing)

## Conclusion

**Problem Solved**: Developers now get clear error logging when Cinder table queries fail, instead of silent failures that only show "No results found".

**Key Improvements**:
- **Visible Error Feedback**: Console logs now show detailed error information including actual error messages when queries fail
- **Rich Context**: Error logs include resource name, filters, sorting, pagination, and query options
- **Exception Details**: Calculation errors and other exceptions include full stacktraces and specific error messages
- **Immediate Identification**: Resource name and error type are shown directly in log message for quick debugging
- **Preserved UX**: Tables still show empty state gracefully without breaking UI
- **Backward Compatible**: All existing functionality preserved (275 tests passing)

**Error Log Examples**:
```
[error] Cinder table query execution failed for MyApp.User: %Ash.Error.Query.InvalidFilterValue{message: "Invalid filter value"}
[error] Cinder table query crashed with exception for MyApp.Album: %ArgumentError{message: "Could not determine domain for query"}  
[warning] Cinder table count query failed: %Ash.Error.Query.NotFound{} - falling back to basic pagination for MyApp.Product
```

**Developer Experience**: 
- Calculation errors are now immediately visible in console with specific error messages
- Filter/sort issues are clearly logged with context and actual error details
- Resource name and error type shown directly in log message
- No more guessing why tables are empty - exact error cause is displayed
- Debugging time significantly reduced with actionable error information

**Production Impact**: Minimal - only adds logging, no behavioral changes to end users.