defmodule Cinder.Filters.Text do
  @moduledoc """
  Text filter implementation for Cinder tables.

  Provides text-based filtering with support for different operators
  like contains, equals, starts_with, etc.
  """

  @behaviour Cinder.Filters.Base
  use Phoenix.Component

  import Cinder.Filters.Base

  @impl true
  def render(column, current_value, theme, _assigns) do
    placeholder = get_option(column.filter_options, :placeholder, "Filter #{column.label}...")

    assigns = %{
      column: column,
      current_value: current_value || "",
      placeholder: placeholder,
      theme: theme
    }

    ~H"""
    <input
      type="text"
      name={field_name(@column.key)}
      value={@current_value}
      placeholder={@placeholder}
      phx-debounce="300"
      class={@theme.filter_text_input_class}
    />
    """
  end

  @impl true
  def process(raw_value, column) when is_binary(raw_value) do
    trimmed = String.trim(raw_value)

    if trimmed == "" do
      nil
    else
      operator = get_option(column.filter_options, :operator, :contains)
      case_sensitive = get_option(column.filter_options, :case_sensitive, false)

      %{
        type: :text,
        value: trimmed,
        operator: operator,
        case_sensitive: case_sensitive
      }
    end
  end

  def process(_raw_value, _column), do: nil

  @impl true
  def validate(value) do
    case value do
      %{type: :text, value: val, operator: op} when is_binary(val) and is_atom(op) ->
        op in [:contains, :equals, :starts_with, :ends_with, :not_contains, :not_equals]

      _ ->
        false
    end
  end

  @impl true
  def default_options do
    [
      operator: :contains,
      case_sensitive: false,
      placeholder: nil
    ]
  end

  @impl true
  def empty?(value) do
    case value do
      nil -> true
      "" -> true
      %{value: ""} -> true
      %{value: nil} -> true
      _ -> false
    end
  end
end
