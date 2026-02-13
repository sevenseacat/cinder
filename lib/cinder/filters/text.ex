defmodule Cinder.Filters.Text do
  @moduledoc """
  Text filter implementation for Cinder tables.

  Provides text-based filtering with support for different operators
  like contains, equals, starts_with, etc.
  """

  @behaviour Cinder.Filter
  use Phoenix.Component
  use Cinder.Messages

  import Cinder.Filter

  @impl true
  def render(column, current_value, theme, assigns) do
    filter_options = Map.get(column, :filter_options, [])

    default_placeholder = dgettext("cinder", "Filter %{label}...", label: column.label)
    placeholder = get_option(filter_options, :placeholder, default_placeholder)
    table_id = Map.get(assigns, :table_id)

    assigns = %{
      column: column,
      current_value: current_value || "",
      placeholder: placeholder,
      theme: theme,
      filter_id: table_id && filter_id(table_id, column.field)
    }

    ~H"""
    <input
      type="text"
      id={@filter_id}
      name={field_name(@column.field)}
      value={@current_value}
      placeholder={@placeholder}
      phx-debounce="300"
      class={@theme.filter_text_input_class}
      data-key="filter_text_input_class"
    />
    """
  end

  @impl true
  def process(raw_value, column) when is_binary(raw_value) do
    trimmed = String.trim(raw_value)

    if trimmed == "" do
      nil
    else
      filter_options = Map.get(column, :filter_options, [])
      operator = get_option(filter_options, :operator, :contains)
      case_sensitive = get_option(filter_options, :case_sensitive, false)

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

  @impl true
  def build_query(query, field, filter_value) do
    %{type: :text, value: value, operator: operator} = filter_value
    case_sensitive = Map.get(filter_value, :case_sensitive, false)

    # Use case-insensitive search unless explicitly set to case-sensitive
    search_value = if case_sensitive, do: value, else: Ash.CiString.new(value)

    # Use the centralized helper which supports direct, relationship, and embedded fields
    Cinder.Filter.Helpers.build_ash_filter(query, field, search_value, operator)
  end
end
