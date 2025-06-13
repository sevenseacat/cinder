defmodule Cinder.FilterManager do
  @moduledoc """
  Coordinator for Cinder's modular filter system.

  Acts as the main interface for filter operations while delegating
  to individual filter type modules for specific implementations.
  """

  use Phoenix.Component

  alias Cinder.Filters.Registry

  @type filter_type :: :text | :select | :multi_select | :date_range | :number_range | :boolean
  @type filter_value ::
          String.t()
          | [String.t()]
          | %{from: String.t(), to: String.t()}
          | %{min: String.t(), max: String.t()}
  @type filter :: %{type: filter_type(), value: filter_value(), operator: atom()}
  @type filters :: %{String.t() => filter()}
  @type column :: %{
          field: String.t(),
          label: String.t(),
          filterable: boolean(),
          filter_type: filter_type(),
          filter_options: keyword()
        }

  @doc """
  Renders filter controls for a list of columns.

  ## Parameters
  - `columns` - List of column definitions
  - `filters` - Current filter state map
  - `theme` - Theme configuration
  - `target` - LiveComponent target for events

  ## Returns
  HEEx template for filter controls
  """
  def render_filter_controls(assigns) do
    filterable_columns = Enum.filter(assigns.columns, & &1.filterable)
    active_filters = count_active_filters(assigns.filters)
    filter_values = build_filter_values(filterable_columns, assigns.filters)

    assigns =
      assigns
      |> assign(:filterable_columns, filterable_columns)
      |> assign(:active_filters, active_filters)
      |> assign(:filter_values, filter_values)

    ~H"""
    <div :if={@filterable_columns != []} class={@theme.filter_container_class}>
      <div class={@theme.filter_header_class}>
        <span class={@theme.filter_title_class}>
          🔍 Filters
          <span :if={@active_filters > 0} class={@theme.filter_count_class}>
            ({@active_filters} active)
          </span>
        </span>
        <button
          :if={@active_filters > 0}
          phx-click="clear_all_filters"
          phx-target={@target}
          class={@theme.filter_clear_all_class}
        >
          Clear All
        </button>
      </div>

      <form phx-change="filter_change" phx-target={@target}>
        <div class={@theme.filter_inputs_class}>
          <div :for={column <- @filterable_columns} class={@theme.filter_input_wrapper_class}>
            <label class={@theme.filter_label_class}>{column.label}:</label>
            <.filter_input
              column={column}
              current_value={Map.get(@filter_values, column.field, "")}
              filter_values={@filter_values}
              theme={@theme}
              target={@target}
            />
          </div>
        </div>
      </form>
    </div>
    """
  end

  @doc """
  Renders an individual filter input by delegating to the appropriate filter module.
  """
  def filter_input(assigns) do
    filter_module = Registry.get_filter(assigns.column.filter_type)

    filter_content =
      if filter_module do
        # Build additional assigns for filter modules
        filter_assigns = %{
          target: assigns.target,
          filter_values: assigns.filter_values
        }

        # Delegate to the specific filter module
        filter_module.render(assigns.column, assigns.current_value, assigns.theme, filter_assigns)
      else
        # Fallback to text filter if type not found
        fallback_column = Map.put(assigns.column, :filter_type, :text)
        text_module = Registry.get_filter(:text)
        filter_assigns = %{target: assigns.target, filter_values: assigns.filter_values}
        text_module.render(fallback_column, assigns.current_value, assigns.theme, filter_assigns)
      end

    # Wrap with clear button
    assigns = assign(assigns, :filter_content, filter_content)

    ~H"""
    <div class="flex items-center space-x-2">
      <div class="flex-1">
        <%= @filter_content %>
      </div>

      <!-- Clear individual filter button -->
      <button
        :if={@current_value != "" and not is_nil(@current_value) and @current_value != [] and @current_value != %{from: "", to: ""} and @current_value != %{min: "", max: ""}}
        type="button"
        phx-click="clear_filter"
        phx-value-key={@column.field}
        phx-target={@target}
        class={@theme.filter_clear_button_class}
        title="Clear filter"
      >
        ×
      </button>
    </div>
    """
  end

  @doc """
  Processes filter parameters from form submission using modular filter system.
  """
  def process_filter_params(filter_params, columns) do
    # Ensure multi-select fields are included even when no checkboxes are selected
    complete_filter_params = Cinder.UrlManager.ensure_multiselect_fields(filter_params, columns)

    # Handle special cases for range inputs (backward compatibility)
    complete_filter_params
    |> Enum.reduce(%{}, fn {key, value}, acc ->
      cond do
        # Handle date range fields
        String.ends_with?(key, "_from") ->
          base_key = String.replace_suffix(key, "_from", "")
          to_key = base_key <> "_to"
          to_value = Map.get(complete_filter_params, to_key, "")

          combined_value =
            if value != "" or to_value != "", do: "#{value},#{to_value}", else: ""

          Map.put(acc, base_key, combined_value)

        String.ends_with?(key, "_to") ->
          # Skip _to keys as they're handled by _from keys
          acc

        # Handle number range fields
        String.ends_with?(key, "_min") ->
          base_key = String.replace_suffix(key, "_min", "")
          max_key = base_key <> "_max"
          max_value = Map.get(complete_filter_params, max_key, "")

          combined_value =
            if value != "" or max_value != "", do: "#{value},#{max_value}", else: ""

          Map.put(acc, base_key, combined_value)

        String.ends_with?(key, "_max") ->
          # Skip _max keys as they're handled by _min keys
          acc

        true ->
          Map.put(acc, key, value)
      end
    end)
  end

  @doc """
  Transforms form values into structured filter objects using modular filter system.
  """
  def params_to_filters(filter_params, columns) do
    processed_params = process_filter_params(filter_params, columns)

    columns
    |> Enum.filter(& &1.filterable)
    |> Enum.reduce(%{}, fn column, acc ->
      raw_value = Map.get(processed_params, column.field, "")

      if has_filter_value?(raw_value) do
        case process_filter_value(raw_value, column) do
          nil -> acc
          processed_filter -> Map.put(acc, column.field, processed_filter)
        end
      else
        acc
      end
    end)
  end

  @doc """
  Builds filter values map for form inputs using modular filter system.
  """
  def build_filter_values(filterable_columns, filters) do
    filterable_columns
    |> Enum.reduce(%{}, fn column, acc ->
      case Map.get(filters, column.field) do
        nil ->
          Map.put(acc, column.field, get_default_value(column.filter_type))

        filter ->
          formatted_value = format_filter_value(filter, column.filter_type)
          Map.put(acc, column.field, formatted_value)
      end
    end)
  end

  @doc """
  Clears a specific filter from the filter state.
  """
  def clear_filter(filters, key) do
    Map.delete(filters, key)
  end

  @doc """
  Clears all filters from the filter state.
  """
  def clear_all_filters(_filters) do
    %{}
  end

  @doc """
  Counts the number of active filters.
  """
  def count_active_filters(filters) do
    Enum.count(filters)
  end

  @doc """
  Checks if a filter has a meaningful value using modular system.
  """
  def has_filter_value?(value) do
    Cinder.Filters.Base.has_filter_value?(value)
  end

  @doc """
  Infers filter configuration from Ash resource attribute definitions.
  """
  def infer_filter_config(key, resource, slot) do
    # Skip inference if filterable is false or if both filter_type and filter_options are explicitly set with content
    has_custom_options = Map.get(slot, :filter_options, []) != []

    if not Map.get(slot, :filterable, false) or
         (Map.has_key?(slot, :filter_type) and has_custom_options) do
      %{filter_type: :text, filter_options: []}
    else
      attribute = get_ash_attribute(resource, key)

      # Use explicit filter_type if provided, otherwise infer it
      filter_type = Map.get(slot, :filter_type) || Registry.infer_filter_type(attribute, key)
      default_options = Registry.default_options(filter_type, key)

      # Enhance options with Ash-specific data for select/multi_select filters
      enhanced_options =
        case filter_type do
          :select -> enhance_select_options(default_options, attribute, key)
          :multi_select -> enhance_select_options(default_options, attribute, key)
          _ -> default_options
        end

      %{filter_type: filter_type, filter_options: enhanced_options}
    end
  end

  # Private helper functions

  defp process_filter_value(raw_value, column) do
    filter_module = Registry.get_filter(column.filter_type)

    if filter_module do
      filter_module.process(raw_value, column)
    else
      # Fallback to text processing
      text_module = Registry.get_filter(:text)
      text_module.process(raw_value, column)
    end
  end

  defp get_default_value(:date_range), do: %{from: "", to: ""}
  defp get_default_value(:number_range), do: %{min: "", max: ""}
  defp get_default_value(:multi_select), do: []
  defp get_default_value(_), do: ""

  defp format_filter_value(filter, filter_type) do
    case {filter_type, filter} do
      {:date_range, %{value: %{from: from, to: to}}} ->
        %{from: from || "", to: to || ""}

      {:number_range, %{value: %{min: min, max: max}}} ->
        %{min: min || "", max: max || ""}

      {:multi_select, %{value: values}} when is_list(values) ->
        values

      {:boolean, %{value: true}} ->
        "true"

      {:boolean, %{value: false}} ->
        "false"

      {_, %{value: value}} ->
        value

      _ ->
        ""
    end
  end

  defp get_ash_attribute(resource, key) do
    try do
      key_atom = if is_binary(key), do: String.to_atom(key), else: key

      # Check if this is actually an Ash resource using Ash.Resource.Info.resource?/1
      if Ash.Resource.Info.resource?(resource) do
        # First check regular attributes
        attributes = Ash.Resource.Info.attributes(resource)
        attribute = Enum.find(attributes, &(&1.name == key_atom))

        if attribute do
          attribute
        else
          # Check aggregates - they should be treated as their type for filtering
          aggregates = Ash.Resource.Info.aggregates(resource)
          aggregate = Enum.find(aggregates, &(&1.name == key_atom))

          if aggregate do
            # Convert aggregate to attribute-like structure for type inference
            # Count aggregates should be treated as integers
            case aggregate.kind do
              :count -> %{name: key_atom, type: :integer}
              :sum -> %{name: key_atom, type: aggregate.field_type || :integer}
              :avg -> %{name: key_atom, type: :decimal}
              :max -> %{name: key_atom, type: aggregate.field_type || :integer}
              :min -> %{name: key_atom, type: aggregate.field_type || :integer}
              _ -> %{name: key_atom, type: :integer}
            end
          else
            # Check calculations as well
            calculations = Ash.Resource.Info.calculations(resource)
            calculation = Enum.find(calculations, &(&1.name == key_atom))

            if calculation do
              # Convert calculation to attribute-like structure
              %{name: key_atom, type: calculation.type}
            else
              nil
            end
          end
        end
      else
        nil
      end
    rescue
      _ -> nil
    catch
      _ -> nil
    end
  end

  defp enhance_select_options(default_options, attribute, key) do
    case extract_enum_options(attribute) do
      [] ->
        # No enum options found, return defaults
        Keyword.merge(default_options, prompt: "All #{Cinder.Filters.Base.humanize_key(key)}")

      options ->
        # Add enum options and prompt
        default_options
        |> Keyword.put(:options, options)
        |> Keyword.put(:prompt, "All #{Cinder.Filters.Base.humanize_key(key)}")
    end
  end

  defp extract_enum_options(nil), do: []

  defp extract_enum_options(%{type: type, constraints: constraints}) do
    cond do
      # Handle constraint-based enums (new Ash format) - constraints can be a map or keyword list
      (is_map(constraints) and Map.has_key?(constraints, :one_of)) or
          (is_list(constraints) and Keyword.has_key?(constraints, :one_of)) ->
        values =
          if is_map(constraints),
            do: Map.get(constraints, :one_of),
            else: Keyword.get(constraints, :one_of)

        enum_to_options(values, type)

      # Handle Ash.Type.Enum and custom enum types
      is_atom(type) ->
        case (try do
                apply(type, :values, [])
              rescue
                _ -> nil
              end) do
          values when is_list(values) -> enum_to_options(values, type)
          _ -> []
        end

      true ->
        []
    end
  end

  defp extract_enum_options(%{type: {:one_of, values}}) when is_list(values) do
    enum_to_options(values, nil)
  end

  defp extract_enum_options(_), do: []

  defp enum_to_options(values, enum_module) do
    Enum.map(values, fn value ->
      case value do
        atom when is_atom(atom) ->
          label =
            if enum_module && function_exported?(enum_module, :description, 1) do
              apply(enum_module, :description, [atom])
            else
              Cinder.Filters.Base.humanize_atom(atom)
            end

          {label, atom}

        string when is_binary(string) ->
          {String.capitalize(string), string}

        {label, value} ->
          {to_string(label), value}

        other ->
          {to_string(other), other}
      end
    end)
  end
end
