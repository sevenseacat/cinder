defmodule Cinder.Filter do
  @moduledoc """
  Base behavior for Cinder filter implementations.

  Defines the common interface that all filter types must implement,
  along with shared types and utility functions.

  ## Usage

  The most convenient way to create a custom filter is to use this module:

      defmodule MyApp.Filters.Slider do
        use Cinder.Filter

        @impl true
        def render(column, current_value, theme, assigns) do
          # Your filter rendering logic
        end

        # ... implement other required callbacks
      end

  This automatically:
  - Adds the `@behaviour Cinder.Filter` declaration
  - Imports Phoenix.Component for HEEx templates
  - Imports helper functions from this module
  - Registers the filter automatically if configured
  """

  @doc false
  defmacro __using__(opts) do
    filter_name = Keyword.get(opts, :name)

    quote do
      @behaviour Cinder.Filter
      use Phoenix.Component

      require Ash.Query
      import Ash.Expr
      import Cinder.Filter

      # Auto-register filter if name is provided and config exists
      if unquote(filter_name) do
        @after_compile {Cinder.Filter, :maybe_auto_register}
        @filter_name unquote(filter_name)
      end
    end
  end

  @doc false
  def maybe_auto_register(env, _bytecode) do
    if Module.get_attribute(env.module, :filter_name) do
      filter_name = Module.get_attribute(env.module, :filter_name)

      # Check if this filter is configured for auto-registration
      config_filters = Application.get_env(:cinder, :filters, %{})

      if Map.get(config_filters, filter_name) == env.module do
        case Cinder.Filters.Registry.register_filter(filter_name, env.module) do
          :ok ->
            :ok

          {:error, _reason} ->
            # Registration will be handled by register_config_filters/0
            :ok
        end
      end
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
