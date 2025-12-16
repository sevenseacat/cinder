defmodule Cinder.Filters.Registry do
  @moduledoc """
  Registry for managing available filter types in Cinder.

  Provides centralized registration and discovery of filter implementations,
  along with default filter type inference based on data types.
  """

  @doc """
  Returns a map of all registered filter types to their implementing modules.
  """
  def all_filters do
    %{
      text: Cinder.Filters.Text,
      select: Cinder.Filters.Select,
      multi_select: Cinder.Filters.MultiSelect,
      multi_checkboxes: Cinder.Filters.MultiCheckboxes,
      date_range: Cinder.Filters.DateRange,
      number_range: Cinder.Filters.NumberRange,
      boolean: Cinder.Filters.Boolean,
      checkbox: Cinder.Filters.Checkbox,
      autocomplete: Cinder.Filters.Autocomplete
    }
  end

  @doc """
  Gets the implementing module for a filter type.

  Checks both built-in and custom registered filters.

  ## Examples

      iex> Cinder.Filters.Registry.get_filter(:text)
      Cinder.Filters.Text

      iex> Cinder.Filters.Registry.get_filter(:slider)
      MyApp.Filters.Slider

      iex> Cinder.Filters.Registry.get_filter(:unknown)
      nil
  """
  def get_filter(filter_type) do
    Map.get(all_filters_with_custom(), filter_type)
  end

  @doc """
  Checks if a filter type is registered.

  Checks both built-in and custom registered filters.

  ## Examples

      iex> Cinder.Filters.Registry.registered?(:text)
      true

      iex> Cinder.Filters.Registry.registered?(:slider)
      true

      iex> Cinder.Filters.Registry.registered?(:unknown)
      false
  """
  def registered?(filter_type) do
    Map.has_key?(all_filters_with_custom(), filter_type)
  end

  @doc """
  Returns a list of all registered filter type atoms.

  ## Examples

      iex> Cinder.Filters.Registry.filter_types()
      [:text, :select, :multi_select, :multi_checkboxes, :date_range, :number_range, :boolean]
  """
  def filter_types do
    Map.keys(all_filters())
  end

  @doc """
  Infers the appropriate filter type based on Ash resource attribute.

  ## Parameters
  - `attribute` - Ash resource attribute definition
  - `column_key` - Column key for context

  ## Returns
  Atom representing the inferred filter type
  """
  def infer_filter_type(attribute, column_key \\ nil)

  def infer_filter_type(nil, _column_key), do: :text

  def infer_filter_type(%{type: type, constraints: constraints}, _column_key) do
    # Only check constraints for enum types
    if (is_map(constraints) and Map.has_key?(constraints, :one_of)) or
         (is_atom(type) and enum_type?(type)) do
      :select
    else
      infer_by_type(type)
    end
  end

  def infer_filter_type(%{type: type}, _column_key) do
    infer_by_type(type)
  end

  # Private helper to infer filter type based on just the type
  defp infer_by_type(type) do
    cond do
      # Array types
      match?({:array, _}, type) ->
        :multi_select

      # Date/time types
      type in [
        :date,
        :datetime,
        :utc_datetime,
        :utc_datetime_usec,
        :naive_datetime,
        :time,
        Ash.Type.Date,
        Ash.Type.Datetime,
        Ash.Type.DateTime,
        Ash.Type.UtcDatetime,
        Ash.Type.UtcDatetimeUsec,
        Ash.Type.NaiveDatetime,
        Ash.Type.Time
      ] ->
        :date_range

      # Boolean types
      type in [:boolean, Ash.Type.Boolean] ->
        :boolean

      # Numeric types
      type in [
        :integer,
        :decimal,
        :float,
        Ash.Type.Integer,
        Ash.Type.Decimal,
        Ash.Type.Float
      ] ->
        :number_range

      # String types
      type in [:string, Ash.Type.String] ->
        :text

      # Default fallback
      true ->
        :text
    end
  end

  @doc """
  Gets default filter options for a given filter type.

  ## Parameters
  - `filter_type` - Filter type atom
  - `column_key` - Column key for context (optional)

  ## Returns
  Keyword list of default options for the filter type
  """
  def default_options(filter_type, _column_key \\ nil) do
    case get_filter(filter_type) do
      nil -> []
      module -> module.default_options()
    end
  end

  @doc false
  # Internal function for manual filter registration.
  #
  # For new applications, use configuration-based registration instead:
  #
  #     config :cinder, :filters, %{
  #       slider: MyApp.Filters.Slider
  #     }
  #
  # Then call Cinder.setup() in your application startup.
  #
  # This function is kept for internal use and testing scenarios.
  def register_filter(filter_type, module) when is_atom(filter_type) and is_atom(module) do
    cond do
      # Prevent overriding built-in filter types
      Map.has_key?(all_filters(), filter_type) ->
        {:error, "Cannot override built-in filter type :#{filter_type}"}

      # Check if module exists
      not module_exists?(module) ->
        {:error, "Module #{inspect(module)} does not exist"}

      # Verify the module implements the behavior
      not behaviour_implemented?(module) ->
        {:error, "Module #{inspect(module)} does not implement Cinder.Filter behavior"}

      true ->
        # Just validate - no storage needed for config-only approach
        :ok
    end
  end

  # Internal function used by register_config_filters/0 to avoid
  # overriding runtime-registered filters.
  def register_config_filter(filter_type, module) when is_atom(filter_type) and is_atom(module) do
    register_filter(filter_type, module)
  end

  @doc false
  # Internal function for unregistering custom filters.
  # Mainly used for testing scenarios.
  def unregister_filter(filter_type) when is_atom(filter_type) do
    if builtin_filter?(filter_type) do
      {:error, "Cannot unregister built-in filter :#{filter_type}"}
    else
      :ok
    end
  end

  @doc """
  Lists all registered custom filter types.

  ## Returns
  Map of custom filter types to their implementing modules

  ## Examples

      iex> Cinder.Filters.Registry.list_custom_filters()
      %{slider: MyApp.Filters.Slider, color_picker: MyApp.Filters.ColorPicker}
  """
  def list_custom_filters do
    get_config_filters()
  end

  @doc """
  Checks if a filter type is a custom (user-registered) filter.

  ## Parameters
  - `filter_type` - Filter type atom to check

  ## Returns
  Boolean indicating if the filter type is custom

  ## Examples

      iex> Cinder.Filters.Registry.custom_filter?(:slider)
      true

      iex> Cinder.Filters.Registry.custom_filter?(:text)
      false
  """
  def custom_filter?(filter_type) do
    Map.has_key?(list_custom_filters(), filter_type)
  end

  @doc """
  Gets all filters including custom registered ones.

  Custom filters take precedence over built-in filters if there's a naming conflict
  (though registration prevents this from happening).

  ## Returns
  Map of all filter types to their implementing modules

  ## Examples

      iex> Cinder.Filters.Registry.all_filters_with_custom()
      %{
        text: Cinder.Filters.Text,
        select: Cinder.Filters.Select,
        slider: MyApp.Filters.Slider
      }
  """
  def all_filters_with_custom do
    config_filters = get_config_filters()

    all_filters()
    |> Map.merge(config_filters)
  end

  @doc """
  Validates that all registered custom filters are properly implemented.

  This function can be called at application startup to ensure all custom filters
  are valid and will work correctly.

  ## Returns
  :ok if all filters are valid, {:error, [reasons]} if any are invalid

  ## Examples

      iex> Cinder.Filters.Registry.validate_custom_filters()
      :ok

      iex> Cinder.Filters.Registry.validate_custom_filters()
      {:error, ["Module MyApp.Filters.BrokenSlider does not implement required function render/4"]}
  """
  def validate_custom_filters do
    custom_filters = list_custom_filters()

    errors =
      Enum.reduce(custom_filters, [], fn {filter_type, module}, acc ->
        cond do
          not module_exists?(module) ->
            ["Custom filter :#{filter_type} - Module #{inspect(module)} does not exist" | acc]

          not behaviour_implemented?(module) ->
            [
              "Custom filter :#{filter_type} - Module #{inspect(module)} does not implement Cinder.Filter behavior"
              | acc
            ]

          not all_callbacks_implemented?(module) ->
            missing = find_missing_callbacks(module)

            [
              "Custom filter :#{filter_type} - Module #{inspect(module)} is missing callbacks: #{Enum.join(missing, ", ")}"
              | acc
            ]

          true ->
            acc
        end
      end)

    case errors do
      [] -> :ok
      errors -> {:error, Enum.reverse(errors)}
    end
  end

  @doc """
  Registers custom filters from application configuration.

  This function should be called during application startup to register
  filters defined in config files.

  ## Configuration

      config :cinder, :filters, %{
        slider: MyApp.Filters.Slider,
        color_picker: MyApp.Filters.ColorPicker
      }

  ## Returns
  :ok if all filters registered successfully, {:error, [reasons]} if any failed
  """
  def register_config_filters do
    config_filters = get_config_filters()

    errors =
      Enum.reduce(config_filters, [], fn {filter_type, module}, acc ->
        case register_config_filter(filter_type, module) do
          :ok -> acc
          {:error, reason} -> ["#{filter_type}: #{reason}" | acc]
        end
      end)

    case errors do
      [] -> :ok
      errors -> {:error, Enum.reverse(errors)}
    end
  end

  # Private helper to get filters from configuration
  defp get_config_filters do
    Application.get_env(:cinder, :filters, [])
    |> Enum.into(%{})
  end

  # Private helper functions

  defp enum_type?(type) do
    try do
      case apply(type, :values, []) do
        values when is_list(values) -> true
        _ -> false
      end
    rescue
      _ -> false
    catch
      _ -> false
    end
  end

  defp module_exists?(module) do
    try do
      Code.ensure_loaded?(module)
    rescue
      _ -> false
    catch
      _ -> false
    end
  end

  defp behaviour_implemented?(module) do
    try do
      module.module_info(:attributes)
      |> Keyword.get(:behaviour, [])
      |> Enum.member?(Cinder.Filter)
    rescue
      _ -> false
    catch
      _ -> false
    end
  end

  defp all_callbacks_implemented?(module) do
    required_callbacks = [
      {:render, 4},
      {:process, 2},
      {:validate, 1},
      {:default_options, 0},
      {:empty?, 1}
    ]

    Enum.all?(required_callbacks, fn {func, arity} ->
      function_exported?(module, func, arity)
    end)
  end

  defp find_missing_callbacks(module) do
    required_callbacks = [
      {:render, 4},
      {:process, 2},
      {:validate, 1},
      {:default_options, 0},
      {:empty?, 1}
    ]

    required_callbacks
    |> Enum.reject(fn {func, arity} -> function_exported?(module, func, arity) end)
    |> Enum.map(fn {func, arity} -> "#{func}/#{arity}" end)
  end

  defp builtin_filter?(filter_type) do
    Map.has_key?(all_filters(), filter_type)
  end
end
