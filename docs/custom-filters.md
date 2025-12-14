# Custom Filters

This guide covers how to create custom filters for Cinder tables. Custom filters allow you to extend Cinder's filtering capabilities with domain-specific UI components and logic.

## Overview

Cinder's filter system is built around the `Cinder.Filter` behaviour, which defines a standard interface for all filter types. Custom filters implement this behaviour and can be registered with the system for use in tables.

## Generator - `mix cinder.gen.filter`

The easiest way to create custom filters is using the `cinder.gen.filter` Mix task. This generator creates a custom filter based on one of the built-in filters, allowing you to customize specific behaviors while keeping the rest of the implementation.

### Basic Usage

```bash
mix cinder.gen.filter MyApp.Filters.CustomText custom_text --template=text
```

This creates:
- A custom filter module that delegates to `Cinder.Filters.Text`
- Automatically updates your configuration
- Generates comprehensive test files
- Updates the filter type to your custom type

### Available Templates

- `text` - Based on `Cinder.Filters.Text` (text input with operators)
- `select` - Based on `Cinder.Filters.Select` (dropdown selection)
- `multi_select` - Based on `Cinder.Filters.MultiSelect` (multiple selection)
- `multi_checkboxes` - Based on `Cinder.Filters.MultiCheckboxes` (multiple selection)
- `boolean` - Based on `Cinder.Filters.Boolean` (true/false/any selection)
- `date_range` - Based on `Cinder.Filters.DateRange` (from/to date picker)
- `number_range` - Based on `Cinder.Filters.NumberRange` (from/to number input)

### Example: Creating a Custom Text Filter

```bash
mix cinder.gen.filter MyApp.Filters.CaseInsensitiveText case_insensitive_text --template=text
```

This generates a filter that starts by delegating all behavior to `Cinder.Filters.Text` but with your custom type. You can then override specific functions to customize behavior:

```elixir
defmodule MyApp.Filters.CaseInsensitiveText do
  # ... generated delegations ...

  # Override to customize processing
  @impl true
  def process(raw_value, column) do
    case Cinder.Filters.Text.process(raw_value, column) do
      %{type: _old_type, value: value} = filter ->
        %{filter | type: :case_insensitive_text, value: String.downcase(value)}
      result -> result
    end
  end

  # Override to customize query building
  @impl true
  def build_query(query, field, %{value: value} = filter_value) do
    field_atom = String.to_atom(field)
    # Use ilike for case-insensitive matching
    Ash.Query.filter(query, ilike(^ref(field_atom), ^"%#{value}%"))
  end
end
```

### Options

- `--template` or `-t` - Choose the base filter to copy from
- `--no-tests` - Skip generating test file
- `--no-config` - Skip automatic configuration registration
- `--no-setup` - Skip setup instructions

## Quick Start

Here's a complete example of a custom slider filter:

```elixir
defmodule MyApp.Filters.Slider do
  @moduledoc """
  A range slider filter for numeric values.

  Provides a visual slider interface for filtering numeric columns
  with configurable min, max, and step values.
  """

  use Cinder.Filter

  @impl true
  def render(column, current_value, theme, assigns) do
    filter_options = Map.get(column, :filter_options, [])

    min_value = get_option(filter_options, :min, 0)
    max_value = get_option(filter_options, :max, 100)
    step_value = get_option(filter_options, :step, 1)
    current = current_value || min_value

    assigns = %{
      column: column,
      current_value: current,
      min_value: min_value,
      max_value: max_value,
      step_value: step_value,
      theme: theme
    }

    ~H"""
    <div class="flex flex-col space-y-2">
      <input
        type="range"
        name={field_name(@column.field)}
        value={@current_value}
        min={@min_value}
        max={@max_value}
        step={@step_value}
        phx-debounce="100"
        class="w-full h-2 bg-gray-200 rounded-lg appearance-none cursor-pointer"
        oninput="this.nextElementSibling.value = this.value"
      />
      <div class="flex justify-between text-sm text-gray-600">
        <span>{@min_value}</span>
        <output class="font-medium">{@current_value}</output>
        <span>{@max_value}</span>
      </div>
    </div>
    """
  end

  @impl true
  def process(raw_value, column) when is_binary(raw_value) do
    case Integer.parse(raw_value) do
      {value, ""} ->
        filter_options = Map.get(column, :filter_options, [])
        operator = get_option(filter_options, :operator, :equals)

        %{
          type: :slider,
          value: value,
          operator: operator
        }

      _ -> nil
    end
  end

  def process(_raw_value, _column), do: nil

  @impl true
  def validate(%{type: :slider, value: value, operator: operator})
      when is_integer(value) and is_atom(operator) do
    operator in [:equals, :greater_than, :less_than, :greater_than_or_equal, :less_than_or_equal]
  end

  def validate(_), do: false

  @impl true
  def default_options do
    [
      min: 0,
      max: 100,
      step: 1,
      operator: :equals
    ]
  end

  @impl true
  def empty?(value) do
    case value do
      nil -> true
      %{value: nil} -> true
      _ -> false
    end
  end

  @impl true
  def build_query(query, field, filter_value) do
    %{type: :slider, value: value, operator: operator} = filter_value

    # Handle relationship fields using dot notation
    if String.contains?(field, ".") do
      path_atoms = field |> String.split(".") |> Enum.map(&String.to_atom/1)
      {rel_path, [field_atom]} = Enum.split(path_atoms, -1)

      case operator do
        :equals ->
          Ash.Query.filter(query, exists(^rel_path, ^ref(field_atom) == ^value))
        :greater_than ->
          Ash.Query.filter(query, exists(^rel_path, ^ref(field_atom) > ^value))
        :greater_than_or_equal ->
          Ash.Query.filter(query, exists(^rel_path, ^ref(field_atom) >= ^value))
        :less_than ->
          Ash.Query.filter(query, exists(^rel_path, ^ref(field_atom) < ^value))
        :less_than_or_equal ->
          Ash.Query.filter(query, exists(^rel_path, ^ref(field_atom) <= ^value))
        _ ->
          query
      end
    else
      # Direct field filtering
      field_atom = String.to_atom(field)

      case operator do
        :equals ->
          Ash.Query.filter(query, ^ref(field_atom) == ^value)
        :greater_than ->
          Ash.Query.filter(query, ^ref(field_atom) > ^value)
        :greater_than_or_equal ->
          Ash.Query.filter(query, ^ref(field_atom) >= ^value)
        :less_than ->
          Ash.Query.filter(query, ^ref(field_atom) < ^value)
        :less_than_or_equal ->
          Ash.Query.filter(query, ^ref(field_atom) <= ^value)
        _ ->
          query
      end
    end
  end
end
```

## Setup and Configuration

### 1. Configure Custom Filters

Add your custom filters to your application configuration:

```elixir
# config/config.exs
config :cinder, :filters, [
  slider: MyApp.Filters.Slider,
  color_picker: MyApp.Filters.ColorPicker,
  date_picker: MyApp.Filters.DatePicker
]
```

### 2. Initialize Cinder

Call `Cinder.setup()` in your application startup:

```elixir
# lib/my_app/application.ex
defmodule MyApp.Application do
  use Application

  def start(_type, _args) do
    # Set up Cinder with configured filters
    Cinder.setup()

    children = [
      # your supervisors...
    ]

    opts = [strategy: :one_for_one, name: MyApp.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
```

### 3. Use in Tables

Use your custom filter in column definitions:

```heex
<Cinder.collection resource={MyApp.Product} actor={@current_user}>
  <:col :let={product} field="price" filter={[type: :slider, min: 0, max: 1000, step: 10]} sort>
    ${product.price}
  </:col>
</Cinder.collection>
```

## The Cinder.Filter Behaviour

All custom filters must implement the `Cinder.Filter` behaviour with these callbacks:

### Required Callbacks

#### `render/4`
Renders the filter UI component.

```elixir
@callback render(column :: map(), current_value :: any(), theme :: map(), assigns :: map()) :: Phoenix.LiveView.Rendered.t()
```

- `column`: Column configuration with `field`, `label`, `filter_options`
- `current_value`: Current filter value (nil if no filter applied)
- `theme`: Theme configuration with CSS classes
- `assigns`: Additional assigns from the parent component

#### `process/2`
Processes raw form/URL input into structured filter data.

```elixir
@callback process(raw_value :: any(), column :: map()) :: map() | nil
```

Must return a map with `:type`, `:value`, `:operator` keys, or `nil`.

#### `validate/1`
Validates a processed filter value.

```elixir
@callback validate(value :: any()) :: boolean()
```

#### `default_options/0`
Returns default configuration options.

```elixir
@callback default_options() :: keyword()
```

#### `empty?/1`
Determines if a filter value is "empty" (no filtering applied).

```elixir
@callback empty?(value :: any()) :: boolean()
```

#### `build_query/3`
**Critical for functionality!** Builds the Ash query for this filter.

```elixir
@callback build_query(query :: Ash.Query.t(), field :: String.t(), filter_value :: map()) :: Ash.Query.t()
```

## Helper Functions

The `Cinder.Filter` module provides utilities via `use Cinder.Filter`:

### `field_name/1`
Generates form field names:

```elixir
~H"""
<input name={field_name(@column.field)} ... />
"""
```

### `get_option/3`
Safely extracts options from filter configuration:

```elixir
filter_options = Map.get(column, :filter_options, [])
placeholder = get_option(filter_options, :placeholder, "Default text")
```

## Common Patterns

### Simple Value Filters

```elixir
def process(raw_value, _column) when is_binary(raw_value) do
  trimmed = String.trim(raw_value)

  if trimmed == "" do
    nil
  else
    %{
      type: :my_filter,
      value: trimmed,
      operator: :equals
    }
  end
end

def process(_raw_value, _column), do: nil
```

### Range Filters

```elixir
def process(%{"min" => min, "max" => max}, _column) do
  with {min_val, ""} <- Integer.parse(min),
       {max_val, ""} <- Integer.parse(max),
       true <- min_val <= max_val do
    %{
      type: :my_range,
      value: %{min: min_val, max: max_val},
      operator: :between
    }
  else
    _ -> nil
  end
end
```

### Multi-Value Filters

```elixir
def process(raw_values, _column) when is_list(raw_values) do
  values = Enum.reject(raw_values, &(&1 == "" or is_nil(&1)))

  if Enum.empty?(values) do
    nil
  else
    %{
      type: :my_multi,
      value: values,
      operator: :in
    }
  end
end
```

## Query Building Patterns

### Basic Field Filtering

```elixir
def build_query(query, field, filter_value) do
  %{value: value} = filter_value
  field_atom = String.to_atom(field)
  Ash.Query.filter(query, ^ref(field_atom) == ^value)
end
```

### Relationship Filtering

Handle dot notation fields like "user.name":

```elixir
def build_query(query, field, filter_value) do
  %{value: value} = filter_value

  if String.contains?(field, ".") do
    # Handle relationship fields
    path_atoms = field |> String.split(".") |> Enum.map(&String.to_atom/1)
    {rel_path, [field_atom]} = Enum.split(path_atoms, -1)

    Ash.Query.filter(query, exists(^rel_path, ^ref(field_atom) == ^value))
  else
    # Direct field filtering
    field_atom = String.to_atom(field)
    Ash.Query.filter(query, ^ref(field_atom) == ^value)
  end
end
```

### Complex Queries

```elixir
def build_query(query, field, filter_value) do
  %{type: :date_range, value: %{from: from_date, to: to_date}} = filter_value
  field_atom = String.to_atom(field)

  query
  |> Ash.Query.filter(^ref(field_atom) >= ^from_date)
  |> Ash.Query.filter(^ref(field_atom) <= ^to_date)
end
```



## Testing Custom Filters

### Unit Tests

```elixir
defmodule MyApp.Filters.SliderTest do
  use ExUnit.Case
  alias MyApp.Filters.Slider

  describe "process/2" do
    test "processes valid integer values" do
      column = %{filter_options: [min: 0, max: 100]}

      result = Slider.process("50", column)

      assert result == %{
        type: :slider,
        value: 50,
        operator: :equals
      }
    end

    test "returns nil for invalid values" do
      result = Slider.process("invalid", %{})
      assert result == nil
    end
  end

  describe "validate/1" do
    test "validates correct filter structure" do
      valid_filter = %{
        type: :slider,
        value: 75,
        operator: :equals
      }

      assert Slider.validate(valid_filter) == true
    end
  end

  describe "build_query/3" do
    test "builds correct query for direct field" do
      query = Ash.Query.new(MyApp.Product)
      filter_value = %{type: :slider, value: 100, operator: :less_than_or_equal}

      result = Slider.build_query(query, "price", filter_value)

      # Test that the query has the correct filter
      # Implementation depends on your testing setup
    end
  end
end
```

## Registry Functions

Check filter registration status:

```elixir
# List all registered filters
Cinder.Filters.Registry.list_filters()

# Check if a filter is custom
Cinder.Filters.Registry.custom_filter?(:slider)

# Get filter module
Cinder.Filters.Registry.get_filter(:slider)

# Get default options
Cinder.Filters.Registry.default_options(:slider)

# Check if registered
Cinder.Filters.Registry.registered?(:slider)
```

## Best Practices

### 1. Handle Edge Cases

Always handle nil values, empty strings, and invalid input:

```elixir
def process(raw_value, _column) when raw_value in [nil, ""], do: nil
def process(raw_value, column) when is_binary(raw_value) do
  # Main processing logic
end
def process(_raw_value, _column), do: nil
```

### 2. Provide Sensible Defaults

```elixir
def default_options do
  [
    placeholder: "Enter value...",
    case_sensitive: false,
    operator: :contains
  ]
end
```

### 3. Make Filters Configurable

```elixir
# Column definition
%{
  field: "score",
  filter: :slider,
  filter_options: [
    min: 0,
    max: 1000,
    step: 10,
    operator: :less_than_or_equal
  ]
}
```

### 4. Document Your Filters

```elixir
defmodule MyApp.Filters.Slider do
  @moduledoc """
  Slider filter for numeric range filtering.

  ## Options

  - `:min` - Minimum value (default: 0)
  - `:max` - Maximum value (default: 100)
  - `:step` - Step increment (default: 1)
  - `:operator` - Comparison operator (default: :equals)

  ## Usage

      %{
        field: "price",
        filter: :slider,
        filter_options: [min: 0, max: 1000, step: 50, operator: :less_than_or_equal]
      }
  """

  use Cinder.Filter
  # ... implementation
end
```

### 5. Implement build_query/3 Correctly

This is the most critical callback - without it, your filter won't actually filter data!

## Troubleshooting

### Filter Not Appearing
- Check configuration: `config :cinder, :filters, [slider: MyApp.Filters.Slider]`
- Verify `Cinder.setup()` was called
- Ensure column uses `filter={:slider}` (not `filter_type`)
- Check console for registration errors

### Filter Not Working
- Verify `build_query/3` is implemented
- Check that `process/2` returns correct structure
- Test with `Cinder.Filters.Registry.get_filter(:slider)`
- Add logging to debug query building

### Configuration Issues
- Check config syntax (proper map format)
- Verify module names are correct
- Run `Cinder.Filters.Registry.validate_custom_filters()`

### URL State Not Persisting
- Ensure using `Cinder.UrlSync`
- Check `handle_params/3` implementation
- Verify `url_state={@url_state}` attribute

## Advanced Topics

### Dynamic Filter Options

```elixir
def render(column, current_value, theme, assigns) do
  # Get options from database or context
  options = get_dynamic_options(column.field, assigns)

  assigns = Map.put(assigns, :dynamic_options, options)
  # ... render with dynamic options
end
```

### Filter Dependencies

```elixir
def render(column, current_value, theme, assigns) do
  # Access other filter values
  category_filter = get_in(assigns, [:filters, "category"])

  # Adjust options based on other filters
  options = get_options_for_category(category_filter)
  # ... render
end
```

### Custom Validation

```elixir
def validate(value) do
  case value do
    %{type: :my_filter, value: val} ->
      # Custom business logic validation
      val > 0 and val < 1000 and is_valid_for_business_rules(val)
    _ ->
      false
  end
end
```

## Key Points

- Use `use Cinder.Filter` to get all necessary imports and behavior
- Configure filters in `config.exs` with `:filters` key
- Call `Cinder.setup()` once in application startup
- Use `filter={:my_filter}` in column definitions
- Always implement `build_query/3` - this is what actually filters data
- Handle both direct fields and relationship fields (dot notation)
- Provide fallback CSS classes for theme compatibility
- Test all callbacks thoroughly, especially query building
