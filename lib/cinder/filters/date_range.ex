defmodule Cinder.Filters.DateRange do
  @moduledoc """
  Date range filter implementation for Cinder tables.

  Provides date range filtering with from/to date inputs.
  """

  @behaviour Cinder.Filters.Base
  use Phoenix.Component

  import Cinder.Filters.Base

  @impl true
  def render(column, current_value, theme, _assigns) do
    from_value = get_in(current_value, [:from]) || ""
    to_value = get_in(current_value, [:to]) || ""

    assigns = %{
      column: column,
      from_value: from_value,
      to_value: to_value,
      theme: theme
    }

    ~H"""
    <div class={@theme.filter_range_container_class}>
      <div class={@theme.filter_range_input_group_class}>
        <input
          type="date"
          name={field_name(@column.key, "from")}
          value={@from_value}
          placeholder="From"
          class={@theme.filter_date_input_class}
        />
      </div>
      <div class={@theme.filter_range_input_group_class}>
        <input
          type="date"
          name={field_name(@column.key, "to")}
          value={@to_value}
          placeholder="To"
          class={@theme.filter_date_input_class}
        />
      </div>
    </div>
    """
  end

  @impl true
  def process(raw_value, _column) when is_binary(raw_value) do
    # Handle comma-separated values from form processing
    case String.split(raw_value, ",", parts: 2) do
      [from, to] ->
        from_trimmed = String.trim(from)
        to_trimmed = String.trim(to)

        if from_trimmed == "" and to_trimmed == "" do
          nil
        else
          %{
            type: :date_range,
            value: %{from: from_trimmed, to: to_trimmed},
            operator: :between
          }
        end

      [single] ->
        trimmed = String.trim(single)

        if trimmed == "" do
          nil
        else
          %{
            type: :date_range,
            value: %{from: trimmed, to: ""},
            operator: :between
          }
        end

      _ ->
        nil
    end
  end

  def process(%{from: from, to: to}, _column) do
    from_trimmed = String.trim(from || "")
    to_trimmed = String.trim(to || "")

    if from_trimmed == "" and to_trimmed == "" do
      nil
    else
      %{
        type: :date_range,
        value: %{from: from_trimmed, to: to_trimmed},
        operator: :between
      }
    end
  end

  def process(_raw_value, _column), do: nil

  @impl true
  def validate(value) do
    case value do
      %{type: :date_range, value: %{from: from, to: to}, operator: :between} ->
        valid_date?(from) and valid_date?(to)

      _ ->
        false
    end
  end

  @impl true
  def default_options do
    [
      format: :date
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
  defp valid_date?(nil), do: true

  defp valid_date?(date_string) when is_binary(date_string) do
    case Date.from_iso8601(date_string) do
      {:ok, _date} -> true
      {:error, _} -> false
    end
  end

  defp valid_date?(_), do: false
end
