# SPDX-FileCopyrightText: 2025 Cinder contributors <https://github.com/sevenseacat/cinder/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Cinder.Filters.DateRange do
  @moduledoc """
  Date range filter implementation for Cinder tables.

  Provides date range filtering with from/to date inputs.
  Supports both date-only and datetime filtering via the `include_time` option.
  """

  @behaviour Cinder.Filter
  use Phoenix.Component

  import Cinder.Filter, only: [field_name: 2, filter_id: 3]
  use Cinder.Messages

  alias Cinder.Filter.Helpers

  @impl true
  def render(column, current_value, theme, assigns) do
    from_value = get_in(current_value, [:from]) || ""
    to_value = get_in(current_value, [:to]) || ""
    table_id = Map.get(assigns, :table_id)

    # Check for include_time option
    filter_options = Map.get(column, :filter_options, [])
    include_time = Keyword.get(filter_options, :include_time, false)
    input_type = if include_time, do: "datetime-local", else: "date"

    # Format values for the appropriate input type
    from_display = format_value_for_input(from_value, include_time)
    to_display = format_value_for_input(to_value, include_time)

    assigns = %{
      column: column,
      from_value: from_display,
      to_value: to_display,
      input_type: input_type,
      theme: theme,
      from_id: table_id && filter_id(table_id, column.field, "from"),
      to_id: table_id && filter_id(table_id, column.field, "to")
    }

    ~H"""
    <div class={@theme.filter_range_container_class} data-key="filter_range_container_class">
      <div class={@theme.filter_range_input_group_class} data-key="filter_range_input_group_class">
        <input
          type={@input_type}
          id={@from_id}
          name={field_name(@column.field, "from")}
          value={@from_value}
          placeholder={dgettext("cinder", "From")}
          class={@theme.filter_date_input_class}
          data-key="filter_date_input_class"
        />
      </div>
      <div class={@theme.filter_range_separator_class} data-key="filter_range_separator_class">
        {dgettext("cinder", "to")}
      </div>
      <div class={@theme.filter_range_input_group_class} data-key="filter_range_input_group_class">
        <input
          type={@input_type}
          id={@to_id}
          name={field_name(@column.field, "to")}
          value={@to_value}
          placeholder={dgettext("cinder", "To")}
          class={@theme.filter_date_input_class}
          data-key="filter_date_input_class"
        />
      </div>
    </div>
    """
  end

  @impl true
  def process(raw_value, column) when is_binary(raw_value) do
    # Comma-separated from URLs: "from,to", or a single "from"
    case String.split(raw_value, ",", parts: 2) do
      [from, to] -> process(%{from: from, to: to}, column)
      [from] -> process(%{from: from, to: ""}, column)
    end
  end

  # A bound that isn't a date or datetime (from a hand-edited URL, say) is dropped,
  # leaving the range open on that side, rather than reaching the data layer
  def process(%{from: from, to: to}, _column) do
    from = usable_bound(from)
    to = usable_bound(to)

    if from == "" and to == "" do
      nil
    else
      %{type: :date_range, value: %{from: from, to: to}, operator: :between}
    end
  end

  def process(_raw_value, _column), do: nil

  defp usable_bound(value) when is_binary(value) do
    trimmed = String.trim(value)
    if valid_date_or_datetime?(trimmed), do: trimmed, else: ""
  end

  defp usable_bound(_value), do: ""

  @impl true
  def validate(value) do
    case value do
      %{type: :date_range, value: %{from: from, to: to}, operator: :between} ->
        valid_date_or_datetime?(from) and valid_date_or_datetime?(to)

      _ ->
        false
    end
  end

  @impl true
  def default_options do
    [
      include_time: false
    ]
  end

  @impl true
  def empty?(value) do
    case value do
      nil -> true
      %{value: %{from: "", to: ""}} -> true
      %{value: %{from: nil, to: nil}} -> true
      %{from: "", to: ""} -> true
      %{from: nil, to: nil} -> true
      _ -> false
    end
  end

  # Private helper functions

  defp valid_date?(""), do: true

  defp valid_date?(date_string) when is_binary(date_string) do
    case Date.from_iso8601(date_string) do
      {:ok, _date} -> true
      {:error, _} -> false
    end
  end

  # Validate both date and datetime formats
  defp valid_date_or_datetime?(""), do: true
  defp valid_date_or_datetime?(nil), do: true

  defp valid_date_or_datetime?(value) when is_binary(value) do
    value = if Regex.match?(~r/T\d{2}:\d{2}$/, value), do: value <> ":00", else: value

    # Try datetime first (ISO8601 with T)
    if String.contains?(value, "T") do
      case DateTime.from_iso8601(value) do
        {:ok, _, _} ->
          true

        {:error, _} ->
          # Try NaiveDateTime if regular DateTime fails
          case NaiveDateTime.from_iso8601(value) do
            {:ok, _} -> true
            {:error, _} -> false
          end
      end
    else
      # Try date format
      valid_date?(value)
    end
  end

  # Format value for HTML input display
  defp format_value_for_input("", _include_time), do: ""

  defp format_value_for_input(value, true) when is_binary(value) do
    # For datetime-local inputs, ensure we have the right format
    cond do
      # Already in datetime format (YYYY-MM-DDTHH:MM or YYYY-MM-DDTHH:MM:SS)
      String.contains?(value, "T") ->
        # datetime-local inputs expect YYYY-MM-DDTHH:MM format
        case String.split(value, "T") do
          [date, time] ->
            # Trim seconds if present for datetime-local compatibility
            time_part = time |> String.split(":") |> Enum.take(2) |> Enum.join(":")
            "#{date}T#{time_part}"

          _ ->
            value
        end

      # Date only - convert to datetime for datetime-local input
      String.match?(value, ~r/^\d{4}-\d{2}-\d{2}$/) ->
        "#{value}T00:00"

      # Unknown format, return as-is
      true ->
        value
    end
  end

  defp format_value_for_input(value, false) when is_binary(value) do
    # For date inputs, extract just the date part if datetime is provided
    if String.contains?(value, "T") do
      value |> String.split("T") |> List.first()
    else
      value
    end
  end

  defp format_value_for_input(value, _), do: value

  @impl true
  def build_query(query, field, %{value: %{from: from, to: to}}) do
    Helpers.build_date_filter(query, field, bound(from), bound(to))
  end

  # A date-only bound covers that whole day; a bound with a time (from `include_time`) is
  # compared as given
  defp bound(value) when value in ["", nil], do: nil

  defp bound(value) do
    case Date.from_iso8601(value) do
      {:ok, date} -> date
      {:error, _} -> value
    end
  end
end
