defmodule Cinder.Filters.MultiSelect do
  @moduledoc """
  Multi-select checkbox filter implementation for Cinder tables.

  Provides multiple selection filtering with checkbox inputs for each option.
  """

  @behaviour Cinder.Filters.Base
  use Phoenix.Component

  import Cinder.Filters.Base

  @impl true
  def render(column, current_value, theme, _assigns) do
    options = get_option(column.filter_options, :options, [])
    selected_values = current_value || []

    assigns = %{
      column: column,
      selected_values: selected_values,
      options: options,
      theme: theme
    }

    ~H"""
    <div class="space-y-2">
      <div :for={{label, value} <- @options} class="flex items-center space-x-2">
        <input
          type="checkbox"
          name={field_name(@column.key) <> "[]"}
          value={to_string(value)}
          checked={to_string(value) in Enum.map(@selected_values, &to_string/1)}
          class="mr-2"
        />
        <label class="text-sm">{label}</label>
      </div>
    </div>
    """
  end

  @impl true
  def process(raw_value, _column) when is_list(raw_value) do
    # Filter out empty values
    values = Enum.reject(raw_value, &(&1 == "" or is_nil(&1)))

    if Enum.empty?(values) do
      nil
    else
      %{
        type: :multi_select,
        value: values,
        operator: :in
      }
    end
  end

  def process(raw_value, column) when is_binary(raw_value) do
    # Handle single value as list
    process([raw_value], column)
  end

  def process(_raw_value, _column), do: nil

  @impl true
  def validate(value) do
    case value do
      %{type: :multi_select, value: vals, operator: :in} when is_list(vals) ->
        not Enum.empty?(vals) and Enum.all?(vals, &is_binary/1)

      _ ->
        false
    end
  end

  @impl true
  def default_options do
    [
      options: []
    ]
  end

  @impl true
  def empty?(value) do
    case value do
      nil -> true
      [] -> true
      %{value: []} -> true
      %{value: nil} -> true
      _ -> false
    end
  end
end
