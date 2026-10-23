defmodule Cinder.TestFilters.Slider do
  @moduledoc """
  A hand-written custom filter for the new shell (spike): at most a value, from a
  range input. Its view only adds to the generic input's attrs; its control shows
  the value beside the slider.
  """
  use Cinder.Filter

  @impl true
  def render(_column, _value, _theme, _assigns), do: raise("only written for the new shell")

  @impl true
  def options_schema do
    [
      min: [type: :integer, default: 0],
      max: [type: :integer, default: 100],
      step: [type: :pos_integer, default: 1]
    ]
  end

  @impl true
  def view(filter, ctx) do
    # Until it's been used, a slider sits at its maximum, which filters nothing
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
    <output for={@filter.input_attrs["id"]}>{@filter.value}</output>
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

defmodule Cinder.TestFilters.CustomSelect do
  @moduledoc """
  Shaped like `mix cinder.gen.filter ... --template=select` output: every callback
  delegates to the built-in it's based on, the new shell's included.
  """
  use Cinder.Filter

  @impl true
  def render(column, current_value, theme, assigns),
    do: Cinder.Filters.Select.render(column, current_value, theme, assigns)

  @impl true
  def process(raw_value, column) do
    case Cinder.Filters.Select.process(raw_value, column) do
      %{type: _old_type} = filter -> %{filter | type: :custom_select}
      result -> result
    end
  end

  @impl true
  def validate(filter_value), do: Cinder.Filters.Select.validate(filter_value)

  @impl true
  def default_options, do: Cinder.Filters.Select.default_options()

  @impl true
  def empty?(value), do: Cinder.Filters.Select.empty?(value)

  @impl true
  def build_query(query, field, filter_value),
    do: Cinder.Filters.Select.build_query(query, field, filter_value)

  @impl true
  def view(filter, ctx), do: Cinder.Filters.Select.view(filter, ctx)

  @impl true
  def control(assigns), do: Cinder.Filters.Select.control(assigns)
end

defmodule Cinder.TestFilters.Bare do
  @moduledoc "A custom filter with none of the new shell's callbacks: an exact title."
  use Cinder.Filter

  @impl true
  def render(_column, _value, _theme, _assigns), do: raise("only written for the new shell")

  @impl true
  def process(raw_value, _column) when raw_value not in [nil, ""],
    do: %{type: :bare, value: raw_value, operator: :equals}

  def process(_raw_value, _column), do: nil

  @impl true
  def validate(%{type: :bare}), do: true
  def validate(_value), do: false

  @impl true
  def default_options, do: []

  @impl true
  def empty?(value), do: value == nil

  @impl true
  def build_query(query, field, %{value: value}),
    do: Cinder.Filter.Helpers.build_ash_filter(query, field, value, :equals)
end
