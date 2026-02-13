defmodule Cinder.Filters.RadioGroup do
  @moduledoc """
  Radio group filter implementation for Cinder tables.

  Provides filtering with radio button inputs for arbitrary mutually exclusive options.

  ## Usage

      <:col field="status" filter={[type: :radio_group, options: [{"Active", "active"}, {"Archived", "archived"}]]}>
        {item.status}
      </:col>

  ## Options

  - `options` - List of `{label, value}` tuples for radio buttons (required)
  """

  @behaviour Cinder.Filter
  use Phoenix.Component
  use Cinder.Messages

  import Cinder.Filter

  @impl true
  def render(column, current_value, theme, _assigns) do
    current_radio_value = current_value || ""
    filter_options = Map.get(column, :filter_options, [])
    options = get_option(filter_options, :options, [])

    assigns = %{
      column: column,
      current_radio_value: current_radio_value,
      options: options,
      theme: theme
    }

    ~H"""
    <div class={@theme.filter_radio_group_container_class} data-key="filter_radio_group_container_class">
      <.option
        :for={{label, value} <- @options}
        name={field_name(@column.field)}
        label={label}
        value={value}
        checked={@current_radio_value == value}
        theme={@theme}
      />
    </div>
    """
  end

  attr :name, :string, required: true
  attr :label, :string, required: true
  attr :value, :string, required: true
  attr :checked, :boolean, required: true
  attr :theme, :map, required: true

  defp option(assigns) do
    ~H"""
    <label class={@theme.filter_radio_group_option_class} data-key="filter_radio_group_option_class">
      <input
        type="radio"
        name={@name}
        value={@value}
        checked={@checked}
        class={@theme.filter_radio_group_radio_class}
        aria-label={@label}
        data-key="filter_radio_group_radio_class"
      />
      <span class={@theme.filter_radio_group_label_class} data-key="filter_radio_group_label_class">{@label}</span>
    </label>
    """
  end

  @impl true
  def process(raw_value, _column) when is_binary(raw_value) do
    trimmed = String.trim(raw_value)

    if trimmed == "" do
      nil
    else
      %{
        type: :radio_group,
        value: trimmed,
        operator: :equals
      }
    end
  end

  def process(_raw_value, _column), do: nil

  @impl true
  def validate(value) do
    case value do
      %{type: :radio_group, value: val, operator: :equals} when is_binary(val) and val != "" ->
        true

      _ ->
        false
    end
  end

  @impl true
  def default_options do
    [options: []]
  end

  @impl true
  def empty?(value) do
    case value do
      nil -> true
      "" -> true
      %{value: nil} -> true
      %{value: ""} -> true
      _ -> false
    end
  end

  @impl true
  def build_query(query, field, filter_value) do
    %{value: value} = filter_value

    Cinder.Filter.Helpers.build_ash_filter(query, field, value, :equals)
  end
end
