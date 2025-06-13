defmodule Cinder.Filters.Boolean do
  @moduledoc """
  Boolean filter implementation for Cinder tables.

  Provides boolean filtering with radio button inputs for true/false/all options.
  """

  @behaviour Cinder.Filters.Base
  use Phoenix.Component

  import Cinder.Filters.Base

  @impl true
  def render(column, current_value, theme, _assigns) do
    current_boolean_value = current_value || ""
    filter_options = Map.get(column, :filter_options, [])
    options = get_option(filter_options, :labels, %{})

    all_label = Map.get(options, :all, "All")
    true_label = Map.get(options, true, "True")
    false_label = Map.get(options, false, "False")

    assigns = %{
      column: column,
      current_boolean_value: current_boolean_value,
      all_label: all_label,
      true_label: true_label,
      false_label: false_label,
      theme: theme
    }

    ~H"""
    <div class={@theme.filter_boolean_container_class}>
      <label class={@theme.filter_boolean_option_class}>
        <input
          type="radio"
          name={field_name(@column.field)}
          value=""
          checked={@current_boolean_value == "" || @current_boolean_value == "all"}
          class={@theme.filter_boolean_radio_class}
        />
        <span class={@theme.filter_boolean_label_class}>{@all_label}</span>
      </label>
      <label class={@theme.filter_boolean_option_class}>
        <input
          type="radio"
          name={field_name(@column.field)}
          value="true"
          checked={@current_boolean_value == "true"}
          class={@theme.filter_boolean_radio_class}
        />
        <span class={@theme.filter_boolean_label_class}>{@true_label}</span>
      </label>
      <label class={@theme.filter_boolean_option_class}>
        <input
          type="radio"
          name={field_name(@column.field)}
          value="false"
          checked={@current_boolean_value == "false"}
          class={@theme.filter_boolean_radio_class}
        />
        <span class={@theme.filter_boolean_label_class}>{@false_label}</span>
      </label>
    </div>
    """
  end

  @impl true
  def process(raw_value, _column) when is_binary(raw_value) do
    trimmed = String.trim(raw_value)

    case trimmed do
      "" ->
        nil

      "all" ->
        nil

      "true" ->
        %{
          type: :boolean,
          value: true,
          operator: :equals
        }

      "false" ->
        %{
          type: :boolean,
          value: false,
          operator: :equals
        }

      _ ->
        nil
    end
  end

  def process(_raw_value, _column), do: nil

  @impl true
  def validate(value) do
    case value do
      %{type: :boolean, value: val, operator: :equals} when is_boolean(val) ->
        true

      _ ->
        false
    end
  end

  @impl true
  def default_options do
    [
      labels: %{
        all: "All",
        true: "True",
        false: "False"
      }
    ]
  end

  @impl true
  def empty?(value) do
    case value do
      nil -> true
      "" -> true
      "all" -> true
      %{value: nil} -> true
      _ -> false
    end
  end
end
