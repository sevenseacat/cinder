defmodule Cinder.Filters.MultiSelect do
  @moduledoc """
  Multi-select tag-based filter implementation for Cinder tables.

  Provides multiple selection filtering with a modern dropdown + tags interface.
  Selected items are displayed as removable tags with a dropdown for adding new selections.
  Uses Phoenix LiveView patterns for interactivity.
  """

  @behaviour Cinder.Filters.Base
  use Phoenix.Component

  import Cinder.Filters.Base

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
    <div class={@theme.filter_multiselect_container_class} phx-hook="MultiSelectDropdown" id={@dropdown_id}>
      <!-- Main dropdown button that looks like a select input -->
      <button
        type="button"
        class={[@theme.filter_select_input_class, "flex items-center justify-between"]}
        {@theme.filter_select_input_data}
        onclick={"document.getElementById('#{@dropdown_id}-options').classList.toggle('hidden')"}
      >
        <span class={if Enum.empty?(@selected_values), do: "text-gray-400", else: ""}>{@display_text}</span>
        <svg class="w-4 h-4 ml-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7"></path>
        </svg>
      </button>

      <!-- Dropdown options (hidden by default) -->
      <div
        id={"#{@dropdown_id}-options"}
        class={[@theme.filter_multiselect_dropdown_class, "hidden"]}
        {@theme.filter_multiselect_dropdown_data}
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
  def process(raw_value, _column) when is_list(raw_value) do
    # Filter out empty values
    values = Enum.reject(raw_value, &(&1 == "" or is_nil(&1)))

    if Enum.empty?(values) do
      nil
    else
      %{
        type: :multi_select,
        value: values,
        operator: :in
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
      %{type: :multi_select, value: vals, operator: :in} when is_list(vals) ->
        not Enum.empty?(vals) and Enum.all?(vals, &is_binary/1)

      _ ->
        false
    end
  end

  @impl true
  def default_options do
    [
      options: []
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
