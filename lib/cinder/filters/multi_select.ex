defmodule Cinder.Filters.MultiSelect do
  @moduledoc """
  Multi-select tag-based filter implementation for Cinder tables.

  Provides multiple selection filtering with a modern dropdown + tags interface.
  Selected items are displayed as removable tags with a dropdown for adding new selections.
  Uses Phoenix LiveView patterns for interactivity.

  ## Match Mode Options

  The `match_mode` option controls how multiple selections are combined:

  - `:any` (default) - Shows records containing ANY of the selected values (OR logic)
  - `:all` - Shows records containing ALL of the selected values (AND logic)

  ## Examples

      # ANY logic - show books with at least one selected tag
      <:col field="tags" filter={:multi_select}
            filter_options={[
              options: [{"Fiction", "fiction"}, {"Romance", "romance"}],
              match_mode: :any
            ]} />

      # ALL logic - show books that have all selected tags
      <:col field="tags" filter={:multi_select}
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
  alias Phoenix.LiveView.JS

  @impl true
  def render(column, current_value, theme, assigns) do
    filter_options = Map.get(column, :filter_options, [])
    options = get_option(filter_options, :options, [])
    selected_values = current_value || []

    # Create a lookup map for labels
    option_labels =
      Enum.into(options, %{}, fn {label, value} -> {to_string(value), label} end)

    # Create display text for the dropdown button
    display_text =
      case length(selected_values) do
        0 ->
          "Select options..."

        1 ->
          Map.get(
            option_labels,
            to_string(Enum.at(selected_values, 0)),
            Enum.at(selected_values, 0)
          )

        count ->
          "#{count} selected"
      end

    assigns = %{
      column: column,
      selected_values: selected_values,
      options: options,
      option_labels: option_labels,
      display_text: display_text,
      theme: theme,
      field_name: field_name(column.field),
      dropdown_id: "multiselect-dropdown-#{column.field}",
      target: Map.get(assigns, :target)
    }

    ~H"""
    <div class={@theme.filter_multiselect_container_class} id={@dropdown_id}>
      <!-- Main dropdown button that looks like a select input -->
      <button
        type="button"
        class={[@theme.filter_select_input_class, "flex items-center justify-between"]}
        {@theme.filter_select_input_data}
        phx-click={JS.toggle(to: "##{@dropdown_id}-options")}
      >
        <span class={[if(Enum.empty?(@selected_values), do: "text-gray-400", else: ""), "truncate"]}>{@display_text}</span>
        <svg :if={@theme.filter_select_arrow_class != ""} class={@theme.filter_select_arrow_class} fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7"></path>
        </svg>
      </button>

      <!-- Dropdown options (hidden by default) -->
      <div
        id={"#{@dropdown_id}-options"}
        class={[@theme.filter_multiselect_dropdown_class, "hidden"]}
        {@theme.filter_multiselect_dropdown_data}
        phx-click-away={JS.hide(to: "##{@dropdown_id}-options")}
      >
        <label :for={{label, value} <- @options} class={[@theme.filter_multiselect_option_class, "flex items-center"]} {@theme.filter_multiselect_option_data}>
          <input
            type="checkbox"
            name={@field_name <> "[]"}
            value={to_string(value)}
            checked={to_string(value) in Enum.map(@selected_values, &to_string/1)}
            class={@theme.filter_multiselect_checkbox_class}
            {@theme.filter_multiselect_checkbox_data}
            phx-click="toggle_multiselect_option"
            phx-value-field={@column.field}
            phx-value-option={value}
            phx-target={@target}
          />
          <span class={@theme.filter_multiselect_label_class} {@theme.filter_multiselect_label_data}>{label}</span>
        </label>

        <div :if={Enum.empty?(@options)} class={@theme.filter_multiselect_empty_class} {@theme.filter_multiselect_empty_data}>
          No options available
        </div>
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
        type: :multi_select,
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
      %{type: :multi_select, value: vals, operator: :in, match_mode: mode} when is_list(vals) ->
        valid_values = not Enum.empty?(vals) and Enum.all?(vals, &is_binary/1)
        valid_mode = mode in [:any, :all]
        valid_values and valid_mode

      %{type: :multi_select, value: vals, operator: :in} when is_list(vals) ->
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

  @doc """
  Handles toggling an option in the multi-select filter.

  This function should be called from the parent LiveView/LiveComponent
  to handle the "toggle_multiselect_option" event.
  """
  def handle_toggle_option(socket, field, value) do
    current_filters = Map.get(socket.assigns, :filters, %{})
    current_values = Map.get(current_filters, field, [])

    # Toggle the value - add if not present, remove if present
    new_values =
      if value in current_values do
        Enum.reject(current_values, &(&1 == value))
      else
        current_values ++ [value]
      end

    updated_filters =
      if Enum.empty?(new_values) do
        Map.delete(current_filters, field)
      else
        Map.put(current_filters, field, new_values)
      end

    assign(socket, :filters, updated_filters)
  end
end
