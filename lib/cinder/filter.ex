defmodule Cinder.Filter do
  @moduledoc """
  Base behavior for Cinder filter implementations.

  Defines the common interface that all filter types must implement,
  along with shared types and utility functions.

  ## Quick Start

  The most convenient way to create a custom filter is to use this module:

      defmodule MyApp.Filters.Slider do
        use Cinder.Filter

        @impl true
        def render(column, current_value, theme, assigns) do
          filter_options = Map.get(column, :filter_options, [])
          min_value = get_option(filter_options, :min, 0)
          max_value = get_option(filter_options, :max, 100)
          current = current_value || min_value

          assigns = %{
            column: column,
            current_value: current,
            min_value: min_value,
            max_value: max_value,
            theme: theme
          }

          ~H\"\"\"
          <div class="flex flex-col space-y-2">
            <input
              type="range"
              name={field_name(@column.field)}
              value={@current_value}
              min={@min_value}
              max={@max_value}
              phx-debounce="100"
              class={Map.get(@theme, :filter_slider_input_class, "w-full")}
            />
            <output>{@current_value}</output>
          </div>
          \"\"\"
        end

        @impl true
        def process(raw_value, column) when is_binary(raw_value) do
          case Integer.parse(raw_value) do
            {value, ""} ->
              %{
                type: :slider,
                value: value,
                operator: :less_than_or_equal
              }
            _ -> nil
          end
        end

        def process(_raw_value, _column), do: nil

        @impl true
        def validate(%{type: :slider, value: value, operator: operator})
            when is_integer(value) and is_atom(operator), do: true
        def validate(_), do: false

        @impl true
        def default_options, do: [min: 0, max: 100, step: 1]

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
          %{value: value} = filter_value
          field_atom = String.to_atom(field)
          Ash.Query.filter(query, ^ref(field_atom) <= ^value)
        end
      end

  Then register it in your configuration:

      config :cinder, :filters, %{
        slider: MyApp.Filters.Slider
      }

  And call `Cinder.setup()` in your application start function to register
  all configured filters.

  This automatically:
  - Adds the `@behaviour Cinder.Filter` declaration
  - Imports Phoenix.Component for HEEx templates
  - Imports helper functions from this module

  ## Required Callbacks

  All custom filters must implement these callbacks:

  ### render/4

  Renders the filter UI component.

      @callback render(column :: map(), current_value :: any(), theme :: map(), assigns :: map()) :: Phoenix.LiveView.Rendered.t()

  - `column`: Column configuration with `field`, `label`, `filter_options`
  - `current_value`: Current filter value (nil if no filter applied)
  - `theme`: Theme configuration with CSS classes
  - `assigns`: Additional assigns from the parent component

  ### process/2

  Processes raw form/URL input into structured filter data.

      @callback process(raw_value :: any(), column :: map()) :: map() | nil

  Must return a map with `:type`, `:value`, `:operator` keys, or `nil`.

  ### validate/1

  Validates a processed filter value.

      @callback validate(value :: any()) :: boolean()

  ### default_options/0

  Returns default configuration options.

      @callback default_options() :: keyword()

  ### empty?/1

  Determines if a filter value is "empty" (no filtering applied).

      @callback empty?(value :: any()) :: boolean()

  ### build_query/3

  **Critical for functionality!** Builds the Ash query for this filter.

      @callback build_query(query :: Ash.Query.t(), field :: String.t(), filter_value :: map()) :: Ash.Query.t()

  ## Helper Functions

  ### field_name/1

  Generates proper form field names for filter inputs:

      ~H\"\"\"
      <input name={field_name(@column.field)} ... />
      \"\"\"

  ### get_option/3

  Safely extracts options from filter configuration with defaults:

      filter_options = Map.get(column, :filter_options, [])
      placeholder = get_option(filter_options, :placeholder, "Enter text...")

  ## Query Building Patterns

  ### Basic Field Filtering

      def build_query(query, field, filter_value) do
        %{value: value} = filter_value
        field_atom = String.to_atom(field)
        Ash.Query.filter(query, ^ref(field_atom) == ^value)
      end

  ### Relationship Filtering

  Handle dot notation fields like "user.name":

      def build_query(query, field, filter_value) do
        %{value: value} = filter_value

        if String.contains?(field, ".") do
          path_atoms = field |> String.split(".") |> Enum.map(&String.to_atom/1)
          {rel_path, [field_atom]} = Enum.split(path_atoms, -1)

          Ash.Query.filter(query, exists(^rel_path, ^ref(field_atom) == ^value))
        else
          field_atom = String.to_atom(field)
          Ash.Query.filter(query, ^ref(field_atom) == ^value)
        end
      end

  ## Best Practices

  1. **Always implement build_query/3** - This is what actually filters data
  2. **Handle edge cases in process/2** - Return nil for invalid input
  3. **Validate filter values** - Check structure and data types
  4. **Document your filters** - Include usage examples and options

  """

  @doc false
  defmacro __using__(_opts) do
    quote do
      @behaviour Cinder.Filter
      use Phoenix.Component

      require Ash.Query
      import Ash.Expr
      import Cinder.Filter
    end
  end

  @type filter_value ::
          String.t()
          | [String.t()]
          | %{from: String.t(), to: String.t()}
          | %{min: String.t(), max: String.t()}
          | boolean()
          | nil

  @type filter_options :: [
          placeholder: String.t(),
          prompt: String.t(),
          options: [{String.t(), any()}],
          operator: atom(),
          case_sensitive: boolean(),
          labels: %{atom() => String.t()}
        ]

  @type column :: %{
          field: String.t(),
          label: String.t(),
          filter_type: atom(),
          filter_options: filter_options()
        }

  @type theme :: %{
          filter_input_class: String.t(),
          filter_select_class: String.t(),
          filter_checkbox_class: String.t(),
          filter_date_input_class: String.t(),
          filter_number_input_class: String.t()
        }

  @doc """
  Renders the filter input component for this filter type.

  ## Parameters
  - `column` - Column definition with filter configuration
  - `current_value` - Current filter value
  - `theme` - Theme configuration for styling
  - `assigns` - Additional assigns (target, filter_values, etc.)

  ## Returns
  HEEx template for the filter input
  """
  @callback render(column(), filter_value(), theme(), map()) :: Phoenix.LiveView.Rendered.t()

  @doc """
  Processes raw form input into structured filter value.

  ## Parameters
  - `raw_value` - Raw value from form submission
  - `column` - Column definition with filter configuration

  ## Returns
  Structured filter value or nil if invalid
  """
  @callback process(String.t() | [String.t()], column()) :: filter_value()

  @doc """
  Validates a filter value for this filter type.

  ## Parameters
  - `value` - Filter value to validate

  ## Returns
  Boolean indicating if value is valid
  """
  @callback validate(filter_value()) :: boolean()

  @doc """
  Returns default options for this filter type.

  ## Returns
  Keyword list of default filter options
  """
  @callback default_options() :: filter_options()

  @doc """
  Checks if a filter value is considered empty/inactive.

  ## Parameters
  - `value` - Filter value to check

  ## Returns
  Boolean indicating if the filter should be considered inactive
  """
  @callback empty?(filter_value()) :: boolean()

  @doc """
  Builds query filters for this filter type.

  ## Parameters
  - `query` - The Ash query to modify
  - `field` - The field name being filtered
  - `filter_value` - The processed filter value

  ## Returns
  Modified Ash query with the filter applied
  """
  @callback build_query(Ash.Query.t(), String.t(), filter_value()) :: Ash.Query.t()

  # Shared utility functions

  @doc """
  Checks if a filter has a meaningful value across all filter types.
  """
  def has_filter_value?(value) do
    case value do
      "" -> false
      nil -> false
      "all" -> false
      [] -> false
      %{from: "", to: ""} -> false
      %{min: "", max: ""} -> false
      %{from: nil, to: nil} -> false
      %{min: nil, max: nil} -> false
      _ -> true
    end
  end

  @doc """
  Converts a key to human readable string.
  """
  def humanize_key(key) do
    key
    |> to_string()
    |> String.replace("_", " ")
    |> String.split(" ")
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end

  @doc """
  Converts an atom to human readable string.
  """
  def humanize_atom(atom) do
    atom
    |> to_string()
    |> String.replace("_", " ")
    |> String.split(" ")
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end

  @doc """
  Gets a nested value from filter options with a default.
  """
  def get_option(filter_options, path, default \\ nil) do
    get_in(filter_options, List.wrap(path)) || default
  end

  @doc """
  Merges default options with provided options.
  """
  def merge_options(defaults, provided) when is_list(defaults) and is_list(provided) do
    Keyword.merge(defaults, provided)
  end

  def merge_options(defaults, _provided) when is_list(defaults) do
    defaults
  end

  @doc """
  Generates a form field name for the given column key.
  """
  def field_name(column_key, suffix \\ nil) do
    case suffix do
      nil -> "filters[#{column_key}]"
      suffix -> "filters[#{column_key}_#{suffix}]"
    end
  end
end
