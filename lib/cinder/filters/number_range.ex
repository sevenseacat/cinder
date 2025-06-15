defmodule Cinder.Filters.NumberRange do
  @moduledoc """
  Number range filter implementation for Cinder tables.

  Provides numeric range filtering with min/max number inputs.
  """

  @behaviour Cinder.Filter
  use Phoenix.Component

  require Ash.Query
  import Ash.Expr
  import Cinder.Filter

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
    <div class={@theme.filter_range_container_class} {@theme.filter_range_container_data}>
      <div class={@theme.filter_range_input_group_class} {@theme.filter_range_input_group_data}>
        <input
          type="number"
          name={field_name(@column.field, "min")}
          value={@min_value}
          placeholder="Min"
          phx-debounce="300"
          class={@theme.filter_number_input_class}
          {@theme.filter_number_input_data}
        />
      </div>
      <div class={@theme.filter_range_separator_class} {@theme.filter_range_separator_data}>
        to
      </div>
      <div class={@theme.filter_range_input_group_class} {@theme.filter_range_input_group_data}>
        <input
          type="number"
          name={field_name(@column.field, "max")}
          value={@max_value}
          placeholder="Max"
          phx-debounce="300"
          class={@theme.filter_number_input_class}
          {@theme.filter_number_input_data}
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

  @impl true
  def build_query(query, field, filter_value) do
    %{type: :number_range, value: %{min: min, max: max}} = filter_value

    # Handle relationship fields using dot notation
    if String.contains?(field, ".") do
      # Build the path as a list of atoms for Ash filtering
      path_atoms = field |> String.split(".") |> Enum.map(&String.to_atom/1)

      # Handle any relationship path length: user.name, user.department.name, etc.
      {rel_path, [field_atom]} = Enum.split(path_atoms, -1)

      case {min, max} do
        {min_val, max_val} when min_val != "" and max_val != "" ->
          min_num = parse_number(min_val)
          max_num = parse_number(max_val)

          Ash.Query.filter(
            query,
            exists(^rel_path, ^ref(field_atom) >= ^min_num and ^ref(field_atom) <= ^max_num)
          )

        {min_val, ""} when min_val != "" ->
          min_num = parse_number(min_val)
          Ash.Query.filter(query, exists(^rel_path, ^ref(field_atom) >= ^min_num))

        {"", max_val} when max_val != "" ->
          max_num = parse_number(max_val)
          Ash.Query.filter(query, exists(^rel_path, ^ref(field_atom) <= ^max_num))

        _ ->
          query
      end
    else
      # Direct field filtering
      field_atom = String.to_atom(field)

      case {min, max} do
        {min_val, max_val} when min_val != "" and max_val != "" ->
          min_num = parse_number(min_val)
          max_num = parse_number(max_val)
          Ash.Query.filter(query, ^ref(field_atom) >= ^min_num and ^ref(field_atom) <= ^max_num)

        {min_val, ""} when min_val != "" ->
          min_num = parse_number(min_val)
          Ash.Query.filter(query, ^ref(field_atom) >= ^min_num)

        {"", max_val} when max_val != "" ->
          max_num = parse_number(max_val)
          Ash.Query.filter(query, ^ref(field_atom) <= ^max_num)

        _ ->
          query
      end
    end
  rescue
    ArgumentError ->
      # Invalid number format, skip filter
      query
  end

  # Helper function to parse numbers, trying integer first, then float
  defp parse_number(str) when is_binary(str) do
    case Integer.parse(str) do
      {int_val, ""} ->
        int_val

      _ ->
        case Float.parse(str) do
          {float_val, ""} -> float_val
          _ -> raise ArgumentError, "Invalid number format"
        end
    end
  end
end
