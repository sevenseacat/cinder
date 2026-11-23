defmodule Cinder.Test.TrackRange do
  @moduledoc """
  A custom range filter type, as the custom filters guide writes one: its form posts
  halves (`field_min`, `field_max`), and its value is a list.
  """
  use Cinder.Filter

  @impl true
  def render(column, _current_value, _theme, _assigns) do
    assigns = %{column: column}

    ~H"""
    <input name={field_name(@column.field, "min")} />
    <input name={field_name(@column.field, "max")} />
    """
  end

  @impl true
  def process(raw_value, _column) when is_binary(raw_value) do
    with [min, max] <- String.split(raw_value, ","),
         {min_val, ""} <- Integer.parse(min),
         {max_val, ""} <- Integer.parse(max),
         true <- min_val <= max_val do
      %{type: :track_range, value: [min_val, max_val], operator: :between}
    else
      _ -> nil
    end
  end

  def process(_raw_value, _column), do: nil

  @impl true
  def validate(_value), do: true

  @impl true
  def default_options, do: []

  @impl true
  def empty?(value), do: is_nil(value)

  @impl true
  def build_query(query, field, %{value: [min, max]}) do
    field = String.to_existing_atom(field)
    Ash.Query.filter(query, ^ref(field) >= ^min and ^ref(field) <= ^max)
  end
end
