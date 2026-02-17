defmodule Cinder.Filters.Select do
  @moduledoc """
  Select dropdown filter implementation for Cinder tables.

  Provides single-select filtering with configurable options and prompts.
  """

  @behaviour Cinder.Filter
  use Phoenix.Component
  use Cinder.Messages

  import Cinder.Filter, only: [get_option: 3, field_name: 1, filter_id: 2]
  alias Phoenix.LiveView.JS

  @impl true
  def render(column, current_value, theme, assigns) do
    filter_options = Map.get(column, :filter_options, [])
    options = get_option(filter_options, :options, [])
    default_prompt = dgettext("cinder", "All %{label}", label: column.label)
    prompt = get_option(filter_options, :prompt, default_prompt)

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

    table_id = Map.get(assigns, :table_id)
    safe_field_name = Cinder.Filter.sanitized_field_name(column.field)

    # Use filter_id for consistent ID generation (or fallback for tests without table_id)
    dropdown_id =
      if table_id do
        filter_id(table_id, column.field)
      else
        "select-dropdown-#{safe_field_name}"
      end

    assigns = %{
      column: column,
      current_value: current_value,
      options: options,
      prompt: prompt,
      theme: theme,
      display_text: display_text,
      dropdown_id: dropdown_id,
      target: Map.get(assigns, :target)
    }

    ~H"""
    <div class={@theme.filter_select_container_class} data-key="filter_select_container_class" id={@dropdown_id}>
      <!-- Main dropdown button that looks like a select input -->
      <button
        type="button"
        id={"#{@dropdown_id}-button"}
        class={[@theme.filter_select_input_class, "flex items-center justify-between"]}
        data-key="filter_select_input_class"
        phx-click={JS.toggle(to: "##{@dropdown_id}-options")}
      >
        <span class={[if(@current_value == "", do: @theme.filter_select_placeholder_class, else: ""), "truncate"]}>{@display_text}</span>
        <svg :if={@theme.filter_select_arrow_class != ""} class={@theme.filter_select_arrow_class} data-key="filter_select_arrow_class" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7"></path>
        </svg>
      </button>



      <!-- Dropdown options (hidden by default) -->
      <div
        id={"#{@dropdown_id}-options"}
        class={[@theme.filter_select_dropdown_class, "hidden"]}
        data-key="filter_select_dropdown_class"
        phx-click-away={JS.hide(to: "##{@dropdown_id}-options")}
      >
        <label class={[@theme.filter_select_option_class, "flex items-center cursor-pointer"]} data-key="filter_select_option_class">
          <input
            type="radio"
            name={field_name(@column.field)}
            value=""
            checked={@current_value == ""}
            class="sr-only"
            phx-click={JS.hide(to: "##{@dropdown_id}-options")}
          />
          <span class={@theme.filter_select_label_class} data-key="filter_select_label_class">{@prompt}</span>
        </label>

        <label :for={{label, value} <- @options} class={[@theme.filter_select_option_class, "flex items-center cursor-pointer"]} data-key="filter_select_option_class">
          <input
            type="radio"
            name={field_name(@column.field)}
            value={to_string(value)}
            checked={to_string(value) == @current_value}
            class="sr-only"
            phx-click={JS.hide(to: "##{@dropdown_id}-options")}
          />
          <span class={@theme.filter_select_label_class} data-key="filter_select_label_class">{label}</span>
        </label>

        <div :if={Enum.empty?(@options)} class={@theme.filter_select_empty_class} data-key="filter_select_empty_class">
          {dgettext("cinder", "No options available")}
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
