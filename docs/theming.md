# Theming

Cinder provides a comprehensive theming system that allows complete visual customization of your tables. With 10 built-in themes and a powerful DSL for creating custom themes, you can match any design system or create unique visual experiences.

> **See Also**: [Theme Showcase](theme-showcase.md) - Visual examples and comparisons of all built-in themes

## Table of Contents

- [Quick Start](#quick-start)
- [Built-in Theme Presets](#built-in-theme-presets)
- [Custom Themes with DSL](#custom-themes-with-dsl)
- [Theme Inheritance](#theme-inheritance)
- [Developer Tools](#developer-tools)
- [Component Reference](#component-reference)

## Quick Start

### Using Built-in Themes

The fastest way to style your table is with one of the 10 built-in themes:

```heex
<Cinder.collection theme="modern" resource={MyApp.User} actor={@current_user}>
  <:col :let={user} field="name" filter sort>{user.name}</:col>
  <:col :let={user} field="email" filter>{user.email}</:col>
</Cinder.collection>
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
<Cinder.collection theme={MyApp.CustomTheme} resource={MyApp.User} actor={@current_user}>
  <:col :let={user} field="name" filter sort>{user.name}</:col>
</Cinder.collection>
```

## Built-in Theme Presets

Cinder includes 10 carefully crafted themes covering a wide range of design styles. Each theme provides complete coverage for all table components while maintaining a consistent visual identity.

> **Visual Reference**: See the [Theme Showcase](theme-showcase.md) for detailed visual examples and feature descriptions of each theme.

Available themes:

- **`"default"`** - Clean, minimal styling for universal compatibility
- **`"modern"`** - Professional styling with shadows and improved spacing
- **`"dark"`** - Elegant dark theme with proper contrast
- **`"daisy_ui"`** - Optimized for DaisyUI component library
- **`"flowbite"`** - Designed for Flowbite design system
- **`"retro"`** - Cyberpunk-inspired with bright accent colors
- **`"futuristic"`** - Sci-fi aesthetic with glowing effects
- **`"compact"`** - High-density layout for data-heavy applications

### Usage

```heex
<!-- Use any theme by name -->
<Cinder.collection theme="modern" resource={MyApp.User} actor={@current_user}>
  <:col :let={user} field="name" filter sort>{user.name}</:col>
  <:col :let={user} field="email" filter>{user.email}</:col>
</Cinder.collection>
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
    set :filter_container_class, "bg-blue-50 border border-blue-200 rounded-lg p-6 mb-6"
    set :filter_title_class, "text-lg font-semibold text-blue-900 mb-4"
    set :filter_text_input_class, "w-full px-4 py-3 border border-blue-300 rounded-lg focus:ring-2 focus:ring-blue-500"
  end

  component Cinder.Components.Pagination do
    set :pagination_button_class, "px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors"
    set :pagination_info_class, "text-blue-700 font-medium"
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
    set :filter_container_class, "bg-gradient-to-r from-purple-50 to-pink-50 border-2 border-purple-200 rounded-xl p-8 mb-8"
    set :filter_title_class, "text-xl font-bold text-purple-900 mb-6"
    set :filter_text_input_class, "w-full px-4 py-3 border-2 border-purple-300 rounded-lg focus:ring-4 focus:ring-purple-200"
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
    set :filter_container_class, "bg-gray-800 border border-gray-700 rounded-lg p-6 mb-6"
    set :filter_title_class, "text-sm font-medium text-gray-200"
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
    set :filter_container_class, "bg-blue-50 border border-blue-200 rounded-lg p-4 mb-4"
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

<!-- theme-properties-begin -->

### Table Component
Theme properties for the main table component.

```elixir
component Cinder.Components.Table do
  set :container_class, ""
  set :controls_class, ""
  set :table_wrapper_class, "overflow-x-auto"
  set :table_class, "w-full border-collapse"
  set :thead_class, ""
  set :tbody_class, ""
  set :header_row_class, ""
  set :row_class, ""
  set :th_class, "text-left whitespace-nowrap"
  set :td_class, ""
  set :loading_class, "text-center py-4"
  set :empty_class, "text-center py-4"
  set :error_container_class, "text-red-600 text-sm"
  set :error_message_class, ""
end
```

### List Component
Theme properties for the List component.

```elixir
component Cinder.Components.List do
  set :list_container_class, "divide-y divide-gray-200"
  set :list_item_class, "py-3 px-4 text-gray-900"
  set :list_item_clickable_class, "cursor-pointer hover:bg-gray-50 transition-colors"
  set :sort_container_class, "bg-white border border-gray-200 rounded-lg shadow-sm mt-4"
  set :sort_controls_class, "flex items-center gap-2 p-4"
  set :sort_controls_label_class, "text-sm text-gray-600 font-medium"
  set :sort_buttons_class, "flex gap-1"
  set :sort_button_class, "px-3 py-1 text-sm border rounded transition-colors"
  set :sort_button_active_class, "bg-blue-50 border-blue-300 text-blue-700"
  set :sort_button_inactive_class, "bg-white border-gray-300 hover:bg-gray-50"
  set :sort_icon_class, "ml-1"
  set :sort_asc_icon, "↑"
  set :sort_desc_icon, "↓"
end
```

### Grid Component
Theme properties for the Grid component.

```elixir
component Cinder.Components.Grid do
  set :grid_container_class, "grid gap-4"
  set :grid_item_class, "p-4 bg-white border border-gray-200 rounded-lg shadow-sm"
  set :grid_item_clickable_class, "cursor-pointer hover:shadow-md transition-shadow"
end
```

### Filters Component
Theme properties for filter components.

```elixir
component Cinder.Components.Filters do
  set :filter_container_class, ""
  set :filter_header_class, ""
  set :filter_title_class, ""
  set :filter_count_class, ""
  set :filter_clear_all_class, ""
  set :filter_inputs_class, ""
  set :filter_input_wrapper_class, ""
  set :filter_label_class, ""
  set :filter_placeholder_class, ""
  set :filter_clear_button_class, ""
  set :filter_text_input_class, ""
  set :filter_date_input_class, ""
  set :filter_number_input_class, "[&::-webkit-outer-spin-button]:appearance-none [&::-webkit-inner-spin-button]:appearance-none [-moz-appearance:textfield]"
  set :filter_select_input_class, ""
  set :filter_select_container_class, ""
  set :filter_select_dropdown_class, ""
  set :filter_select_option_class, ""
  set :filter_select_label_class, ""
  set :filter_select_empty_class, ""
  set :filter_select_arrow_class, "w-4 h-4 ml-2 flex-shrink-0"
  set :filter_select_placeholder_class, "text-gray-400"
  set :filter_boolean_container_class, ""
  set :filter_boolean_option_class, ""
  set :filter_boolean_radio_class, ""
  set :filter_boolean_label_class, ""
  set :filter_checkbox_container_class, ""
  set :filter_checkbox_input_class, ""
  set :filter_checkbox_label_class, ""
  set :filter_multiselect_container_class, ""
  set :filter_multiselect_dropdown_class, ""
  set :filter_multiselect_option_class, ""
  set :filter_multiselect_checkbox_class, ""
  set :filter_multiselect_label_class, ""
  set :filter_multiselect_empty_class, ""
  set :filter_multicheckboxes_container_class, ""
  set :filter_multicheckboxes_option_class, ""
  set :filter_multicheckboxes_checkbox_class, ""
  set :filter_multicheckboxes_label_class, ""
  set :filter_range_container_class, ""
  set :filter_range_input_group_class, ""
  set :filter_range_separator_class, "flex items-center px-2 text-sm text-gray-500"
end
```

### Pagination Component
Theme properties for pagination components.

```elixir
component Cinder.Components.Pagination do
  set :pagination_wrapper_class, ""
  set :pagination_container_class, ""
  set :pagination_button_class, ""
  set :pagination_info_class, ""
  set :pagination_count_class, ""
  set :pagination_nav_class, ""
  set :pagination_current_class, ""
  set :page_size_container_class, ""
  set :page_size_label_class, ""
  set :page_size_dropdown_class, ""
  set :page_size_dropdown_container_class, ""
  set :page_size_option_class, ""
  set :page_size_selected_class, ""
end
```

### Search Component
Theme properties for the global search component.

```elixir
component Cinder.Components.Search do
  set :search_container_class, ""
  set :search_wrapper_class, "relative"
  set :search_input_class, "w-full px-3 py-2 border rounded"
  set :search_icon_class, "w-4 h-4"
  set :search_label_class, ""
end
```

### Sorting Component
Theme properties for sorting components.

```elixir
component Cinder.Components.Sorting do
  set :sort_indicator_class, "ml-1 inline-flex items-center align-baseline"
  set :sort_arrow_wrapper_class, "inline-flex items-center"
  set :sort_asc_icon_name, "hero-chevron-up"
  set :sort_asc_icon_class, "w-3 h-3"
  set :sort_desc_icon_name, "hero-chevron-down"
  set :sort_desc_icon_class, "w-3 h-3"
  set :sort_none_icon_name, "hero-chevron-up-down"
  set :sort_none_icon_class, "w-3 h-3 opacity-50"
end
```

### Loading Component
Theme properties for loading components.

```elixir
component Cinder.Components.Loading do
  set :loading_overlay_class, ""
  set :loading_container_class, ""
  set :loading_spinner_class, ""
  set :loading_spinner_circle_class, ""
  set :loading_spinner_path_class, ""
end
```


<!-- theme-properties-end -->

