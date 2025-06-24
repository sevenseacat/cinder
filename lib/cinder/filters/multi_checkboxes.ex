defmodule Cinder.Filters.MultiCheckboxes do
  @moduledoc """
  Multi-checkbox filter implementation for Cinder tables.

  Provides multiple selection filtering with checkbox inputs for each option.
  This is the traditional checkbox-based interface for selecting multiple values.
  """

  @behaviour Cinder.Filter
  use Phoenix.Component

  require Ash.Query
  import Cinder.Filter

  @impl true
  def render(column, current_value, theme, _assigns) do
    filter_options = Map.get(column, :filter_options, [])
    options = get_option(filter_options, :options, [])
    selected_values = current_value || []

    assigns = %{
      column: column,
      selected_values: selected_values,
      options: options,
      theme: theme
    }

    ~H"""
    <div class={@theme.filter_multicheckboxes_container_class} {@theme.filter_multicheckboxes_container_data}>
      <div :for={{label, value} <- @options} class={@theme.filter_multicheckboxes_option_class} {@theme.filter_multicheckboxes_option_data}>
        <input
          type="checkbox"
          name={field_name(@column.field) <> "[]"}
          value={to_string(value)}
          checked={to_string(value) in Enum.map(@selected_values, &to_string/1)}
          class={@theme.filter_multicheckboxes_checkbox_class}
          {@theme.filter_multicheckboxes_checkbox_data}
        />
        <label class={@theme.filter_multicheckboxes_label_class} {@theme.filter_multicheckboxes_label_data}>{label}</label>
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
        type: :multi_checkboxes,
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
      %{type: :multi_checkboxes, value: vals, operator: :in} when is_list(vals) ->
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

  @impl true
  def build_query(query, field, filter_value) do
    %{value: values} = filter_value

    # Use the centralized helper which supports direct, relationship, and embedded fields
    Cinder.Filter.Helpers.build_ash_filter(query, field, values, :in)
  end
end
