defmodule Cinder.Filters.Text do
  @moduledoc """
  Text filter implementation for Cinder tables.

  Provides text-based filtering with support for different operators
  like contains, equals, starts_with, etc.
  """

  @behaviour Cinder.Filter
  use Phoenix.Component

  require Ash.Query
  import Ash.Expr
  import Cinder.Filter

  @impl true
  def render(column, current_value, theme, _assigns) do
    filter_options = Map.get(column, :filter_options, [])
    placeholder = get_option(filter_options, :placeholder, "Filter #{column.label}...")

    assigns = %{
      column: column,
      current_value: current_value || "",
      placeholder: placeholder,
      theme: theme
    }

    ~H"""
    <input
      type="text"
      name={field_name(@column.field)}
      value={@current_value}
      placeholder={@placeholder}
      phx-debounce="300"
      class={@theme.filter_text_input_class}
      {@theme.filter_text_input_data}
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

    # Handle relationship fields using dot notation
    if String.contains?(field, ".") do
      # Build the path as a list of atoms for Ash filtering
      path_atoms = field |> String.split(".") |> Enum.map(&String.to_atom/1)

      # Handle any relationship path length: user.name, user.department.name, etc.
      {rel_path, [field_atom]} = Enum.split(path_atoms, -1)
      search_value = if case_sensitive, do: value, else: Ash.CiString.new(value)

      case operator do
        :contains ->
          Ash.Query.filter(
            query,
            exists(^rel_path, contains(^ref(field_atom), ^search_value))
          )

        :equals ->
          Ash.Query.filter(query, exists(^rel_path, ^ref(field_atom) == ^search_value))

        :starts_with ->
          Ash.Query.filter(
            query,
            exists(^rel_path, contains(^ref(field_atom), ^search_value))
          )

        _ ->
          query
      end
    else
      # Direct field filtering
      field_atom = String.to_atom(field)
      search_value = if case_sensitive, do: value, else: Ash.CiString.new(value)

      case operator do
        :contains ->
          Ash.Query.filter(query, contains(^ref(field_atom), ^search_value))

        :equals ->
          Ash.Query.filter(query, ^ref(field_atom) == ^search_value)

        :starts_with ->
          Ash.Query.filter(query, contains(^ref(field_atom), ^search_value))

        _ ->
          query
      end
    end
  end
end
