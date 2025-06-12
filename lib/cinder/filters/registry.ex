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
      date_range: Cinder.Filters.DateRange,
      number_range: Cinder.Filters.NumberRange,
      boolean: Cinder.Filters.Boolean
    }
  end

  @doc """
  Gets the implementing module for a filter type.

  ## Examples

      iex> Cinder.Filters.Registry.get_filter(:text)
      Cinder.Filters.Text

      iex> Cinder.Filters.Registry.get_filter(:unknown)
      nil
  """
  def get_filter(filter_type) do
    Map.get(all_filters(), filter_type)
  end

  @doc """
  Checks if a filter type is registered.

  ## Examples

      iex> Cinder.Filters.Registry.registered?(:text)
      true

      iex> Cinder.Filters.Registry.registered?(:unknown)
      false
  """
  def registered?(filter_type) do
    Map.has_key?(all_filters(), filter_type)
  end

  @doc """
  Returns a list of all registered filter type atoms.

  ## Examples

      iex> Cinder.Filters.Registry.filter_types()
      [:text, :select, :multi_select, :date_range, :number_range, :boolean]
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
    cond do
      # Handle constraint-based enums (new Ash format)
      is_map(constraints) and Map.has_key?(constraints, :one_of) ->
        :select

      # Handle Ash.Type.Enum types
      is_atom(type) and enum_type?(type) ->
        :select

      # Handle specific Ash types
      type == Ash.Type.Boolean ->
        :boolean

      type == Ash.Type.Date ->
        :date_range

      type in [Ash.Type.Integer, Ash.Type.Decimal, Ash.Type.Float] ->
        :number_range

      type == Ash.Type.String ->
        :text

      true ->
        :text
    end
  end

  def infer_filter_type(%{type: {:array, _inner_type}}, _column_key) do
    # Array types default to text for now
    # Could be extended to multi_select in the future
    :text
  end

  def infer_filter_type(%{type: {:one_of, _values}}, _column_key) do
    # Legacy enum format
    :select
  end

  def infer_filter_type(%{type: type}, _column_key) when type in [:boolean, Ash.Type.Boolean] do
    :boolean
  end

  def infer_filter_type(%{type: type}, _column_key) when type in [:date, Ash.Type.Date] do
    :date_range
  end

  def infer_filter_type(%{type: type}, _column_key)
      when type in [
             :integer,
             :decimal,
             :float,
             Ash.Type.Integer,
             Ash.Type.Decimal,
             Ash.Type.Float
           ] do
    :number_range
  end

  def infer_filter_type(%{type: type}, _column_key) when type in [:string, Ash.Type.String] do
    :text
  end

  def infer_filter_type(_attribute, _column_key) do
    :text
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

  @doc """
  Registers a custom filter type.

  ## Parameters
  - `filter_type` - Atom identifying the filter type
  - `module` - Module implementing the Cinder.Filters.Base behavior

  ## Returns
  :ok if successful, {:error, reason} if failed
  """
  def register_filter(filter_type, module) when is_atom(filter_type) and is_atom(module) do
    # Verify the module implements the behavior
    if behaviour_implemented?(module) do
      # Store in application environment for runtime registration
      existing = Application.get_env(:cinder, :custom_filters, %{})
      updated = Map.put(existing, filter_type, module)
      Application.put_env(:cinder, :custom_filters, updated)
      :ok
    else
      {:error, "Module #{module} does not implement Cinder.Filters.Base behavior"}
    end
  end

  @doc """
  Gets all filters including custom registered ones.
  """
  def all_filters_with_custom do
    custom_filters = Application.get_env(:cinder, :custom_filters, %{})
    Map.merge(all_filters(), custom_filters)
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

  defp behaviour_implemented?(module) do
    try do
      module.module_info(:attributes)
      |> Keyword.get(:behaviour, [])
      |> Enum.member?(Cinder.Filters.Base)
    rescue
      _ -> false
    catch
      _ -> false
    end
  end
end
