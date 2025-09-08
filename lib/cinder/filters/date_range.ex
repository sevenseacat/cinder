defmodule Cinder.Filters.DateRange do
  @moduledoc """
  Date range filter implementation for Cinder tables.

  Provides date range filtering with from/to date inputs.
  Supports both date-only and datetime filtering via the `include_time` option.
  """

  @behaviour Cinder.Filter
  use Phoenix.Component

  require Ash.Query
  import Cinder.Filter
  alias Cinder.Messages

  @impl true
  def render(column, current_value, theme, _assigns) do
    from_value = get_in(current_value, [:from]) || ""
    to_value = get_in(current_value, [:to]) || ""

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
      theme: theme
    }

    ~H"""
    <div class={@theme.filter_range_container_class} {@theme.filter_range_container_data}>
      <div class={@theme.filter_range_input_group_class} {@theme.filter_range_input_group_data}>
        <input
          type={@input_type}
          name={field_name(@column.field, "from")}
          value={@from_value}
          placeholder="From"
          class={@theme.filter_date_input_class}
          {@theme.filter_date_input_data}
        />
      </div>
      <div class={@theme.filter_range_separator_class} {@theme.filter_range_separator_data}>
        {Messages.dgettext("cinder", "to")}
      </div>
      <div class={@theme.filter_range_input_group_class} {@theme.filter_range_input_group_data}>
        <input
          type={@input_type}
          name={field_name(@column.field, "to")}
          value={@to_value}
          placeholder="To"
          class={@theme.filter_date_input_class}
          {@theme.filter_date_input_data}
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
        valid_date_or_datetime?(from) and valid_date_or_datetime?(to)

      _ ->
        false
    end
  end

  @impl true
  def default_options do
    [
      format: :date,
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
  defp valid_date?(nil), do: true

  defp valid_date?(date_string) when is_binary(date_string) do
    case Date.from_iso8601(date_string) do
      {:ok, _date} -> true
      {:error, _} -> false
    end
  end

  defp valid_date?(_), do: false

  # Validate both date and datetime formats
  defp valid_date_or_datetime?(""), do: true
  defp valid_date_or_datetime?(nil), do: true

  defp valid_date_or_datetime?(value) when is_binary(value) do
    cond do
      # Try datetime first (ISO8601 with T)
      String.contains?(value, "T") ->
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

      # Try date format
      true ->
        valid_date?(value)
    end
  end

  defp valid_date_or_datetime?(_), do: false

  # Format value for HTML input display
  defp format_value_for_input("", _include_time), do: ""
  defp format_value_for_input(nil, _include_time), do: ""

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

  # Get the resource from the query to detect field types
  defp get_resource(query) do
    case query do
      %Ash.Query{resource: resource} -> resource
      _ -> nil
    end
  end

  # Get field type from resource
  defp get_field_type(resource, field) when is_atom(resource) and is_atom(field) do
    case Ash.Resource.Info.attribute(resource, field) do
      %{type: Ash.Type.Date} -> :date
      %{type: Ash.Type.NaiveDatetime} -> :naive_datetime
      %{type: Ash.Type.UtcDatetime} -> :utc_datetime
      _ -> :unknown
    end
  end

  defp get_field_type(_, _), do: :unknown

  # Convert date string to datetime string for NaiveDatetime fields
  defp convert_date_for_field(value, _field_type) when value in ["", nil], do: value

  defp convert_date_for_field(value, :naive_datetime) when is_binary(value) do
    cond do
      # Already a datetime string
      String.contains?(value, "T") ->
        value

      # Date string - convert to datetime
      String.match?(value, ~r/^\d{4}-\d{2}-\d{2}$/) ->
        "#{value}T00:00:00"

      # Unknown format
      true ->
        value
    end
  end

  defp convert_date_for_field(value, _field_type), do: value

  # Convert date string to end-of-day datetime for range end values
  defp convert_date_for_field_end(value, _field_type) when value in ["", nil], do: value

  defp convert_date_for_field_end(value, :naive_datetime) when is_binary(value) do
    cond do
      # Already a datetime string
      String.contains?(value, "T") ->
        value

      # Date string - convert to end of day datetime
      String.match?(value, ~r/^\d{4}-\d{2}-\d{2}$/) ->
        "#{value}T23:59:59"

      # Unknown format
      true ->
        value
    end
  end

  defp convert_date_for_field_end(value, _field_type), do: value

  @impl true
  def build_query(query, field, filter_value) do
    %{value: %{from: from, to: to}} = filter_value

    # Get resource and field type for proper conversion
    resource = get_resource(query)

    # For embedded fields, we need to handle field type detection differently
    field_type =
      case Cinder.Filter.Helpers.parse_field_notation(field) do
        {:direct, field_name} ->
          field_atom = String.to_atom(field_name)
          get_field_type(resource, field_atom)

        {:relationship, _rel_path, field_name} ->
          field_atom = String.to_atom(field_name)
          get_field_type(resource, field_atom)

        {:embedded, _embed_field, _field_name} ->
          # For embedded fields, assume :naive_datetime for now
          # This could be enhanced with embedded field type detection
          :naive_datetime

        {:nested_embedded, _embed_field, _field_path} ->
          :naive_datetime

        {:relationship_embedded, _rel_path, _embed_field, _field_name} ->
          :naive_datetime

        {:relationship_nested_embedded, _rel_path, _embed_field, _field_path} ->
          :naive_datetime

        {:invalid, _} ->
          :date
      end

    # Convert values based on field type
    from_converted = convert_date_for_field(from, field_type)
    to_converted = convert_date_for_field_end(to, field_type)

    case {from_converted, to_converted} do
      {from_val, to_val} when from_val != "" and to_val != "" ->
        # Apply both from and to filters using the centralized helper
        query
        |> Cinder.Filter.Helpers.build_ash_filter(field, from_val, :greater_than_or_equal)
        |> Cinder.Filter.Helpers.build_ash_filter(field, to_val, :less_than_or_equal)

      {from_val, ""} when from_val != "" ->
        Cinder.Filter.Helpers.build_ash_filter(query, field, from_val, :greater_than_or_equal)

      {"", to_val} when to_val != "" ->
        Cinder.Filter.Helpers.build_ash_filter(query, field, to_val, :less_than_or_equal)

      _ ->
        query
    end
  end
end
