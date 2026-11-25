# SPDX-FileCopyrightText: 2025 Cinder contributors <https://github.com/sevenseacat/cinder/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Cinder.FilterManager do
  @moduledoc false
  # Coordinator for Cinder's filter system, delegating to each filter type's module.
  # Internal: the shell goes through `Cinder.Engine` and `Cinder.Params`.

  require Logger

  alias Cinder.Filters.Registry

  @doc """
  Processes filter parameters from form submission using modular filter system.
  """
  def process_filter_params(filter_params, columns) do
    # Ensure multi-select fields are included even when no checkboxes are selected
    complete_filter_params = Cinder.UrlManager.ensure_multiselect_fields(filter_params, columns)

    fields = filterable_fields(columns)

    Enum.reduce(complete_filter_params, %{}, fn {key, value}, acc ->
      case range_half(key, fields) do
        {field, low_key, high_key} ->
          Map.put(acc, field, combine_range(complete_filter_params, low_key, high_key))

        nil ->
          Map.put(acc, key, value)
      end
    end)
  end

  @doc false
  # The URL has a range as one param under its field (`price=6,11`); its halves are
  # form input only
  def drop_range_halves(params, columns) do
    fields = filterable_fields(columns)
    Map.reject(params, fn {key, _value} -> range_half(key, fields) end)
  end

  defp filterable_fields(columns) do
    for column <- columns, column.filterable, into: MapSet.new(), do: column.field
  end

  @range_suffixes [{"_from", "_to"}, {"_min", "_max"}]

  # Range filters post their halves as `field_from`/`field_to` or `field_min`/`field_max`
  # (and so do custom filters copied from the range templates, under their own type). A key
  # that is a field itself is never a half, so a text filter on `valid_to` stays as it is.
  defp range_half(key, fields) do
    if MapSet.member?(fields, key) do
      nil
    else
      Enum.find_value(@range_suffixes, fn {low, high} ->
        Enum.find_value([low, high], &range_field(key, &1, fields, low, high))
      end)
    end
  end

  defp range_field(key, suffix, fields, low, high) do
    field = String.replace_suffix(key, suffix, "")

    if field != key and MapSet.member?(fields, field) do
      {field, field <> low, field <> high}
    end
  end

  defp combine_range(params, low_key, high_key) do
    low = Map.get(params, low_key, "")
    high = Map.get(params, high_key, "")
    if low != "" or high != "", do: "#{low},#{high}", else: ""
  end

  @doc """
  Transforms form values into structured filter objects using modular filter system.
  """
  def params_to_filters(filter_params, columns) do
    processed_params = process_filter_params(filter_params, columns)

    columns
    |> Enum.filter(& &1.filterable)
    |> Enum.reduce(%{}, fn column, acc ->
      raw_value = Map.get(processed_params, column.field, "")

      # Special handling for checkbox filters: always process them,
      # even when empty, so unchecking clears the filter
      if column.filter_type == :checkbox do
        case process_filter_value(raw_value, column) do
          # When unchecked, exclude from filters (clears the filter)
          nil -> acc
          processed_filter -> Map.put(acc, column.field, processed_filter)
        end
      else
        # Standard handling for other filter types
        if has_filter_value?(raw_value) do
          case process_filter_value(raw_value, column) do
            nil -> acc
            processed_filter -> Map.put(acc, column.field, processed_filter)
          end
        else
          acc
        end
      end
    end)
  end

  @doc """
  Builds filter values map for form inputs using modular filter system.
  """
  def build_filter_values(filterable_columns, filters) do
    filterable_columns
    |> Enum.reduce(%{}, fn column, acc ->
      case Map.get(filters, column.field) do
        nil ->
          Map.put(acc, column.field, get_default_value(column.filter_type))

        filter ->
          formatted_value = format_filter_value(filter, column.filter_type)
          Map.put(acc, column.field, formatted_value)
      end
    end)
  end

  @doc """
  Checks if a filter has a meaningful value using modular system.
  """
  def has_filter_value?(value) do
    Cinder.Filter.has_filter_value?(value)
  end

  @doc """
  Processes raw filter value using the appropriate filter module.

  This function is public to enable comprehensive testing of custom filter processing.
  """
  def process_filter_value(raw_value, column) do
    # Use enhanced registry that includes custom filters
    filter_module = Registry.get_filter(column.filter_type)

    # A bug in a filter fails closed: no filter, rather than quietly a different one
    if filter_module do
      try do
        filter_module.process(raw_value, column)
      rescue
        error ->
          Logger.error(
            "Error processing filter value for custom filter :#{column.filter_type} " <>
              "on column '#{column.field}': #{inspect(error)}. Skipping it."
          )

          nil
      end
    else
      Logger.error(
        "No filter module for :#{column.filter_type} on column '#{column.field}'. Skipping it."
      )

      nil
    end
  end

  defp get_default_value(:date_range), do: %{from: "", to: ""}
  defp get_default_value(:number_range), do: %{min: "", max: ""}
  defp get_default_value(:multi_select), do: []
  defp get_default_value(:multi_checkboxes), do: []
  defp get_default_value(_), do: ""

  defp format_filter_value(filter, filter_type) do
    case {filter_type, filter} do
      {:date_range, %{value: %{from: from, to: to}}} ->
        %{from: from || "", to: to || ""}

      {:number_range, %{value: %{min: min, max: max}}} ->
        %{min: min || "", max: max || ""}

      {:multi_select, %{value: values}} when is_list(values) ->
        values

      {:multi_checkboxes, %{value: values}} when is_list(values) ->
        values

      {:boolean, %{value: true}} ->
        "true"

      {:boolean, %{value: false}} ->
        "false"

      {_, %{value: value}} ->
        value

      _ ->
        ""
    end
  end
end
