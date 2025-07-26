defmodule Cinder.Filters.Select do
  @moduledoc """
  Select dropdown filter implementation for Cinder tables.

  Provides single-select filtering with configurable options and prompts.
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
    prompt = get_option(filter_options, :prompt, "All #{column.label}")

    current_value = current_value || ""

    # Create a lookup map for labels
    option_labels =
      Enum.into(options, %{}, fn {label, value} -> {to_string(value), label} end)

    # Create display text for the dropdown button
    display_text =
      if current_value == "" do
        prompt
      else
        Map.get(option_labels, current_value, current_value)
      end

    assigns = %{
      column: column,
      current_value: current_value,
      options: options,
      prompt: prompt,
      theme: theme,
      display_text: display_text,
      dropdown_id: "select-dropdown-#{column.field}",
      target: Map.get(assigns, :target)
    }

    ~H"""
    <div class={@theme.filter_select_container_class} id={"select-dropdown-#{@column.field}"}>
      <!-- Main dropdown button that looks like a select input -->
      <button
        type="button"
        class={[@theme.filter_select_input_class, "flex items-center justify-between"]}
        {@theme.filter_select_input_data}
        phx-click={JS.toggle(to: "##{@dropdown_id}-options")}
      >
        <span class={[if(@current_value == "", do: "text-gray-400", else: ""), "truncate"]}>{@display_text}</span>
        <svg :if={@theme.filter_select_arrow_class != ""} class={@theme.filter_select_arrow_class} fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7"></path>
        </svg>
      </button>



      <!-- Dropdown options (hidden by default) -->
      <div
        id={"#{@dropdown_id}-options"}
        class={[@theme.filter_select_dropdown_class, "hidden"]}
        {@theme.filter_select_dropdown_data}
        phx-click-away={JS.hide(to: "##{@dropdown_id}-options")}
      >
        <label class={[@theme.filter_select_option_class, "flex items-center cursor-pointer"]} {@theme.filter_select_option_data}>
          <input
            type="radio"
            name={field_name(@column.field)}
            value=""
            checked={@current_value == ""}
            class="sr-only"
            phx-value-field={@column.field}
            phx-value-option=""
            phx-target={@target}
            phx-click={JS.push("select_option", target: @target) |> JS.hide(to: "##{@dropdown_id}-options")}
          />
          <span class={@theme.filter_select_label_class} {@theme.filter_select_label_data}>{@prompt}</span>
        </label>

        <label :for={{label, value} <- @options} class={[@theme.filter_select_option_class, "flex items-center cursor-pointer"]} {@theme.filter_select_option_data}>
          <input
            type="radio"
            name={field_name(@column.field)}
            value={to_string(value)}
            checked={to_string(value) == @current_value}
            class="sr-only"
            phx-value-field={@column.field}
            phx-value-option={value}
            phx-target={@target}
            phx-click={JS.push("select_option", target: @target) |> JS.hide(to: "##{@dropdown_id}-options")}
          />
          <span class={@theme.filter_select_label_class} {@theme.filter_select_label_data}>{label}</span>
        </label>

        <div :if={Enum.empty?(@options)} class={@theme.filter_select_empty_class} {@theme.filter_select_empty_data}>
          No options available
        </div>
      </div>
    </div>
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
    %{value: value} = filter_value

    # Use the centralized helper which supports direct, relationship, and embedded fields
    Cinder.Filter.Helpers.build_ash_filter(query, field, value, :equals)
  end

  @doc """
  Handles selecting an option in the single-select filter.

  This function should be called from the parent LiveView/LiveComponent
  to handle the "select_option" event.
  """
  def handle_select_option(socket, field, value) do
    current_filters = Map.get(socket.assigns, :filters, %{})

    updated_filters =
      if value == "" do
        Map.delete(current_filters, field)
      else
        Map.put(current_filters, field, value)
      end

    assign(socket, :filters, updated_filters)
  end
end
