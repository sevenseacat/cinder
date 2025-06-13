defmodule Cinder.Filters.Select do
  @moduledoc """
  Select dropdown filter implementation for Cinder tables.

  Provides single-select filtering with configurable options and prompts.
  """

  @behaviour Cinder.Filters.Base
  use Phoenix.Component

  import Cinder.Filters.Base

  @impl true
  def render(column, current_value, theme, _assigns) do
    filter_options = Map.get(column, :filter_options, [])
    options = get_option(filter_options, :options, [])
    prompt = get_option(filter_options, :prompt, "All #{column.label}")

    assigns = %{
      column: column,
      current_value: current_value || "",
      options: options,
      prompt: prompt,
      theme: theme
    }

    ~H"""
    <select
      name={field_name(@column.key)}
      class={@theme.filter_select_input_class}
    >
      <option value="">{@prompt}</option>
      <option
        :for={{label, value} <- @options}
        value={to_string(value)}
        selected={to_string(value) == @current_value}
      >
        {label}
      </option>
    </select>
    """
  end

  @impl true
  def process(raw_value, _column) when is_binary(raw_value) do
    trimmed = String.trim(raw_value)

    if trimmed == "" or trimmed == "all" do
      nil
    else
      %{
        type: :select,
        value: trimmed,
        operator: :equals
      }
    end
  end

  def process(_raw_value, _column), do: nil

  @impl true
  def validate(value) do
    case value do
      %{type: :select, value: val, operator: :equals} when is_binary(val) ->
        val != ""

      _ ->
        false
    end
  end

  @impl true
  def default_options do
    [
      options: [],
      prompt: nil
    ]
  end

  @impl true
  def empty?(value) do
    case value do
      nil -> true
      "" -> true
      "all" -> true
      %{value: ""} -> true
      %{value: nil} -> true
      %{value: "all"} -> true
      _ -> false
    end
  end
end
