# Cinder Theming System

Cinder provides a powerful, modular theming system that allows you to completely customize the appearance of your tables. Every HTML element can be styled using a clean DSL syntax.

## Table of Contents

- [Quick Start](#quick-start)
- [Built-in Theme Presets](#built-in-theme-presets)
- [DSL-Based Themes](#dsl-based-themes)
- [Theme Inheritance](#theme-inheritance)
- [Component Reference](#component-reference)
- [Real-World Examples](#real-world-examples)

## Quick Start

The simplest way to customize your table's appearance is to use one of the built-in theme presets:

```elixir
<Cinder.Table.table theme="modern" resource={MyApp.User} current_user={@current_user}>
  <:col field="name" filter sort>Name</:col>
  <:col field="email" filter>Email</:col>
</Cinder.Table.table>
```

For more control, create a custom theme module:

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

Cinder includes three carefully crafted theme presets:

### Default Theme
Clean, professional styling suitable for most applications:
```elixir
<Cinder.Table.table theme="default" resource={MyApp.User} current_user={@current_user}>
```

### Modern Theme
Enhanced styling with shadows, improved spacing, and smooth transitions:
```elixir
<Cinder.Table.table theme="modern" resource={MyApp.User} current_user={@current_user}>
```

### Minimal Theme
Streamlined styling with reduced visual weight:
```elixir
<Cinder.Table.table theme="minimal" resource={MyApp.User} current_user={@current_user}>
```

## DSL-Based Themes

Create reusable, modular themes using Cinder's DSL:

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

You can customize individual components while leaving others with default styling:

```elixir
defmodule MyApp.Theme.FilterFocused do
  use Cinder.Theme

  # Only customize filters, leave table and pagination with defaults
  component Cinder.Components.Filters do
    set :container_class, "bg-gradient-to-r from-purple-50 to-pink-50 border-2 border-purple-200 rounded-xl p-8 mb-8"
    set :title_class, "text-xl font-bold text-purple-900 mb-6"
    set :text_input_class, "w-full px-4 py-3 border-2 border-purple-300 rounded-lg focus:ring-4 focus:ring-purple-200"
    set :boolean_container_class, "flex space-x-6 bg-white p-4 rounded-lg shadow-sm"
    set :boolean_radio_class, "h-5 w-5 text-purple-600 focus:ring-purple-500"
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
    set :text_input_class, "w-full px-3 py-2 bg-gray-700 border border-gray-600 rounded-md text-gray-200 focus:ring-2 focus:ring-blue-500"
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

## Component Reference

Cinder organizes theme properties by logical components. Here are the available components and their key properties:

### Table Component
Controls the main table structure:

```elixir
component Cinder.Components.Table do
  set :container_class, "..."      # Outer container
  set :table_wrapper_class, "..."  # Scrollable wrapper
  set :table_class, "..."          # Table element
  set :thead_class, "..."          # Table header
  set :tbody_class, "..."          # Table body
  set :th_class, "..."             # Header cells
  set :td_class, "..."             # Data cells
  set :row_class, "..."            # Table rows
  set :loading_class, "..."        # Loading state
  set :empty_class, "..."          # Empty state
end
```

### Filters Component
Controls all filter-related styling:

```elixir
component Cinder.Components.Filters do
  # Filter container
  set :container_class, "..."
  set :header_class, "..."
  set :title_class, "..."
  set :inputs_class, "..."
  
  # Input types
  set :text_input_class, "..."
  set :select_input_class, "..."
  set :date_input_class, "..."
  set :number_input_class, "..."
  
  # Boolean filters
  set :boolean_container_class, "..."
  set :boolean_option_class, "..."
  set :boolean_radio_class, "..."
  set :boolean_label_class, "..."
  
  # Multi-select filters
  set :multiselect_container_class, "..."
  set :multiselect_option_class, "..."
  set :multiselect_checkbox_class, "..."
  set :multiselect_label_class, "..."
  
  # Range filters
  set :range_container_class, "..."
  set :range_input_group_class, "..."
end
```

### Pagination Component
Controls pagination styling:

```elixir
component Cinder.Components.Pagination do
  set :wrapper_class, "..."      # Outer wrapper
  set :container_class, "..."    # Inner container
  set :button_class, "..."       # Navigation buttons
  set :info_class, "..."         # Page info text
  set :count_class, "..."        # Record count text
end
```

### Sorting Component
Controls sort indicators and icons:

```elixir
component Cinder.Components.Sorting do
  set :indicator_class, "..."        # Sort indicator wrapper
  set :arrow_wrapper_class, "..."    # Icon wrapper
  set :asc_icon_class, "..."         # Ascending icon
  set :desc_icon_class, "..."        # Descending icon
  set :none_icon_class, "..."        # Unsorted icon
end
```

### Loading Component
Controls loading states:

```elixir
component Cinder.Components.Loading do
  set :overlay_class, "..."         # Loading overlay
  set :container_class, "..."       # Loading text container
  set :spinner_class, "..."         # Spinner element
  set :spinner_circle_class, "..."  # Spinner circle
  set :spinner_path_class, "..."    # Spinner path
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
    set :container_class, "bg-green-50 border border-green-200 rounded-lg p-6 mb-6"
    set :title_class, "text-lg font-semibold text-green-900"
    set :text_input_class, "w-full px-3 py-2 border border-green-300 rounded-md focus:ring-2 focus:ring-green-500 focus:border-green-500"
  end

  component Cinder.Components.Pagination do
    set :button_class, "px-4 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700 transition-colors"
    set :info_class, "text-green-700 font-medium"
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
    set :container_class, "bg-slate-800 border border-slate-600 rounded-lg p-6 mb-6"
    set :title_class, "text-lg font-semibold text-slate-100 mb-4"
    set :text_input_class, "w-full px-3 py-2 bg-slate-700 border border-slate-600 rounded-md text-slate-200 focus:ring-2 focus:ring-blue-500"
  end

  component Cinder.Components.Loading do
    set :container_class, "flex items-center text-sm text-blue-400 font-medium"
    set :spinner_class, "animate-spin -ml-1 mr-2 h-4 w-4 text-blue-400"
  end
end
```

### Mobile-Optimized Theme

```elixir
defmodule MyApp.Theme.Mobile do
  use Cinder.Theme
  extends :minimal

  component Cinder.Components.Table do
    set :container_class, "bg-white rounded-lg shadow-sm border border-gray-200"
    set :table_wrapper_class, "overflow-x-auto -mx-4 sm:mx-0"
    set :th_class, "px-3 py-2 text-xs font-semibold text-gray-900 uppercase tracking-wider"
    set :td_class, "px-3 py-2 text-sm text-gray-700"
  end

  component Cinder.Components.Filters do
    set :inputs_class, "space-y-4"  # Stack filters vertically on mobile
    set :container_class, "bg-gray-50 rounded-lg p-4 mb-4"
    set :text_input_class, "w-full px-3 py-2 text-base border border-gray-300 rounded-lg"  # Larger touch targets
  end

  component Cinder.Components.Pagination do
    set :container_class, "flex flex-col space-y-2 sm:flex-row sm:items-center sm:justify-between sm:space-y-0"
    set :button_class, "px-3 py-2 text-sm border border-gray-300 rounded-lg hover:bg-gray-50"
  end
end
```

### Comprehensive Theme Example

```elixir
defmodule MyApp.Theme.Comprehensive do
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
    set :container_class, "bg-gray-50 border border-gray-200 rounded-lg p-6 mb-6"
    set :header_class, "flex items-center justify-between mb-4"
    set :title_class, "text-lg font-semibold text-gray-900"
    set :count_class, "text-sm text-gray-500 bg-gray-200 px-2 py-1 rounded-full"
    set :clear_all_class, "text-sm text-red-600 hover:text-red-800 underline font-medium"
    set :inputs_class, "grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6"
    set :input_wrapper_class, "space-y-2"
    set :label_class, "block text-sm font-medium text-gray-700"
    set :clear_button_class, "text-gray-400 hover:text-red-500 text-xs font-medium px-2 py-1 rounded hover:bg-gray-100"

    # Input types
    set :text_input_class, "w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
    set :date_input_class, "w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
    set :number_input_class, "w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
    set :select_input_class, "w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500"

    # Boolean filters
    set :boolean_container_class, "flex space-x-6"
    set :boolean_option_class, "flex items-center space-x-2"
    set :boolean_radio_class, "h-4 w-4 text-blue-600 focus:ring-blue-500"
    set :boolean_label_class, "text-sm font-medium text-gray-700"

    # Multi-select filters
    set :multiselect_container_class, "space-y-3"
    set :multiselect_option_class, "flex items-center space-x-3"
    set :multiselect_checkbox_class, "h-4 w-4 text-blue-600 focus:ring-blue-500 rounded"
    set :multiselect_label_class, "text-sm font-medium text-gray-700"

    # Range filters
    set :range_container_class, "grid grid-cols-2 gap-3"
    set :range_input_group_class, "space-y-1"
  end

  component Cinder.Components.Pagination do
    set :wrapper_class, "bg-white border-t border-gray-200 px-6 py-4"
    set :container_class, "flex items-center justify-between"
    set :button_class, "px-4 py-2 border border-gray-300 rounded-lg hover:bg-gray-50 transition-colors font-medium disabled:opacity-50"
    set :info_class, "text-sm font-medium text-gray-700"
    set :count_class, "text-xs text-gray-500 ml-2"
  end

  component Cinder.Components.Sorting do
    set :indicator_class, "ml-2"
    set :arrow_wrapper_class, "inline-block"
    set :asc_icon_class, "w-4 h-4 text-gray-600"
    set :desc_icon_class, "w-4 h-4 text-gray-600"
    set :none_icon_class, "w-4 h-4 text-gray-400 opacity-50"
  end

  component Cinder.Components.Loading do
    set :overlay_class, "absolute top-0 right-0 mt-4 mr-4"
    set :container_class, "flex items-center px-3 py-2 bg-blue-100 rounded-lg text-sm text-blue-800"
    set :spinner_class, "animate-spin -ml-1 mr-2 h-4 w-4 text-blue-600"
    set :spinner_circle_class, "opacity-25"
    set :spinner_path_class, "opacity-75"
  end
end
```

## Best Practices

1. **Start with inheritance**: Extend built-in themes rather than building from scratch
2. **Component-focused**: Organize customizations by component for better maintainability
3. **Consistent naming**: Use consistent CSS class naming conventions across your themes
4. **Mobile considerations**: Always test your themes on mobile devices
5. **Accessibility**: Ensure sufficient color contrast and focus indicators
6. **Performance**: Use efficient CSS selectors and avoid overly complex styles

## Tips

- Use browser developer tools to inspect element structure and identify the right theme properties
- Create a base theme for your application and extend it for specific use cases
- Consider creating theme variants for different sections of your application
- Test themes with various data states (loading, empty, error) to ensure complete coverage