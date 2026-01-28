defmodule Cinder.Filters.Autocomplete do
  @moduledoc """
  Autocomplete filter implementation for Cinder tables.

  Provides a searchable dropdown for cases where a standard select has too many
  options. Users type to filter the available options, with matching results
  shown in a dropdown.

  ## Options

  - `:options` - List of `{label, value}` tuples (required for static mode)
  - `:placeholder` - Placeholder text for the search input
  - `:max_results` - Maximum number of results to show (default: 10)

  ## Examples

      # Static options
      <:col field={:category_id} label="Category"
        filter={[
          type: :autocomplete,
          options: [{"Electronics", 1}, {"Clothing", 2}, {"Books", 3}],
          max_results: 10,
          placeholder: "Search categories..."
        ]}
      />
  """

  @behaviour Cinder.Filter
  use Phoenix.Component
  use Cinder.Messages

  import Cinder.Filter, only: [get_option: 3, field_name: 1, filter_id: 2]
  alias Phoenix.LiveView.JS

  @default_max_results 10

  @impl true
  def render(column, current_value, theme, assigns) do
    filter_options = Map.get(column, :filter_options, [])
    all_options = get_option(filter_options, :options, [])

    default_placeholder = dgettext("cinder", "Search %{label}...", label: column.label)
    placeholder = get_option(filter_options, :placeholder, default_placeholder)
    max_results = get_option(filter_options, :max_results, @default_max_results)

    # Get search term from raw_filter_params (submitted via form)
    raw_filter_params = Map.get(assigns, :raw_filter_params, %{})
    search_key = "#{column.field}_autocomplete_search"
    search_term = Map.get(raw_filter_params, search_key, "")

    # Look up the display label for the current value
    current_label = find_label_for_value(all_options, current_value)

    # Filter options based on search term
    filtered_options =
      if search_term == "" do
        Enum.take(all_options, max_results)
      else
        all_options
        |> Enum.filter(fn {label, _value} ->
          String.contains?(String.downcase(to_string(label)), String.downcase(search_term))
        end)
        |> Enum.take(max_results)
      end

    has_more =
      if search_term == "" do
        length(all_options) > max_results
      else
        length(
          Enum.filter(all_options, fn {label, _value} ->
            String.contains?(String.downcase(to_string(label)), String.downcase(search_term))
          end)
        ) > max_results
      end

    # Sanitize field name for use in HTML attributes
    table_id = Map.get(assigns, :table_id)
    safe_field_name = Cinder.Filter.sanitized_field_name(column.field)

    # Use filter_id for consistent ID generation (or fallback for tests without table_id)
    {dropdown_id, input_id} =
      if table_id do
        base_id = filter_id(table_id, column.field)
        {"#{base_id}-dropdown", base_id}
      else
        {"autocomplete-dropdown-#{safe_field_name}", nil}
      end

    assigns = %{
      column: column,
      current_value: current_value || "",
      current_label: current_label,
      search_term: search_term,
      filtered_options: filtered_options,
      has_more: has_more,
      placeholder: placeholder,
      theme: theme,
      dropdown_id: dropdown_id,
      input_id: input_id,
      target: Map.get(assigns, :target)
    }

    ~H"""
    <div class={@theme.filter_select_container_class} id={@dropdown_id}>
      <!-- Hidden input for the actual filter value -->
      <input
        type="hidden"
        name={field_name(@column.field)}
        value={@current_value}
      />

      <!-- Search input -->
      <input
        type="text"
        id={@input_id}
        name={"filters[#{@column.field}_autocomplete_search]"}
        value={if @current_value != "", do: @current_label, else: @search_term}
        placeholder={@placeholder}
        class={@theme.filter_text_input_class}
        {@theme.filter_text_input_data}
        autocomplete="off"
        phx-debounce="300"
        phx-focus={JS.show(to: "##{@dropdown_id}-options")}
      />

      <!-- Dropdown options -->
      <div
        id={"#{@dropdown_id}-options"}
        class={[@theme.filter_select_dropdown_class, "hidden"]}
        {@theme.filter_select_dropdown_data}
        phx-click-away={JS.hide(to: "##{@dropdown_id}-options")}
      >
        <label
          :for={{label, value} <- @filtered_options}
          class={[@theme.filter_select_option_class, "flex items-center cursor-pointer"]}
          {@theme.filter_select_option_data}
        >
          <input
            type="radio"
            name={field_name(@column.field)}
            value={to_string(value)}
            checked={to_string(value) == to_string(@current_value)}
            class="sr-only"
            phx-click={JS.hide(to: "##{@dropdown_id}-options")}
          />
          <span class={@theme.filter_select_label_class} {@theme.filter_select_label_data}>
            {label}
          </span>
        </label>

        <div
          :if={@filtered_options == []}
          class={@theme.filter_select_empty_class}
          {@theme.filter_select_empty_data}
        >
          No results found
        </div>

        <div
          :if={@has_more}
          class={[@theme.filter_select_empty_class, "text-xs italic"]}
          {@theme.filter_select_empty_data}
        >
          Type to search more options...
        </div>
      </div>


    </div>
    """
  end

  @impl true
  def process(raw_value, _column) when is_binary(raw_value) do
    trimmed = String.trim(raw_value)

    if trimmed == "" do
      nil
    else
      %{
        type: :autocomplete,
        value: trimmed,
        operator: :equals
      }
    end
  end

  def process(_raw_value, _column), do: nil

  @impl true
  def validate(value) do
    case value do
      %{type: :autocomplete, value: val, operator: :equals} when is_binary(val) ->
        val != ""

      _ ->
        false
    end
  end

  @impl true
  def default_options do
    [
      options: [],
      placeholder: nil,
      max_results: @default_max_results
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
    %{value: value} = filter_value

    # Use the centralized helper which supports direct, relationship, and embedded fields
    Cinder.Filter.Helpers.build_ash_filter(query, field, value, :equals)
  end

  # Private helpers

  defp find_label_for_value(_options, nil), do: nil
  defp find_label_for_value(_options, ""), do: nil

  defp find_label_for_value(options, value) do
    value_string = to_string(value)

    case Enum.find(options, fn {_label, v} -> to_string(v) == value_string end) do
      {label, _value} -> label
      nil -> nil
    end
  end
end
