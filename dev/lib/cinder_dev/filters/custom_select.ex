defmodule CinderDev.Filters.CustomSelect do
  @moduledoc """
  Custom Custom_select filter for Cinder tables.

  This filter is based on the built-in Cinder.Filters.Select filter.
  You can customize any of the callback functions to modify the behavior.

  ## Usage

  Use in table columns:

      <:col field="field_name" filter={:custom_select}>
        {item.field_name}
      </:col>

  ## Customization

  You can modify any of the callback functions below:
  - `render/4` - Customize the HTML rendering
  - `process/2` - Customize input processing
  - `validate/1` - Customize validation logic
  - `build_query/3` - Customize query building
  - `default_options/0` - Customize default options
  - `empty?/1` - Customize empty value detection

  ## Built-in Reference

  This filter uses the same structure as `Cinder.Filters.Select`.
  You can refer to that module's source code for implementation details.
  """

  use Cinder.Filter

  @impl true
  def render(column, current_value, theme, assigns) do
    Cinder.Filters.Select.render(column, current_value, theme, assigns)
  end

  @impl true
  def process(raw_value, column) do
    case Cinder.Filters.Select.process(raw_value, column) do
      %{type: _old_type} = filter -> %{filter | type: :custom_select}
      result -> result
    end
  end

  @impl true
  def validate(filter_value) do
    Cinder.Filters.Select.validate(filter_value)
  end

  @impl true
  def default_options do
    Cinder.Filters.Select.default_options()
  end

  @impl true
  def empty?(value) do
    Cinder.Filters.Select.empty?(value)
  end

  @impl true
  def build_query(query, field, filter_value) do
    Cinder.Filters.Select.build_query(query, field, filter_value)
  end

  @impl true
  def view(filter, ctx), do: Cinder.Filters.Select.view(filter, ctx)

  @impl true
  def control(assigns), do: Cinder.Filters.Select.control(assigns)

  # You can override any of the above functions to customize behavior
  # For example, to customize rendering:
  #
  # @impl true
  # def render(column, current_value, theme, assigns) do
  #   # Your custom rendering logic here
  # end
end
