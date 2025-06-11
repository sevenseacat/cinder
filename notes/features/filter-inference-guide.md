# Filter Type Inference Guide

## Overview

The Cinder Table component now automatically infers appropriate filter types from your Ash resource attribute definitions, while still allowing explicit overrides for custom behavior.

## How It Works

When you mark a column as `filterable: true` without specifying a `filter_type`, the system will:

1. **Inspect the Ash resource** to find the corresponding attribute
2. **Analyze the attribute type and constraints** to determine the best filter UI
3. **Generate appropriate options** for enum and select filters automatically
4. **Fall back to text filter** if the attribute isn't found or type is unknown

## Automatic Type Mapping

| Ash Attribute Type | Inferred Filter Type | UI Component | Notes |
|-------------------|---------------------|-------------|-------|
| `:atom` with `one_of` constraints | `:select` | Dropdown | Auto-generates options from enum values |
| `:boolean` | `:boolean` | Radio buttons | True/False/All options |
| `:date` | `:date_range` | Date pickers | From/To date inputs |
| `:integer`, `:decimal`, `:float` | `:number_range` | Number inputs | Min/Max range inputs |
| `:string` | `:text` | Text input | Case-insensitive search |
| `{:array, inner_type}` | `:multi_select` | Checkboxes | For array fields |
| Unknown/Missing | `:text` | Text input | Safe fallback |

## Examples

### Enum Fields (Automatic Select Dropdown)

```elixir
# In your Ash resource
defmodule MyApp.Book do
  use Ash.Resource

  attributes do
    attribute :status, :atom do
      constraints one_of: [:published, :draft, :archived]
    end
    
    attribute :genre, :atom do
      constraints one_of: [:fiction, :non_fiction, :biography, :science]
    end
  end
end

# In your LiveView template - NO filter configuration needed!
<.live_component
  module={Cinder.Table.LiveComponent}
  id="books-table"
  query={MyApp.Book}
  current_user={@current_user}
>
  <:col key="status" filterable={true}>
    <%= item.status %>
  </:col>
  
  <:col key="genre" filterable={true}>
    <%= item.genre %>
  </:col>
</.live_component>
```

**Result:** 
- `status` gets a select dropdown with "Published", "Draft", "Archived" options
- `genre` gets a select dropdown with "Fiction", "Non Fiction", "Biography", "Science" options
- Both include "All [Field Name]" prompt option

### Boolean Fields (Automatic Boolean Filter)

```elixir
# In your Ash resource
attributes do
  attribute :featured, :boolean
  attribute :published, :boolean
end

# In your template
<:col key="featured" filterable={true}>
  <%= if item.featured, do: "Yes", else: "No" %>
</:col>

<:col key="published" filterable={true}>
  <%= if item.published, do: "Published", else: "Draft" %>
</:col>
```

**Result:** Radio button groups with "All", "True", "False" options

### Date Fields (Automatic Date Range)

```elixir
# In your Ash resource
attributes do
  attribute :publish_date, :date
  attribute :created_at, :utc_datetime
end

# In your template
<:col key="publish_date" filterable={true}>
  <%= item.publish_date %>
</:col>
```

**Result:** Date range picker with "From" and "To" date inputs

### Numeric Fields (Automatic Number Range)

```elixir
# In your Ash resource
attributes do
  attribute :price, :decimal
  attribute :page_count, :integer
  attribute :rating, :float
end

# In your template
<:col key="price" filterable={true}>
  $<%= item.price %>
</:col>

<:col key="page_count" filterable={true}>
  <%= item.page_count %> pages
</:col>
```

**Result:** Number range inputs with "Min" and "Max" fields

## Manual Override

You can always override the inferred behavior by explicitly setting `filter_type` and `filter_options`:

```elixir
# Force an enum field to use text search instead of dropdown
<:col 
  key="status" 
  filterable={true}
  filter_type={:text}
>
  <%= item.status %>
</:col>

# Customize the select options or prompt
<:col 
  key="status" 
  filterable={true}
  filter_type={:select}
  filter_options={[
    options: [
      {"Live", :published},
      {"Coming Soon", :draft},
      {"Discontinued", :archived}
    ],
    prompt: "Any Status"
  ]}
>
  <%= item.status %>
</:col>

# Force a boolean to use select instead of radio buttons
<:col 
  key="featured" 
  filterable={true}
  filter_type={:select}
  filter_options={[
    options: [{"Featured Items", true}, {"Regular Items", false}],
    prompt: "All Items"
  ]}
>
  <%= if item.featured, do: "⭐ Featured", else: "Regular" %>
</:col>
```

## Advanced Enum Handling

The inference system intelligently converts enum values to human-readable options:

```elixir
# Enum values are automatically humanized
:published -> "Published"
:draft -> "Draft" 
:archived -> "Archived"
:non_fiction -> "Non Fiction"
:science_fiction -> "Science Fiction"

# Custom labels still work via explicit configuration
filter_options: [
  options: [
    {"In Print", :published},
    {"Coming Soon", :draft},
    {"Out of Print", :archived}
  ]
]
```

## Multi-Select Arrays

Array fields automatically get multi-select checkbox interfaces:

```elixir
# In your resource
attribute :tags, {:array, :atom} do
  constraints items: [one_of: [:technical, :beginner, :advanced, :reference]]
end

# In your template - automatic multi-select!
<:col key="tags" filterable={true}>
  <%= Enum.join(item.tags, ", ") %>
</:col>
```

**Result:** Checkbox list with "Technical", "Beginner", "Advanced", "Reference" options

## Best Practices

### 1. Use Descriptive Enum Values
```elixir
# Good - clear, descriptive
constraints one_of: [:published, :draft, :under_review, :archived]

# Less ideal - abbreviated or unclear
constraints one_of: [:pub, :dft, :rev, :arc]
```

### 2. Leverage Inference for Consistency
```elixir
# Let inference handle standard types for consistency
<:col key="status" filterable={true}>
<:col key="published" filterable={true}>
<:col key="created_at" filterable={true}>

# Only override for special cases
<:col key="priority" filterable={true} filter_type={:number_range}>
```

### 3. Override When UI Needs Customization
```elixir
# Custom prompt text
<:col 
  key="category" 
  filterable={true}
  filter_options={[prompt: "Choose Category"]}
>

# Simplified options
<:col 
  key="difficulty" 
  filterable={true}
  filter_options={[
    options: [{"Easy", :beginner}, {"Hard", :advanced}]
  ]}
>
```

## Error Handling

The inference system is designed to be resilient:

- **Missing attributes**: Defaults to text filter
- **Unknown types**: Defaults to text filter  
- **Non-Ash resources**: Gracefully falls back to text
- **Invalid configurations**: Logs warnings but continues with defaults

## Performance Notes

- Attribute inspection happens once during column definition parsing
- No runtime performance impact on filtering operations
- Inference results are cached in the column configuration
- Manual overrides bypass inference entirely

## Migration Guide

### From Manual Configuration

```elixir
# Before (manual configuration required)
<:col 
  key="status" 
  filterable={true}
  filter_type={:select}
  filter_options={[
    options: [{"Published", :published}, {"Draft", :draft}],
    prompt: "All Statuses"
  ]}
>

# After (automatic inference)
<:col key="status" filterable={true}>
```

### Gradual Adoption

You can adopt inference gradually:

1. **Start with new columns** - Use inference for new filterable columns
2. **Migrate existing simple cases** - Remove manual config for standard enum/boolean fields
3. **Keep complex customizations** - Maintain manual config where you have custom options or prompts
4. **Test thoroughly** - Verify inferred UI matches your expectations

## Troubleshooting

### Filter Shows Text Instead of Dropdown

**Cause**: Attribute not found or enum constraints not detected

**Solutions**:
1. Verify the column `key` matches the Ash attribute name exactly
2. Check that the attribute uses `constraints one_of: [...]` format
3. Ensure the resource is a proper Ash resource with `use Ash.Resource`
4. Add explicit configuration as fallback

### Wrong Filter Type Inferred

**Cause**: Attribute type doesn't match expected mapping

**Solutions**:
1. Use explicit `filter_type` override
2. Check the actual attribute definition in your resource
3. Consider if a different filter type is actually more appropriate

### Options Don't Look Right

**Cause**: Automatic humanization doesn't match your preferences

**Solutions**:
1. Use explicit `filter_options` with custom labels
2. Update enum values to be more descriptive
3. Provide custom prompt text

## Future Enhancements

The inference system is designed to be extensible. Planned improvements include:

- **Relationship field inference**: Detect `belongs_to` fields and create select dropdowns from related records
- **Custom type handlers**: Plugin system for custom Ash types
- **Localization support**: Automatic translation of inferred labels
- **Advanced constraints**: Support for more complex constraint types