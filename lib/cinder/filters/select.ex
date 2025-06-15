defmodule Cinder.Filters.Select do
  @moduledoc """
  Select dropdown filter implementation for Cinder tables.

  Provides single-select filtering with configurable options and prompts.
  """

  @behaviour Cinder.Filter
  use Phoenix.Component

  require Ash.Query
  import Ash.Expr
  import Cinder.Filter

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
      name={field_name(@column.field)}
      class={@theme.filter_select_input_class}
      {@theme.filter_select_input_data}
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

  @impl true
  def build_query(query, field, filter_value) do
    %{type: :select, value: value} = filter_value

    # Handle relationship fields using dot notation
    if String.contains?(field, ".") do
      # Build the path as a list of atoms for Ash filtering
      path_atoms = field |> String.split(".") |> Enum.map(&String.to_atom/1)

      # Handle any relationship path length: user.name, user.department.name, etc.
      {rel_path, [field_atom]} = Enum.split(path_atoms, -1)
      Ash.Query.filter(query, exists(^rel_path, ^ref(field_atom) == ^value))
    else
      # Direct field filtering
      field_atom = String.to_atom(field)
      Ash.Query.filter(query, ^ref(field_atom) == ^value)
    end
  end
end
