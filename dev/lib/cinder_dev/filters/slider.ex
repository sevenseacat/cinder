defmodule CinderDev.Filters.Slider do
  @moduledoc """
  A hand-written custom filter for the new shell (spike): at most a value, from a
  range input. Its view only adds to the generic input's attrs; its control shows
  the value beside the slider. `render/4` is the current shell's, which this
  doesn't support.
  """
  use Cinder.Filter

  @impl true
  def render(_column, _value, _theme, _assigns), do: raise("only written for the new shell")

  @impl true
  def options_schema do
    [
      min: [type: :integer, default: 0, doc: "The slider's lowest value"],
      max: [type: :integer, default: 100, doc: "Its highest, which filters nothing"],
      step: [type: :pos_integer, default: 1]
    ]
  end

  @impl true
  def view(filter, ctx) do
    value = if filter.value == "", do: to_string(ctx.options[:max]), else: filter.value

    %{
      filter
      | value: value,
        input_attrs:
          Map.merge(filter.input_attrs, %{
            "type" => "range",
            "value" => value,
            "min" => ctx.options[:min],
            "max" => ctx.options[:max],
            "step" => ctx.options[:step]
          })
    }
  end

  @impl true
  def control(assigns) do
    ~H"""
    <input {@filter.input_attrs} />
    <output for={@filter.input_attrs["id"]}>≤ {@filter.value}</output>
    """
  end

  @impl true
  def process(raw_value, _column) when is_binary(raw_value) do
    case Integer.parse(raw_value) do
      {value, ""} -> %{type: :slider, value: value, operator: :less_than_or_equal}
      _other -> nil
    end
  end

  def process(_raw_value, _column), do: nil

  @impl true
  def validate(%{type: :slider, value: value}) when is_integer(value), do: true
  def validate(_value), do: false

  @impl true
  def default_options, do: [min: 0, max: 100, step: 1]

  @impl true
  def empty?(value), do: value in [nil, %{value: nil}]

  @impl true
  def build_query(query, field, %{value: value}) do
    Ash.Query.filter(query, ^ref(String.to_existing_atom(field)) <= ^value)
  end
end
