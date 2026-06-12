defmodule Cinder.Filters.Date do
  @moduledoc """
  Single date filter implementation for Cinder tables.

  Renders a single date input and matches a single calendar date. For `:date`
  fields it matches exactly; for datetime fields it matches the whole day.
  """

  @behaviour Cinder.Filter
  use Phoenix.Component

  import Cinder.Filter, only: [field_name: 1, filter_id: 2]
  use Cinder.Messages

  alias Cinder.Filter.Helpers

  @impl true
  def render(column, current_value, theme, assigns) do
    value = format_value_for_input(current_value)
    table_id = Map.get(assigns, :table_id)

    assigns = %{
      column: column,
      value: value,
      theme: theme,
      input_id: table_id && filter_id(table_id, column.field)
    }

    ~H"""
    <input
      type="date"
      id={@input_id}
      name={field_name(@column.field)}
      value={@value}
      class={@theme.filter_date_input_class}
      data-key="filter_date_input_class"
    />
    """
  end

  @impl true
  def process(value, _column) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      trimmed -> build(trimmed)
    end
  end

  def process(%Date{} = value, _column), do: build(Date.to_iso8601(value))

  def process(_value, _column), do: nil

  defp build(value), do: %{type: :date, value: value, operator: :equals}

  @impl true
  def validate(%{type: :date, value: value, operator: :equals}), do: valid_date?(value)
  def validate(_), do: false

  @impl true
  def default_options, do: []

  @impl true
  def empty?(nil), do: true
  def empty?(%{value: ""}), do: true
  def empty?(%{value: nil}), do: true
  def empty?(_), do: false

  @impl true
  def build_query(query, field, %{value: value}) when value not in ["", nil] do
    require Ash.Query
    import Ash.Expr

    # Cast the column to a date and match it by equality against a `Date`. This
    # matches the whole calendar day for datetime columns and compares as dates,
    # rather than relying on `>=`/`<=` range comparisons against datetime fields.
    # The cast is type-agnostic, so it works the same whether the field is a
    # `:date` or any datetime type, and on direct, relationship, and embedded
    # fields alike.
    case Date.from_iso8601(value) do
      {:ok, date} ->
        case Helpers.parse_field_notation(field) do
          {:direct, field_name} ->
            field_atom = String.to_atom(field_name)
            Ash.Query.filter(query, type(^ref(field_atom), :date) == ^date)

          {:relationship, rel_path, field_name} ->
            rel_path_atoms = Enum.map(rel_path, &String.to_atom/1)
            field_atom = String.to_atom(field_name)

            Ash.Query.filter(
              query,
              exists(^rel_path_atoms, type(^ref(field_atom), :date) == ^date)
            )

          {:embedded, embed_field, field_name} ->
            embed_atom = String.to_atom(embed_field)
            field_atom = String.to_atom(field_name)

            Ash.Query.filter(
              query,
              type(get_path(^ref(embed_atom), [^field_atom]), :date) == ^date
            )

          {:nested_embedded, embed_field, field_path} ->
            embed_atom = String.to_atom(embed_field)
            field_atoms = Enum.map(field_path, &String.to_atom/1)

            Ash.Query.filter(
              query,
              type(get_path(^ref(embed_atom), ^field_atoms), :date) == ^date
            )

          {:relationship_embedded, rel_path, embed_field, field_name} ->
            rel_path_atoms = Enum.map(rel_path, &String.to_atom/1)
            embed_atom = String.to_atom(embed_field)
            field_atom = String.to_atom(field_name)

            Ash.Query.filter(
              query,
              exists(
                ^rel_path_atoms,
                type(get_path(^ref(embed_atom), [^field_atom]), :date) == ^date
              )
            )

          {:relationship_nested_embedded, rel_path, embed_field, field_path} ->
            rel_path_atoms = Enum.map(rel_path, &String.to_atom/1)
            embed_atom = String.to_atom(embed_field)
            field_atoms = Enum.map(field_path, &String.to_atom/1)

            Ash.Query.filter(
              query,
              exists(
                ^rel_path_atoms,
                type(get_path(^ref(embed_atom), ^field_atoms), :date) == ^date
              )
            )

          {:invalid, _} ->
            query
        end

      {:error, _} ->
        query
    end
  end

  def build_query(query, _field, _filter_value), do: query

  defp format_value_for_input(value) when is_binary(value), do: value
  defp format_value_for_input(_), do: ""

  defp valid_date?(value) when is_binary(value) do
    match?({:ok, _}, Date.from_iso8601(value))
  end

  defp valid_date?(_), do: false
end
