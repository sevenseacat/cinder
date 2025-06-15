defmodule Cinder.Filters.DateRange do
  @moduledoc """
  Date range filter implementation for Cinder tables.

  Provides date range filtering with from/to date inputs.
  """

  @behaviour Cinder.Filter
  use Phoenix.Component

  require Ash.Query
  import Ash.Expr
  import Cinder.Filter

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
          name={field_name(@column.field, "from")}
          value={@from_value}
          placeholder="From"
          class={@theme.filter_date_input_class}
        />
      </div>
      <div class={@theme.filter_range_separator_class}>
        to
      </div>
      <div class={@theme.filter_range_input_group_class}>
        <input
          type="date"
          name={field_name(@column.field, "to")}
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

  @impl true
  def build_query(query, field, filter_value) do
    %{type: :date_range, value: %{from: from, to: to}} = filter_value

    # Handle relationship fields using dot notation
    if String.contains?(field, ".") do
      # Build the path as a list of atoms for Ash filtering
      path_atoms = field |> String.split(".") |> Enum.map(&String.to_atom/1)

      # Handle any relationship path length: user.name, user.department.name, etc.
      {rel_path, [field_atom]} = Enum.split(path_atoms, -1)

      case {from, to} do
        {from_val, to_val} when from_val != "" and to_val != "" ->
          Ash.Query.filter(
            query,
            exists(^rel_path, ^ref(field_atom) >= ^from_val and ^ref(field_atom) <= ^to_val)
          )

        {from_val, ""} when from_val != "" ->
          Ash.Query.filter(query, exists(^rel_path, ^ref(field_atom) >= ^from_val))

        {"", to_val} when to_val != "" ->
          Ash.Query.filter(query, exists(^rel_path, ^ref(field_atom) <= ^to_val))

        _ ->
          query
      end
    else
      # Direct field filtering
      field_atom = String.to_atom(field)

      case {from, to} do
        {from_val, to_val} when from_val != "" and to_val != "" ->
          Ash.Query.filter(query, ^ref(field_atom) >= ^from_val and ^ref(field_atom) <= ^to_val)

        {from_val, ""} when from_val != "" ->
          Ash.Query.filter(query, ^ref(field_atom) >= ^from_val)

        {"", to_val} when to_val != "" ->
          Ash.Query.filter(query, ^ref(field_atom) <= ^to_val)

        _ ->
          query
      end
    end
  end
end
