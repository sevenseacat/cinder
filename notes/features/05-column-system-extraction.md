# Feature 05: Column System Extraction

## Plan

### Overview
Extract column configuration and type inference logic from the main table component into a dedicated `Column` module. This will create a smart column system that can automatically infer filter types, sort capabilities, and display options from Ash resource definitions.

### Goals
1. **Reduce main component complexity** by ~150 lines
2. **Create intelligent column parsing** that infers types from Ash resources
3. **Support relationship fields** using dot notation (e.g., `user.name`)
4. **Centralize column logic** for easier maintenance and testing
5. **Maintain backward compatibility** with existing column configurations

### Implementation Steps

#### Step 1: Create Column Module Structure
- Create `lib/cinder/column.ex` with core column parsing logic
- Define column struct with all necessary fields
- Implement column validation and normalization

#### Step 2: Extract Column Processing Logic
- Move column definition logic from main component
- Extract column parsing and merging functionality
- Create clean interface for column operations

#### Step 3: Add Ash Resource Type Inference
- Implement automatic filter type detection from Ash attributes
- Add support for common Ash field types (string, integer, boolean, enum, etc.)
- Handle Ash constraints and validations

#### Step 4: Support Relationship Fields
- Add dot notation support for relationship traversal
- Implement relationship field validation
- Handle nested field type inference

#### Step 5: Update Main Component
- Replace inline column logic with Column module calls
- Maintain existing API compatibility
- Update tests to use new column system

### Technical Details

#### Column Module Interface
```elixir
defmodule Cinder.Column do
  @doc "Parse and normalize column definitions"
  def parse_columns(columns, resource) :: [Column.t()]
  
  @doc "Infer column configuration from Ash resource"
  def infer_from_resource(resource, field_key) :: map()
  
  @doc "Validate column configuration"
  def validate(column) :: {:ok, Column.t()} | {:error, term()}
  
  @doc "Merge slot configuration with inferred defaults"
  def merge_config(slot, inferred) :: map()
end
```

#### Column Struct
```elixir
defstruct [
  :key,           # Field key (string)
  :label,         # Display label
  :sortable,      # Boolean
  :filterable,    # Boolean
  :filter_type,   # Atom (:text, :select, etc.)
  :filter_options,# Keyword list
  :class,         # CSS classes
  :slot,          # Original slot data
  :relationship,  # Relationship info for dot notation
  :display_field, # Field to display (for relationships)
  :sort_fn,       # Custom sort function
  :filter_fn,     # Custom filter function
  :search_fn      # Custom search function
]
```

#### Type Inference Logic
- **String fields** → `:text` filter
- **Integer/Float fields** → `:number_range` filter  
- **Boolean fields** → `:boolean` filter
- **Enum fields** → `:select` filter with options
- **Date/DateTime fields** → `:date_range` filter
- **Association fields** → Infer from target field type

#### Relationship Support
- Parse `"user.name"` → `%{key: "user.name", relationship: "user", field: "name"}`
- Validate relationship exists in Ash resource
- Infer type from target field in related resource
- Handle nested relationships (`"user.profile.avatar.url"`)

### Testing Plan

#### Automated Tests
1. **Column Parsing Tests**
   - Basic column creation and validation
   - Slot configuration merging
   - Error handling for invalid configurations

2. **Ash Resource Integration Tests**
   - Type inference for various Ash field types
   - Enum detection and option extraction
   - Constraint handling (min/max, length, etc.)

3. **Relationship Field Tests**
   - Dot notation parsing
   - Relationship validation
   - Nested relationship support
   - Type inference through relationships

4. **Regression Tests**
   - All existing column functionality preserved
   - Backward compatibility with current API
   - Performance impact testing

#### Manual Tests
1. **Column Rendering Verification**
   - Headers display correctly
   - Sorting indicators work
   - Filter inputs render properly

2. **Type Inference Validation**
   - Create table with various Ash field types
   - Verify automatic filter type detection
   - Test enum field option extraction

3. **Relationship Field Testing**
   - Use dot notation fields in real table
   - Verify sorting works through relationships
   - Test filtering on related fields

### Expected Outcomes

#### Code Reduction
- **Main component**: Reduce from ~1,092 to ~942 lines (-150 lines)
- **New Column module**: ~150 lines
- **Net effect**: Same total lines but better organization

#### Feature Improvements
- **Automatic type inference** reduces manual configuration
- **Relationship support** enables more flexible table designs
- **Better error handling** for invalid column configurations
- **Consistent column behavior** across all tables

#### API Enhancements
- **Simplified column slots** with automatic inference
- **Better developer experience** with less boilerplate
- **Clear error messages** for configuration issues
- **Extensible architecture** for future column types

### Backward Compatibility
- All existing column configurations continue to work
- No breaking changes to public API
- Gradual adoption of new features possible
- Clear migration path for enhanced features

### Risks and Mitigations

#### Risk: Type Inference Errors
- **Mitigation**: Comprehensive test suite for all Ash field types
- **Fallback**: Default to text filter if inference fails
- **Validation**: Clear error messages for unsupported types

#### Risk: Relationship Performance
- **Mitigation**: Validate relationships at compile time when possible
- **Optimization**: Cache relationship metadata
- **Monitoring**: Add performance tests for complex relationships

#### Risk: Breaking Changes
- **Mitigation**: Maintain full backward compatibility
- **Testing**: Extensive regression test suite
- **Documentation**: Clear migration guide for new features

### Success Criteria
- [ ] Main component reduced by 150 lines
- [ ] All existing column functionality preserved
- [ ] Automatic type inference works for common Ash types
- [ ] Relationship fields work with dot notation
- [ ] Comprehensive test coverage (>95%)
- [ ] No performance regressions
- [ ] Zero breaking changes to existing API

## Testing Plan

### Manual Testing
1. **Column Configuration Testing**
   - Create tables with various column types
   - Verify headers, sorting, filtering work correctly
   - Test relationship fields with dot notation

2. **Ash Resource Integration**
   - Test with different Ash resource types
   - Verify automatic filter type detection
   - Test enum field option extraction

3. **Edge Case Testing**
   - Invalid relationship paths
   - Unsupported field types
   - Complex nested relationships

### Automated Testing
1. **Unit Tests**: Column parsing, validation, type inference
2. **Integration Tests**: Ash resource integration, relationship handling
3. **Regression Tests**: Existing functionality preservation
4. **Performance Tests**: No significant slowdown

## Log

*Implementation notes and findings will be recorded here during development*

## Conclusion

*Final implementation summary and lessons learned will be documented here upon completion*