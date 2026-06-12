defmodule Cinder.Filters.Date do
  @moduledoc """
  Single date filter implementation for Cinder tables.

  Renders a single date input and matches a single calendar date. For `:date`
  fields it matches exactly; for datetime fields it matches the whole day.

  Supports a `default:` option (a `%Date{}` or ISO date string) which seeds the
  filter on first load and is restored when the clear button is pressed.
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
    <div class={@theme.filter_range_container_class} data-key="filter_range_container_class">
      <div class={@theme.filter_range_input_group_class} data-key="filter_range_input_group_class">
        <input
          type="date"
          id={@input_id}
          name={field_name(@column.field)}
          value={@value}
          class={@theme.filter_date_input_class}
          data-key="filter_date_input_class"
        />
      </div>
    </div>
    """
  end

  @impl true
  def process(%Date{} = date, _column), do: build(Date.to_iso8601(date))

  def process(value, _column) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      trimmed -> build(trimmed)
    end
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
    case field_type(query, field) do
      type when type in [:naive_datetime, :utc_datetime] ->
        query
        |> Helpers.build_ash_filter(field, "#{value}T00:00:00", :greater_than_or_equal)
        |> Helpers.build_ash_filter(field, "#{value}T23:59:59", :less_than_or_equal)

      _ ->
        Helpers.build_ash_filter(query, field, value, :equals)
    end
  end

  def build_query(query, _field, _filter_value), do: query

  defp format_value_for_input(%Date{} = date), do: Date.to_iso8601(date)
  defp format_value_for_input(value) when is_binary(value), do: value
  defp format_value_for_input(_), do: ""

  defp valid_date?(value) when is_binary(value) do
    match?({:ok, _}, Date.from_iso8601(value))
  end

  defp valid_date?(_), do: false

  defp field_type(query, field) do
    resource =
      case query do
        %Ash.Query{resource: resource} -> resource
        _ -> nil
      end

    case Helpers.parse_field_notation(field) do
      {:direct, field_name} ->
        attribute_type(resource, String.to_atom(field_name))

      {:relationship, _rel_path, field_name} ->
        attribute_type(resource, String.to_atom(field_name))

      _ ->
        :naive_datetime
    end
  end

  defp attribute_type(resource, field) when is_atom(resource) and is_atom(field) do
    case Ash.Resource.Info.attribute(resource, field) do
      %{type: Ash.Type.Date} -> :date
      %{type: Ash.Type.NaiveDatetime} -> :naive_datetime
      %{type: Ash.Type.UtcDatetime} -> :utc_datetime
      %{type: Ash.Type.UtcDatetimeUsec} -> :utc_datetime
      %{type: Ash.Type.DateTime} -> :utc_datetime
      _ -> :unknown
    end
  end

  defp attribute_type(_, _), do: :unknown
end
