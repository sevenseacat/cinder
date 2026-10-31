# SPDX-FileCopyrightText: 2026 Cinder contributors <https://github.com/sevenseacat/cinder/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Cinder.Filters.Date do
  @moduledoc """
  Single date filter implementation for Cinder tables.

  Renders a single date input and matches a single calendar date. For `:date`
  fields it matches exactly; for datetime fields it matches the whole day.
  """

  @behaviour Cinder.Filter
  use Phoenix.Component

  import Cinder.Filter, only: [field_name: 1, filter_id: 2]
  use Cinder.Messages

  alias Cinder.Filter.Helpers

  @impl true
  def render(column, current_value, theme, assigns) do
    value = format_value_for_input(current_value)
    table_id = Map.get(assigns, :table_id)

    assigns = %{
      column: column,
      value: value,
      theme: theme,
      input_id: table_id && filter_id(table_id, column.field)
    }

    ~H"""
    <input
      type="date"
      id={@input_id}
      name={field_name(@column.field)}
      value={@value}
      class={@theme.filter_date_input_class}
      data-key="filter_date_input_class"
    />
    """
  end

  @impl true
  def process(value, _column) when is_binary(value) do
    trimmed = String.trim(value)

    # Anything that isn't a date (from a hand-edited URL, say) is no filter, rather
    # than a value the data layer would reject
    if valid_date?(trimmed), do: build(trimmed)
  end

  def process(_value, _column), do: nil

  defp build(value), do: %{type: :date, value: value, operator: :equals}

  @impl true
  def validate(%{type: :date, value: value, operator: :equals}), do: valid_date?(value)
  def validate(_), do: false

  @impl true
  def default_options, do: []

  @impl true
  def empty?(nil), do: true
  def empty?(%{value: ""}), do: true
  def empty?(%{value: nil}), do: true
  def empty?(_), do: false

  @impl true
  def build_query(query, field, %{value: value}) when value not in ["", nil] do
    case Date.from_iso8601(value) do
      {:ok, date} -> Helpers.build_date_filter(query, field, date, date)
      {:error, _} -> query
    end
  end

  def build_query(query, _field, _filter_value), do: query

  defp format_value_for_input(value) when is_binary(value), do: value
  defp format_value_for_input(_), do: ""

  defp valid_date?(value) when is_binary(value) do
    match?({:ok, _}, Date.from_iso8601(value))
  end

  defp valid_date?(_), do: false
end
