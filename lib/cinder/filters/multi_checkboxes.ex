defmodule Cinder.Filters.MultiCheckboxes do
  @moduledoc """
  Multi-checkbox filter implementation for Cinder tables.

  Provides multiple selection filtering with checkbox inputs for each option.
  This is the traditional checkbox-based interface for selecting multiple values.

  ## Match Mode Options

  The `match_mode` option controls how multiple selections are combined:

  - `:any` (default) - Shows records containing ANY of the selected values (OR logic)
  - `:all` - Shows records containing ALL of the selected values (AND logic)

  ## Examples

      # ANY logic - show records with at least one selected value
      <:col field="tags" filter={:multi_checkboxes}
            filter_options={[
              options: [{"Fiction", "fiction"}, {"Romance", "romance"}],
              match_mode: :any
            ]} />

      # ALL logic - show records that have all selected values
      <:col field="tags" filter={:multi_checkboxes}
            filter_options={[
              options: [{"Fiction", "fiction"}, {"Bestseller", "bestseller"}],
              match_mode: :all
            ]} />

  ## Array Field Support

  This filter automatically detects array fields and uses containment logic:
  - For array fields: `"selected_value" in array_field`
  - For non-array fields: `field in [selected_values]`

  The `match_mode` option only affects array fields. For non-array fields,
  standard IN operator logic is always used regardless of match_mode.
  """

  @behaviour Cinder.Filter
  use Phoenix.Component

  require Ash.Query
  import Cinder.Filter

  @impl true
  def render(column, current_value, theme, _assigns) do
    filter_options = Map.get(column, :filter_options, [])
    options = get_option(filter_options, :options, [])
    selected_values = current_value || []

    assigns = %{
      column: column,
      selected_values: selected_values,
      options: options,
      theme: theme
    }

    ~H"""
    <div class={@theme.filter_multicheckboxes_container_class} {@theme.filter_multicheckboxes_container_data}>
      <div :for={{label, value} <- @options} class={@theme.filter_multicheckboxes_option_class} {@theme.filter_multicheckboxes_option_data}>
        <input
          type="checkbox"
          name={field_name(@column.field) <> "[]"}
          value={to_string(value)}
          checked={to_string(value) in Enum.map(@selected_values, &to_string/1)}
          class={@theme.filter_multicheckboxes_checkbox_class}
          {@theme.filter_multicheckboxes_checkbox_data}
        />
        <label class={@theme.filter_multicheckboxes_label_class} {@theme.filter_multicheckboxes_label_data}>{label}</label>
      </div>
    </div>
    """
  end

  @impl true
  def process(raw_value, column) when is_list(raw_value) do
    # Filter out empty values
    values = Enum.reject(raw_value, &(&1 == "" or is_nil(&1)))

    if Enum.empty?(values) do
      nil
    else
      filter_options = Map.get(column, :filter_options, [])
      match_mode = get_option(filter_options, :match_mode, :any)

      %{
        type: :multi_checkboxes,
        value: values,
        operator: :in,
        match_mode: match_mode
      }
    end
  end

  def process(raw_value, column) when is_binary(raw_value) do
    # Handle single value as list
    process([raw_value], column)
  end

  def process(_raw_value, _column), do: nil

  @impl true
  def validate(value) do
    case value do
      %{type: :multi_checkboxes, value: vals, operator: :in, match_mode: mode}
      when is_list(vals) ->
        valid_values = not Enum.empty?(vals) and Enum.all?(vals, &is_binary/1)
        valid_mode = mode in [:any, :all]
        valid_values and valid_mode

      %{type: :multi_checkboxes, value: vals, operator: :in} when is_list(vals) ->
        # Backward compatibility - old format without match_mode
        not Enum.empty?(vals) and Enum.all?(vals, &is_binary/1)

      _ ->
        false
    end
  end

  @impl true
  def default_options do
    [
      options: [],
      match_mode: :any
    ]
  end

  @impl true
  def empty?(value) do
    case value do
      nil -> true
      [] -> true
      %{value: []} -> true
      %{value: nil} -> true
      _ -> false
    end
  end

  @impl true
  def build_query(query, field, filter_value) do
    %{value: values} = filter_value
    match_mode = Map.get(filter_value, :match_mode, :any)

    # Use the centralized helper which supports direct, relationship, and embedded fields
    # Pass match_mode as additional context for array field handling
    Cinder.Filter.Helpers.build_ash_filter(query, field, values, :in, match_mode: match_mode)
  end
end
