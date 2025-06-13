# Cinder Theming System

Cinder provides a comprehensive theming system that allows complete visual customization of your tables. With 10 built-in themes and a powerful DSL for creating custom themes, you can match any design system or create unique visual experiences.

## Table of Contents

- [Quick Start](#quick-start)
- [Built-in Theme Presets](#built-in-theme-presets)
- [Custom Themes with DSL](#custom-themes-with-dsl)
- [Theme Inheritance](#theme-inheritance)
- [Developer Tools](#developer-tools)
- [Component Reference](#component-reference)
- [Real-World Examples](#real-world-examples)

## Quick Start

### Using Built-in Themes

The fastest way to style your table is with one of the 10 built-in themes:

```elixir
<Cinder.Table.table theme="modern" resource={MyApp.User} current_user={@current_user}>
  <:col field="name" filter sort>Name</:col>
  <:col field="email" filter>Email</:col>
</Cinder.Table.table>
```

### Custom Theme Module

Create reusable themes with the Cinder DSL:

```elixir
defmodule MyApp.CustomTheme do
  use Cinder.Theme

  component Cinder.Components.Table do
    set :container_class, "bg-white shadow-lg rounded-lg border"
    set :th_class, "px-6 py-4 bg-gray-50 font-semibold text-gray-900"
    set :row_class, "hover:bg-gray-50 transition-colors"
  end
end

# Use in your template
<Cinder.Table.table theme={MyApp.CustomTheme} resource={MyApp.User} current_user={@current_user}>
  <:col field="name" filter sort>Name</:col>
</Cinder.Table.table>
```

## Built-in Theme Presets

Cinder includes 10 carefully crafted themes covering a wide range of design styles:

### Core Themes

**Default** - Clean, minimal styling for universal compatibility
```elixir
<Cinder.Table.table theme="default" resource={MyApp.User} current_user={@current_user}>
```

**Modern** - Professional styling with shadows and improved spacing
```elixir
<Cinder.Table.table theme="modern" resource={MyApp.User} current_user={@current_user}>
```

**Dark** - Elegant dark theme with proper contrast
```elixir
<Cinder.Table.table theme="dark" resource={MyApp.User} current_user={@current_user}>
```

### Framework Integration Themes

**DaisyUI** - Optimized for DaisyUI component library
```elixir
<Cinder.Table.table theme="daisy_ui" resource={MyApp.User} current_user={@current_user}>
```

**Flowbite** - Designed for Flowbite design system
```elixir
<Cinder.Table.table theme="flowbite" resource={MyApp.User} current_user={@current_user}>
```

### Specialty Themes

**Retro** - Cyberpunk-inspired with bright accent colors
```elixir
<Cinder.Table.table theme="retro" resource={MyApp.User} current_user={@current_user}>
```

**Futuristic** - Sci-fi aesthetic with glowing effects
```elixir
<Cinder.Table.table theme="futuristic" resource={MyApp.User} current_user={@current_user}>
```

**Vintage** - Warm, classic styling with subtle textures
```elixir
<Cinder.Table.table theme="vintage" resource={MyApp.User} current_user={@current_user}>
```

**Compact** - High-density layout for data-heavy applications
```elixir
<Cinder.Table.table theme="compact" resource={MyApp.User} current_user={@current_user}>
```

**Pastel** - Soft, friendly colors for approachable interfaces
```elixir
<Cinder.Table.table theme="pastel" resource={MyApp.User} current_user={@current_user}>
```

## Custom Themes with DSL

Create powerful, maintainable themes using Cinder's DSL syntax:

### Basic Theme Structure

```elixir
defmodule MyApp.Theme.Corporate do
  use Cinder.Theme

  component Cinder.Components.Table do
    set :container_class, "bg-white shadow-lg rounded-lg border border-gray-200"
    set :th_class, "px-6 py-4 bg-blue-50 text-left font-semibold text-blue-900"
    set :td_class, "px-6 py-4 border-b border-gray-100 text-gray-900"
    set :row_class, "hover:bg-blue-50 transition-colors duration-150"
  end

  component Cinder.Components.Filters do
    set :container_class, "bg-blue-50 border border-blue-200 rounded-lg p-6 mb-6"
    set :title_class, "text-lg font-semibold text-blue-900 mb-4"
    set :text_input_class, "w-full px-4 py-3 border border-blue-300 rounded-lg focus:ring-2 focus:ring-blue-500"
  end

  component Cinder.Components.Pagination do
    set :button_class, "px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors"
    set :info_class, "text-blue-700 font-medium"
  end
end
```

### Component-Specific Customization

Customize only the components you need:

```elixir
defmodule MyApp.Theme.FilterFocused do
  use Cinder.Theme

  # Only customize filters, leave table and pagination with defaults
  component Cinder.Components.Filters do
    set :container_class, "bg-gradient-to-r from-purple-50 to-pink-50 border-2 border-purple-200 rounded-xl p-8 mb-8"
    set :title_class, "text-xl font-bold text-purple-900 mb-6"
    set :text_input_class, "w-full px-4 py-3 border-2 border-purple-300 rounded-lg focus:ring-4 focus:ring-purple-200"
    set :filter_boolean_container_class, "flex space-x-6 bg-white p-4 rounded-lg shadow-sm"
    set :filter_boolean_radio_class, "h-5 w-5 text-purple-600 focus:ring-purple-500"
  end
end
```

## Theme Inheritance

Build upon existing themes using the `extends` directive:

### Extending Built-in Themes

```elixir
defmodule MyApp.Theme.DarkModern do
  use Cinder.Theme
  extends :modern

  component Cinder.Components.Table do
    set :container_class, "bg-gray-900 shadow-xl rounded-lg border border-gray-700"
    set :th_class, "px-6 py-4 bg-gray-800 text-left font-semibold text-gray-100 border-b border-gray-700"
    set :td_class, "px-6 py-4 text-gray-200 border-b border-gray-700"
    set :row_class, "hover:bg-gray-800 transition-colors"
  end

  component Cinder.Components.Filters do
    set :container_class, "bg-gray-800 border border-gray-700 rounded-lg p-6 mb-6"
    set :title_class, "text-sm font-medium text-gray-200"
    set :filter_text_input_class, "w-full px-3 py-2 bg-gray-700 border border-gray-600 rounded-md text-gray-200 focus:ring-2 focus:ring-blue-500"
  end
end
```

### Extending Custom Themes

```elixir
defmodule MyApp.Theme.CorporateCompact do
  use Cinder.Theme
  extends MyApp.Theme.Corporate

  # Make the corporate theme more compact
  component Cinder.Components.Table do
    set :th_class, "px-4 py-2 bg-blue-50 text-left font-semibold text-blue-900 border-b border-blue-200"
    set :td_class, "px-4 py-2 border-b border-gray-100 text-gray-900"
  end

  component Cinder.Components.Filters do
    set :container_class, "bg-blue-50 border border-blue-200 rounded-lg p-4 mb-4"
  end
end
```

## Developer Tools

Cinder includes built-in developer tools to make theme creation effortless:

### Data Attributes

Every themed element includes a `data-key` attribute identifying which theme property controls it:

```html
<div class="bg-white shadow-lg rounded-lg" data-key="container_class">
  <table class="w-full border-collapse" data-key="table_class">
    <thead class="bg-gray-50" data-key="thead_class">
      <tr class="border-b" data-key="header_row_class">
        <th class="px-6 py-4 font-semibold" data-key="th_class">Name</th>
      </tr>
    </thead>
  </table>
</div>
```

### Using Browser Dev Tools

1. **Inspect any element** in your table
2. **Look for the `data-key` attribute** to see which theme property controls it
3. **Update your theme** with the identified property name
4. **See changes immediately** without guessing

Example workflow:
```bash
# 1. Inspect element in browser
<input data-key="filter_text_input_class" class="w-full px-3 py-2 border">

# 2. Update your theme
component Cinder.Components.Filters do
  set :filter_text_input_class, "w-full px-4 py-3 border-2 border-blue-500 rounded-lg"
end

# 3. Refresh to see changes
```

## Component Reference

Cinder organizes theme properties by logical components:

### Table Component
Controls the main table structure:

```elixir
component Cinder.Components.Table do
  set :container_class, "..."           # Outer container
  set :controls_class, "..."            # Controls section
  set :table_wrapper_class, "..."       # Scrollable wrapper
  set :table_class, "..."               # Table element
  set :thead_class, "..."               # Table header
  set :tbody_class, "..."               # Table body
  set :header_row_class, "..."          # Header row
  set :row_class, "..."                 # Data rows
  set :th_class, "..."                  # Header cells
  set :td_class, "..."                  # Data cells
  set :loading_class, "..."             # Loading state
  set :empty_class, "..."               # Empty state
  set :error_container_class, "..."     # Error container
  set :error_message_class, "..."       # Error message
end
```

### Filters Component
Controls all filter-related styling:

```elixir
component Cinder.Components.Filters do
  # Container structure
  set :filter_container_class, "..."
  set :filter_header_class, "..."
  set :filter_title_class, "..."
  set :filter_count_class, "..."
  set :filter_clear_all_class, "..."
  set :filter_inputs_class, "..."
  set :filter_input_wrapper_class, "..."
  set :filter_label_class, "..."
  set :filter_placeholder_class, "..."
  set :filter_clear_button_class, "..."
  
  # Input types
  set :filter_text_input_class, "..."
  set :filter_select_input_class, "..."
  set :filter_date_input_class, "..."
  set :filter_number_input_class, "..."
  
  # Boolean filters
  set :filter_boolean_container_class, "..."
  set :filter_boolean_option_class, "..."
  set :filter_boolean_radio_class, "..."
  set :filter_boolean_label_class, "..."
  
  # Multi-select filters (dropdown interface)
  set :filter_multiselect_container_class, "..."
  set :filter_multiselect_dropdown_class, "..."
  set :filter_multiselect_option_class, "..."
  set :filter_multiselect_checkbox_class, "..."
  set :filter_multiselect_label_class, "..."
  set :filter_multiselect_empty_class, "..."
  
  # Multi-checkboxes filters (traditional interface)
  set :filter_multicheckboxes_container_class, "..."
  set :filter_multicheckboxes_option_class, "..."
  set :filter_multicheckboxes_checkbox_class, "..."
  set :filter_multicheckboxes_label_class, "..."
  
  # Range filters
  set :filter_range_container_class, "..."
  set :filter_range_input_group_class, "..."
end
```

### Pagination Component
Controls pagination styling:

```elixir
component Cinder.Components.Pagination do
  set :pagination_wrapper_class, "..."    # Outer wrapper
  set :pagination_container_class, "..."  # Inner container
  set :pagination_info_class, "..."       # Page info ("Page 1 of 10")
  set :pagination_nav_class, "..."        # Navigation section
  set :pagination_button_class, "..."     # Navigation buttons
  set :pagination_current_class, "..."    # Current page indicator
  set :pagination_count_class, "..."      # Record count
end
```

### Sorting Component
Controls sort indicators and icons:

```elixir
component Cinder.Components.Sorting do
  set :sort_indicator_class, "..."         # Sort indicator wrapper
  set :sort_arrow_wrapper_class, "..."     # Icon wrapper
  set :sort_asc_icon_class, "..."          # Ascending icon
  set :sort_asc_icon_name, "hero-chevron-up"     # Icon name
  set :sort_desc_icon_class, "..."         # Descending icon
  set :sort_desc_icon_name, "hero-chevron-down"  # Icon name
  set :sort_none_icon_class, "..."         # Unsorted icon
  set :sort_none_icon_name, "hero-chevron-up-down"  # Icon name
end
```

### Loading Component
Controls loading states:

```elixir
component Cinder.Components.Loading do
  set :loading_overlay_class, "..."        # Loading overlay
  set :loading_container_class, "..."      # Loading container
  set :loading_class, "..."                # Loading text
  set :loading_spinner_class, "..."        # Spinner element
  set :loading_spinner_circle_class, "..." # Spinner circle
  set :loading_spinner_path_class, "..."   # Spinner path
end
```

## Real-World Examples

### E-commerce Admin Theme

```elixir
defmodule MyApp.Theme.EcommerceAdmin do
  use Cinder.Theme
  extends :modern

  component Cinder.Components.Table do
    set :container_class, "bg-white shadow-sm rounded-lg border border-gray-200"
    set :th_class, "px-6 py-4 bg-green-50 text-left font-semibold text-green-900 border-b border-green-200"
    set :row_class, "hover:bg-green-50 transition-colors border-b border-gray-100"
  end

  component Cinder.Components.Filters do
    set :filter_container_class, "bg-green-50 border border-green-200 rounded-lg p-6 mb-6"
    set :filter_title_class, "text-lg font-semibold text-green-900"
    set :filter_text_input_class, "w-full px-3 py-2 border border-green-300 rounded-md focus:ring-2 focus:ring-green-500 focus:border-green-500"
  end

  component Cinder.Components.Pagination do
    set :pagination_button_class, "px-4 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700 transition-colors"
    set :pagination_info_class, "text-green-700 font-medium"
  end
end
```

### Dashboard Analytics Theme

```elixir
defmodule MyApp.Theme.Analytics do
  use Cinder.Theme

  component Cinder.Components.Table do
    set :container_class, "bg-slate-900 shadow-xl rounded-lg border border-slate-700"
    set :th_class, "px-6 py-4 bg-slate-800 text-left font-semibold text-slate-100 border-b border-slate-600"
    set :td_class, "px-6 py-4 text-slate-200 border-b border-slate-700"
    set :row_class, "hover:bg-slate-800 transition-colors"
  end

  component Cinder.Components.Filters do
    set :filter_container_class, "bg-slate-800 border border-slate-600 rounded-lg p-6 mb-6"
    set :filter_title_class, "text-lg font-semibold text-slate-100 mb-4"
    set :filter_text_input_class, "w-full px-3 py-2 bg-slate-700 border border-slate-600 rounded-md text-slate-200 focus:ring-2 focus:ring-blue-500"
  end

  component Cinder.Components.Loading do
    set :loading_container_class, "flex items-center text-sm text-blue-400 font-medium"
    set :loading_spinner_class, "animate-spin -ml-1 mr-2 h-4 w-4 text-blue-400"
  end
end
```

### Mobile-Optimized Theme

```elixir
defmodule MyApp.Theme.Mobile do
  use Cinder.Theme
  extends :default

  component Cinder.Components.Table do
    set :container_class, "bg-white rounded-lg shadow-sm border border-gray-200"
    set :table_wrapper_class, "overflow-x-auto -mx-4 sm:mx-0"
    set :th_class, "px-3 py-2 text-xs font-semibold text-gray-900 uppercase tracking-wider"
    set :td_class, "px-3 py-2 text-sm text-gray-700"
  end

  component Cinder.Components.Filters do
    set :filter_inputs_class, "space-y-4"  # Stack filters vertically on mobile
    set :filter_container_class, "bg-gray-50 rounded-lg p-4 mb-4"
    set :filter_text_input_class, "w-full px-3 py-2 text-base border border-gray-300 rounded-lg"  # Larger touch targets
  end

  component Cinder.Components.Pagination do
    set :pagination_container_class, "flex flex-col space-y-2 sm:flex-row sm:items-center sm:justify-between sm:space-y-0"
    set :pagination_button_class, "px-3 py-2 text-sm border border-gray-300 rounded-lg hover:bg-gray-50"
  end
end
```

### Comprehensive Enterprise Theme

```elixir
defmodule MyApp.Theme.Enterprise do
  use Cinder.Theme

  component Cinder.Components.Table do
    set :container_class, "bg-white shadow-lg rounded-xl border border-gray-200 overflow-hidden"
    set :controls_class, "bg-gray-50 px-6 py-4 border-b border-gray-200"
    set :table_wrapper_class, "overflow-x-auto"
    set :table_class, "w-full border-collapse"
    set :thead_class, "bg-gray-100"
    set :tbody_class, "divide-y divide-gray-200"
    set :header_row_class, "border-b border-gray-300"
    set :row_class, "hover:bg-gray-50 transition-colors"
    set :th_class, "px-6 py-4 text-left font-semibold text-gray-900"
    set :td_class, "px-6 py-4 text-gray-700"
    set :loading_class, "text-center py-12 text-gray-500"
    set :empty_class, "text-center py-12 text-gray-500"
    set :error_container_class, "bg-red-50 border border-red-200 rounded-lg p-4 text-red-800"
    set :error_message_class, "font-medium"
  end

  component Cinder.Components.Filters do
    set :filter_container_class, "bg-gray-50 border border-gray-200 rounded-lg p-6 mb-6"
    set :filter_header_class, "flex items-center justify-between mb-4"
    set :filter_title_class, "text-lg font-semibold text-gray-900"
    set :filter_count_class, "text-sm text-gray-500 bg-gray-200 px-2 py-1 rounded-full"
    set :filter_clear_all_class, "text-sm text-red-600 hover:text-red-800 underline font-medium"
    set :filter_inputs_class, "grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6"
    set :filter_input_wrapper_class, "space-y-2"
    set :filter_label_class, "block text-sm font-medium text-gray-700"
    set :filter_clear_button_class, "text-gray-400 hover:text-red-500 text-xs font-medium px-2 py-1 rounded hover:bg-gray-100"

    # Input types
    set :filter_text_input_class, "w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
    set :filter_date_input_class, "w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
    set :filter_number_input_class, "w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
    set :filter_select_input_class, "w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500"

    # Boolean filters
    set :filter_boolean_container_class, "flex space-x-6"
    set :filter_boolean_option_class, "flex items-center space-x-2"
    set :filter_boolean_radio_class, "h-4 w-4 text-blue-600 focus:ring-blue-500"
    set :filter_boolean_label_class, "text-sm font-medium text-gray-700"

    # Multi-select filters (tag-based dropdown interface)
    set :filter_multiselect_container_class, "relative"
    set :filter_multiselect_dropdown_class, "absolute z-50 w-full mt-1 bg-white border border-gray-300 rounded-lg shadow-lg max-h-60 overflow-auto"
    set :filter_multiselect_option_class, "px-3 py-2 hover:bg-gray-50 cursor-pointer border-b border-gray-100 last:border-0"
    set :filter_multiselect_checkbox_class, "h-4 w-4 text-blue-600 focus:ring-blue-500 rounded mr-3"
    set :filter_multiselect_label_class, "text-sm font-medium text-gray-700 cursor-pointer"
    set :filter_multiselect_empty_class, "px-3 py-2 text-gray-500 text-sm"

    # Multi-checkboxes filters (traditional checkbox interface)
    set :filter_multicheckboxes_container_class, "space-y-3"
    set :filter_multicheckboxes_option_class, "flex items-center space-x-3"
    set :filter_multicheckboxes_checkbox_class, "h-4 w-4 text-blue-600 focus:ring-blue-500 rounded"
    set :filter_multicheckboxes_label_class, "text-sm font-medium text-gray-700"

    # Range filters
    set :filter_range_container_class, "grid grid-cols-2 gap-3"
    set :filter_range_input_group_class, "space-y-1"
  end

  component Cinder.Components.Pagination do
    set :pagination_wrapper_class, "bg-white border-t border-gray-200 px-6 py-4"
    set :pagination_container_class, "flex items-center justify-between"
    set :pagination_info_class, "text-sm font-medium text-gray-700"
    set :pagination_nav_class, "flex items-center space-x-2"
    set :pagination_button_class, "px-4 py-2 border border-gray-300 rounded-lg hover:bg-gray-50 transition-colors font-medium disabled:opacity-50"
    set :pagination_current_class, "px-4 py-2 bg-blue-600 text-white rounded-lg font-medium"
    set :pagination_count_class, "text-xs text-gray-500 ml-2"
  end

  component Cinder.Components.Sorting do
    set :sort_indicator_class, "ml-2"
    set :sort_arrow_wrapper_class, "inline-block"
    set :sort_asc_icon_class, "w-4 h-4 text-gray-600"
    set :sort_desc_icon_class, "w-4 h-4 text-gray-600"
    set :sort_none_icon_class, "w-4 h-4 text-gray-400 opacity-50"
  end

  component Cinder.Components.Loading do
    set :loading_overlay_class, "absolute top-0 right-0 mt-4 mr-4"
    set :loading_container_class, "flex items-center px-3 py-2 bg-blue-100 rounded-lg text-sm text-blue-800"
    set :loading_spinner_class, "animate-spin -ml-1 mr-2 h-4 w-4 text-blue-600"
    set :loading_spinner_circle_class, "opacity-25"
    set :loading_spinner_path_class, "opacity-75"
  end
end
```

## Best Practices

### Theme Development
1. **Start with inheritance**: Extend built-in themes rather than building from scratch
2. **Use data attributes**: Inspect elements to identify the exact property names
3. **Component-focused**: Organize customizations by component for better maintainability
4. **Consistent naming**: Use consistent CSS class naming conventions

### Design Considerations
1. **Mobile first**: Always test themes on mobile devices
2. **Accessibility**: Ensure sufficient color contrast and focus indicators
3. **Loading states**: Style loading, empty, and error states
4. **Interaction states**: Include hover, focus, and active states

### Performance
1. **Efficient selectors**: Use class-based styling over complex CSS selectors
2. **Minimal DOM**: Avoid adding unnecessary wrapper elements
3. **CSS optimization**: Use CSS-in-JS or preprocessors for better maintainability

## Tips and Tricks

### Development Workflow
1. **Use browser inspector** to examine element structure
2. **Look for `data-key` attributes** to identify theme properties
3. **Update theme incrementally** and test frequently
4. **Create variants** for different sections of your application

### Common Patterns
```elixir
# Responsive design
set :filter_inputs_class, "grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4"

# Dark mode support
set :container_class, "bg-white dark:bg-gray-900 border border-gray-200 dark:border-gray-700"

# Focus states
set :filter_text_input_class, "border border-gray-300 focus:ring-2 focus:ring-blue-500 focus:border-blue-500"

# Transitions
set :row_class, "hover:bg-gray-50 transition-colors duration-150"
```

### Debugging Themes
- Use the data attributes to quickly identify which properties control specific elements
- Test with different table states (loading, empty, filtered, sorted)
- Verify themes work with various screen sizes and input types
- Check theme consistency across all filter types and pagination states