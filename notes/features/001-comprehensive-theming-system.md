# 001 - Comprehensive Theming System Enhancement

## Plan

### Overview
Enhance Cinder's theming system to provide complete styling control over every HTML element while introducing a modular, Spark DSL-based approach for theme definition. This will ensure 100% customization capability and improve developer experience.

### Current State Analysis
- Theme system covers ~80% of HTML elements but has gaps (checkbox styling, loading states, etc.)
- Boolean and multi-select filters use hardcoded CSS classes
- No modular theme definition system
- Limited reusability across projects
- Map-based theme configuration works but isn't extensible

### Goals
1. **Complete Coverage**: Every single HTML element has a dedicated theme class
2. **Modular Themes**: Spark DSL for defining reusable theme modules  
3. **Backwards Compatibility**: Existing map-based themes continue to work
4. **Developer Experience**: Better validation, error messages, and documentation
5. **Extensibility**: Theme inheritance and composition support

### Phase 1: Complete Theme Coverage
**Objective**: Audit and add theme classes for every missing HTML element

**Tasks**:
1. Audit all components for hardcoded CSS classes:
   - `Cinder.Filters.Boolean` - radio buttons, labels, containers
   - `Cinder.Filters.MultiSelect` - checkboxes, labels, containers  
   - `Cinder.Filters.DateRange` - input containers, labels
   - `Cinder.Filters.NumberRange` - input containers, labels
   - Loading indicators and states
   - Error message containers
   - Icon styling classes

2. Add missing theme keys to `Cinder.Theme.default/0`:
   - `filter_boolean_container_class`
   - `filter_boolean_option_class` 
   - `filter_boolean_radio_class`
   - `filter_boolean_label_class`
   - `filter_multiselect_container_class`
   - `filter_multiselect_option_class`
   - `filter_multiselect_checkbox_class`
   - `filter_multiselect_label_class`
   - `filter_range_container_class`
   - `filter_range_input_group_class`
   - `loading_overlay_class`
   - `loading_spinner_class`
   - `error_container_class`
   - `error_message_class`

3. Update all filter components to use theme classes instead of hardcoded CSS

4. Add comprehensive tests for all new theme keys

**Success Criteria**: Every HTML element in every component uses a theme class

### Phase 2: Spark DSL Implementation  
**Objective**: Create a Spark DSL for modular theme definition

**Tasks**:
1. Add Spark dependency and create DSL structure:
   ```elixir
   defmodule MyApp.CustomTheme do
     use Cinder.Theme
     
     override Cinder.Components.Table do
       set :container_class, "my-custom-table-container"
       set :row_class, "my-custom-row hover:bg-blue-50"
     end
     
     override Cinder.Components.Filters do
       set :container_class, "my-filter-container"
       set :text_input_class, "my-text-input"
     end
   end
   ```

2. Implement theme module behaviors:
   - `use Cinder.Theme` macro that imports DSL
   - `override/2` macro for component-specific overrides
   - `set/2` macro for setting individual properties
   - Theme resolution and merging logic

3. Create component-specific theme sections:
   - `Cinder.Components.Table` theme section
   - `Cinder.Components.Filters` theme section  
   - `Cinder.Components.Pagination` theme section
   - `Cinder.Components.Sorting` theme section

4. Maintain backwards compatibility with map-based themes

5. Add validation and helpful error messages

**Success Criteria**: Custom theme modules work alongside existing map-based themes

### Phase 3: Enhanced Theme Features
**Objective**: Add advanced theme capabilities and built-in themes

**Tasks**:
1. Theme inheritance support:
   ```elixir
   defmodule MyApp.DarkTheme do
     use Cinder.Theme
     extends Cinder.Theme.Modern
     
     override Cinder.Components.Table do
       set :container_class, "bg-gray-900 text-white"
       set :row_class, "border-gray-700 hover:bg-gray-800"
     end
   end
   ```

2. Create additional built-in themes:
   - `Cinder.Theme.Dark` - Dark mode theme
   - `Cinder.Theme.Compact` - High-density layout
   - `Cinder.Theme.Bootstrap` - Bootstrap-compatible classes
   - `Cinder.Theme.Tailwind` - Optimized Tailwind classes

3. Theme validation and introspection:
   - Validate theme completeness
   - Detect missing theme keys
   - Generate theme documentation
   - Theme preview/testing utilities

4. Enhanced theme resolution:
   - Support theme functions for dynamic values
   - Context-aware theming (responsive, dark mode)
   - Theme composition and merging strategies

**Success Criteria**: Rich theme ecosystem with validation and advanced features

### Phase 4: Testing and Documentation
**Objective**: Comprehensive testing and documentation

**Tasks**:
1. Test coverage for all theme features:
   - Every theme key renders correctly
   - DSL syntax validation
   - Theme inheritance works
   - Backwards compatibility maintained
   - Error handling and validation

2. Update documentation:
   - Complete theme reference
   - DSL syntax guide
   - Custom theme examples
   - Migration guide from current system
   - Built-in theme showcase

3. Developer tools:
   - Theme generator Mix task
   - Theme validation helpers
   - Documentation generation tools

4. Performance testing:
   - Theme resolution performance
   - Memory usage with large themes
   - Component rendering performance

**Success Criteria**: Complete documentation and test coverage

## Testing Plan

### Automated Tests
1. **Theme Coverage Tests**: Verify every HTML element has a theme class
2. **DSL Syntax Tests**: Test all DSL macros and combinations
3. **Theme Resolution Tests**: Test theme merging and inheritance  
4. **Backwards Compatibility Tests**: Ensure existing themes still work
5. **Integration Tests**: Test themes in actual table components
6. **Performance Tests**: Benchmark theme resolution performance

### Manual Testing
1. **Visual Testing**: Verify all built-in themes render correctly
2. **Custom Theme Testing**: Create and test custom theme modules
3. **Documentation Testing**: Follow documentation examples to ensure accuracy
4. **Migration Testing**: Migrate existing themes to new system

### Test Data
- Create comprehensive test themes covering all elements
- Test with various table configurations
- Test with different resource types and data
- Test responsive behavior and edge cases

## Log

[Implementation notes and findings will be documented here during development]

## Conclusion

[Final design decisions and architectural summary will be documented here upon completion]