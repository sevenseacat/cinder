defmodule Cinder.Filters.NumberRange do
  @moduledoc """
  Number range filter implementation for Cinder tables.

  Provides numeric range filtering with min/max number inputs.
  """

  @behaviour Cinder.Filters.Base
  use Phoenix.Component

  import Cinder.Filters.Base

  @impl true
  def render(column, current_value, theme, _assigns) do
    min_value = get_in(current_value, [:min]) || ""
    max_value = get_in(current_value, [:max]) || ""

    assigns = %{
      column: column,
      min_value: min_value,
      max_value: max_value,
      theme: theme
    }

    ~H"""
    <div class="flex space-x-2">
      <div class="flex-1">
        <input
          type="number"
          name={field_name(@column.key, "min")}
          value={@min_value}
          placeholder="Min"
          phx-debounce="300"
          class={@theme.filter_number_input_class}
        />
      </div>
      <div class="flex-1">
        <input
          type="number"
          name={field_name(@column.key, "max")}
          value={@max_value}
          placeholder="Max"
          phx-debounce="300"
          class={@theme.filter_number_input_class}
        />
      </div>
    </div>
    """
  end

  @impl true
  def process(raw_value, _column) when is_binary(raw_value) do
    # Handle comma-separated values from form processing
    case String.split(raw_value, ",", parts: 2) do
      [min, max] ->
        min_trimmed = String.trim(min)
        max_trimmed = String.trim(max)

        if min_trimmed == "" and max_trimmed == "" do
          nil
        else
          %{
            type: :number_range,
            value: %{min: min_trimmed, max: max_trimmed},
            operator: :between
          }
        end

      [single] ->
        trimmed = String.trim(single)

        if trimmed == "" do
          nil
        else
          %{
            type: :number_range,
            value: %{min: trimmed, max: ""},
            operator: :between
          }
        end

      _ ->
        nil
    end
  end

  def process(%{min: min, max: max}, _column) do
    min_trimmed = String.trim(min || "")
    max_trimmed = String.trim(max || "")

    if min_trimmed == "" and max_trimmed == "" do
      nil
    else
      %{
        type: :number_range,
        value: %{min: min_trimmed, max: max_trimmed},
        operator: :between
      }
    end
  end

  def process(_raw_value, _column), do: nil

  @impl true
  def validate(value) do
    case value do
      %{type: :number_range, value: %{min: min, max: max}, operator: :between} ->
        valid_number?(min) and valid_number?(max)

      _ ->
        false
    end
  end

  @impl true
  def default_options do
    [
      step: 1,
      min: nil,
      max: nil
    ]
  end

  @impl true
  def empty?(value) do
    case value do
      nil -> true
      %{value: %{min: "", max: ""}} -> true
      %{value: %{min: nil, max: nil}} -> true
      %{min: "", max: ""} -> true
      %{min: nil, max: nil} -> true
      _ -> false
    end
  end

  # Private helper functions

  defp valid_number?(""), do: true
  defp valid_number?(nil), do: true

  defp valid_number?(number_string) when is_binary(number_string) do
    case Float.parse(number_string) do
      {_number, ""} -> true
      {_number, _remainder} -> false
      :error -> false
    end
  end

  defp valid_number?(_), do: false
end
