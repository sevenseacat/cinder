# Feature 004: Modular Filter System

## Plan

Create individual filter type modules to support expansion and better maintainability. This replaces the current monolithic FilterManager with a modular architecture where each filter type is its own module.

### Current State
- FilterManager: 773 lines with mixed concerns
- All filter types in one file
- Hard to add new filter types
- UI, processing, and Ash integration all mixed together

### Target Architecture

```
lib/cinder/filters/
├── base.ex                    # Filter behavior and shared types
├── registry.ex               # Filter type registration and discovery
├── text.ex                   # Text filter implementation
├── select.ex                 # Select dropdown filter
├── multi_select.ex           # Multi-select checkbox filter
├── date_range.ex             # Date range picker
├── number_range.ex           # Number range inputs
├── boolean.ex                # Boolean radio buttons
└── components.ex             # Shared UI components
```

### Implementation Steps

1. **Create Base Module** (`lib/cinder/filters/base.ex`)
   - Define Filter behavior with callbacks
   - Shared types and utilities
   - Common validation functions

2. **Create Registry** (`lib/cinder/filters/registry.ex`)
   - Register all available filter types
   - Dynamic filter type discovery
   - Default filter type inference

3. **Extract Individual Filter Types**
   - Move each filter implementation to its own module
   - Each module implements the Filter behavior
   - Include render/3, process/2, validate/1 functions

4. **Create Shared Components** (`lib/cinder/filters/components.ex`)
   - Common UI elements (labels, clear buttons, etc.)
   - Shared styling helpers
   - Form integration utilities

5. **Update FilterManager** 
   - Become a coordinator/facade
   - Delegate to individual filter modules
   - Maintain backward compatibility

6. **Update LiveComponent**
   - Use new filter system
   - Remove old filter code
   - Test integration

### Filter Module Interface

Each filter module will implement:

```elixir
defmodule Cinder.Filters.Text do
  @behaviour Cinder.Filters.Base
  
  def render(column, current_value, theme)
  def process(value, column)  
  def validate(value)
  def default_options()
end
```

### Benefits

- **Extensibility**: Easy to add new filter types (e.g. autocomplete, tag, color picker)
- **Maintainability**: Each filter type is isolated and testable
- **Consistency**: All filters implement same interface
- **Performance**: Can lazy-load filter types as needed
- **Customization**: Users can create custom filter types

### Backward Compatibility

- FilterManager maintains same public API
- Existing filter configurations continue working
- Gradual migration path for custom filters

## Testing Plan

### Manual Testing
1. **Visual Testing**: All existing filter types render correctly
2. **Interaction Testing**: Each filter type processes input correctly
3. **Form Integration**: Filters work within form context
4. **State Management**: Filter values persist correctly

### Automated Tests
1. **Base Module Tests**: Filter behavior and shared utilities
2. **Registry Tests**: Filter type registration and discovery
3. **Individual Filter Tests**: Each filter module (render, process, validate)
4. **Integration Tests**: FilterManager coordination
5. **Migration Tests**: Backward compatibility verification

### Performance Testing
1. **Loading**: Filter modules lazy-load correctly
2. **Rendering**: No performance regression in UI
3. **Processing**: Filter value processing remains fast

## Log

### 2024-12-19 - Plan Created
- Analyzed current FilterManager structure (773 lines)
- Identified need for modular architecture to support expansion
- Designed Filter behavior interface
- Planned registry system for dynamic filter discovery
- Outlined implementation steps with backward compatibility

### 2024-12-19 - Implementation Completed
- ✅ Created base filter behavior (`lib/cinder/filters/base.ex`) with shared types and utilities
- ✅ Implemented filter registry (`lib/cinder/filters/registry.ex`) for type management and inference
- ✅ Created individual filter modules:
  - Text filter (`lib/cinder/filters/text.ex`) - 86 lines
  - Select filter (`lib/cinder/filters/select.ex`) - 89 lines  
  - Multi-select filter (`lib/cinder/filters/multi_select.ex`) - 90 lines
  - Date range filter (`lib/cinder/filters/date_range.ex`) - 143 lines
  - Number range filter (`lib/cinder/filters/number_range.ex`) - 148 lines
  - Boolean filter (`lib/cinder/filters/boolean.ex`) - 129 lines
- ✅ Refactored FilterManager to act as coordinator (reduced from 773 to 373 lines)
- ✅ All individual filter modules implement the Filter behavior interface
- ✅ Maintained full backward compatibility - all existing tests pass
- ✅ Fixed theme class name mismatches and render function signatures
- ✅ Added clear filter buttons to individual inputs
- ✅ Corrected boolean filter default labels

### Results
- **Total Lines Reduced**: FilterManager reduced by 400 lines (773 → 373)
- **New Modules Created**: 7 new focused modules (~785 lines total)
- **Architecture**: Modular system ready for easy expansion with new filter types
- **Test Coverage**: All 184 tests passing with zero warnings
- **Extensibility**: Simple to add new filter types by implementing the behavior
- **Maintainability**: Each filter type isolated and independently testable

## Conclusion

Phase 4 successfully completed the modular filter system refactoring. The monolithic FilterManager has been transformed into a clean, extensible architecture:

**Key Achievements:**
- **Modular Design**: Each filter type is now in its own focused module
- **Consistent Interface**: All filters implement the same behavior with `render/4`, `process/2`, `validate/1`, `empty?/1` functions
- **Easy Expansion**: Adding new filter types requires only implementing the behavior
- **Better Maintainability**: Individual filter logic is isolated and testable
- **Performance Ready**: Registry system supports lazy loading and dynamic filter discovery
- **Backward Compatible**: No breaking changes to existing API

**Architecture Benefits:**
- FilterManager reduced from 773 to 373 lines (48% reduction)
- Filter logic distributed across 6 specialized modules
- Clear separation of concerns (UI, processing, validation)
- Registry system for centralized filter type management
- Shared utilities in base module prevent code duplication

**Next Steps:**
This modular foundation makes it trivial to add new filter types like autocomplete, date pickers, color selectors, or custom business-specific filters. The system is now ready for Phase 5 (Column System extraction).