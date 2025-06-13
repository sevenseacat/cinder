# Fix 1: Missing Field Attribute Validation

## Issue

Users can define table columns without a `field` attribute, which causes confusing behavior:

1. The column appears in the table but has no filtering/sorting functionality
2. Filter configurations like `filter={:boolean}` are silently ignored
3. The column gets `key: nil` internally, breaking filter form field naming
4. Users get cryptic errors like `FunctionClauseError` in `ensure_multiselect_fields/2`

**Root Cause**: The column parser looks for `:key` instead of `:field`, and doesn't validate that the field attribute is present.

**Current API Documentation** shows:
```elixir
<:col :let="user" field="name" filter sort>{user.name}</:col>
```

**But Implementation** looks for:
```elixir
key = Map.get(slot, :key)  # Should be :field
```

## Fix

### 1. Update Column Parser
- Change `Map.get(slot, :key)` to `Map.get(slot, :field)` in `Cinder.Column.parse_column/2`
- Add validation to ensure `field` attribute is present and non-empty
- Provide helpful error message when field is missing

### 2. Validation Rules
- Field attribute must be present
- Field attribute must be a non-empty string
- Error should be clear and actionable

### 3. Error Message
When field is missing, show:
```
Cinder table column is missing required 'field' attribute. 
Use: <:col field="column_name" ...>
```

### 4. Backward Compatibility
- Check if this is a breaking change (likely yes, but fixing incorrect behavior)
- Update any internal code that might still use `:key`

## Testing Plan

### Unit Tests
1. Test column parsing with missing field attribute throws helpful error
2. Test column parsing with empty field attribute throws error  
3. Test column parsing with valid field attribute works correctly
4. Test that filter configuration works properly with field attribute

### Integration Tests
1. Test complete table rendering with properly configured columns
2. Test that filter form fields get correct names with field attribute
3. Test that the original user's boolean filter case works after fix

## Implementation Steps

1. Update `Cinder.Column.parse_column/2` to use `:field` instead of `:key`
2. Add field validation with clear error messages
3. Update tests to cover the validation
4. Test with user's original table configuration
5. Update any documentation that might reference the old behavior

## Expected Outcome

After this fix:
- Users get immediate, clear feedback when they forget the `field` attribute
- All filter types work correctly when properly configured
- Form field naming works correctly (`filters[field_name]` instead of `filters[]`)
- No more cryptic `FunctionClauseError` messages