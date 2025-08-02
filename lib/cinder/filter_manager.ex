defmodule Cinder.FilterManager do
  @moduledoc """
  Coordinator for Cinder's modular filter system.

  Acts as the main interface for filter operations while delegating
  to individual filter type modules for specific implementations.
  """

  use Phoenix.Component

  alias Cinder.Filters.Registry
  alias Cinder.Messages

  @type filter_type ::
          :text
          | :select
          | :multi_select
          | :multi_checkboxes
          | :date_range
          | :number_range
          | :boolean
          | :checkbox
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
    <!-- Filter Controls (including search) -->
    <div :if={@filterable_columns != [] or Map.get(assigns, :show_search, false)} class={@theme.filter_container_class} {@theme.filter_container_data}>
      <!-- Filter Header -->
      <div class={@theme.filter_header_class} {@theme.filter_header_data}>
        <span class={@theme.filter_title_class} {@theme.filter_title_data}>
          {@filters_label}
          <span class={[@theme.filter_count_class, if(@active_filters == 0, do: "invisible", else: "")]} {@theme.filter_count_data}>
            ({@active_filters} {Messages.dngettext("cinder", "active", "active", @active_filters)})
          </span>
        </span>
        <button
          :if={@filterable_columns != []}
          phx-click="clear_all_filters"
          phx-target={@target}
          class={[@theme.filter_clear_all_class, if(@active_filters == 0, do: "invisible", else: "")]}
          {@theme.filter_clear_all_data}
        >
          {Messages.dgettext("cinder", "Clear all")}
        </button>
      </div>

      <form phx-change="filter_change" phx-target={@target}>
        <div class={@theme.filter_inputs_class} {@theme.filter_inputs_data}>
          <!-- Search Input (if enabled) - as first filter -->
          <div :if={Map.get(assigns, :show_search, false)} class={@theme.filter_input_wrapper_class} {@theme.filter_input_wrapper_data}>
            <label class={@theme.filter_label_class} {@theme.filter_label_data}>{Map.get(assigns, :search_label, "Search")}:</label>
            <div class="flex items-center space-x-2">
              <div class="flex-1 relative">
                <input
                  type="text"
                  name="search"
                  value={Map.get(assigns, :search_term, "")}
                  placeholder={Map.get(assigns, :search_placeholder, "Search...")}
                  phx-debounce="300"
                  class={@theme.search_input_class}
                  {@theme.search_input_data}
                />
                <div class="absolute inset-y-0 left-0 flex items-center pl-3 pointer-events-none">
                  <svg class={@theme.search_icon_class} {@theme.search_icon_data} fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
                  </svg>
                </div>
              </div>

              <!-- Clear search button - consistent with filter clear buttons -->
              <button
                type="button"
                phx-click="clear_filter"
                phx-value-key="search"
                phx-target={@target}
                class={[
                  @theme.filter_clear_button_class,
                  unless(Map.get(assigns, :search_term, "") != "", do: "invisible", else: "")
                ]}
                {@theme.filter_clear_button_data}
                title="Clear search"
              >
                ×
              </button>
            </div>
          </div>

          <div :for={column <- @filterable_columns} class={@theme.filter_input_wrapper_class} {@theme.filter_input_wrapper_data}>
            <label class={[
              @theme.filter_label_class,
              if(column.filter_type == :checkbox, do: "invisible", else: "")
            ]} {@theme.filter_label_data}>{column.label}:</label>
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
    # Use enhanced registry that includes custom filters
    filter_module = Registry.get_filter(assigns.column.filter_type)

    filter_content =
      if filter_module do
        # Build additional assigns for filter modules
        filter_assigns = %{
          target: assigns.target,
          filter_values: assigns.filter_values
        }

        # Delegate to the specific filter module with error handling
        try do
          filter_module.render(
            assigns.column,
            assigns.current_value,
            assigns.theme,
            filter_assigns
          )
        rescue
          error ->
            require Logger

            Logger.warning(
              "Error rendering custom filter :#{assigns.column.filter_type} for column '#{assigns.column.field}': #{inspect(error)}. " <>
                "Falling back to text filter."
            )

            # Fallback to text filter if rendering fails
            fallback_column = Map.put(assigns.column, :filter_type, :text)
            text_module = Registry.get_filter(:text)

            text_module.render(
              fallback_column,
              assigns.current_value,
              assigns.theme,
              filter_assigns
            )
        end
      else
        # Log warning for missing custom filter
        if Registry.custom_filter?(assigns.column.filter_type) do
          require Logger

          Logger.warning(
            "Custom filter :#{assigns.column.filter_type} is registered but module is not available. " <>
              "Falling back to text filter for column '#{assigns.column.field}'"
          )
        end

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

      <!-- Clear individual filter button - always present but invisible when no value -->
      <button
        type="button"
        phx-click="clear_filter"
        phx-value-key={@column.field}
        phx-target={@target}
        class={[
          @theme.filter_clear_button_class,
          unless(@current_value != "" and not is_nil(@current_value) and @current_value != [] and @current_value != %{from: "", to: ""} and @current_value != %{min: "", max: ""}, do: "invisible", else: "")
        ]}
        {@theme.filter_clear_button_data}
        title={Messages.dgettext("cinder", "Clear filter")}
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

      # Special handling for checkbox filters: always process them,
      # even when empty, so unchecking clears the filter
      if column.filter_type == :checkbox do
        case process_filter_value(raw_value, column) do
          # When unchecked, exclude from filters (clears the filter)
          nil -> acc
          processed_filter -> Map.put(acc, column.field, processed_filter)
        end
      else
        # Standard handling for other filter types
        if has_filter_value?(raw_value) do
          case process_filter_value(raw_value, column) do
            nil -> acc
            processed_filter -> Map.put(acc, column.field, processed_filter)
          end
        else
          acc
        end
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
    Cinder.Filter.has_filter_value?(value)
  end

  @doc """
  Validates all registered custom filters at application startup.

  This function should be called during application initialization to ensure
  all custom filters are properly implemented and available.

  ## Returns
  :ok if all filters are valid, logs warnings for any issues

  ## Examples

      # In your application.ex start/2 function
      case Cinder.FilterManager.validate_runtime_filters() do
        :ok -> :ok
        {:error, _} -> :ok  # Continue startup but log issues
      end
  """
  def validate_runtime_filters do
    case Registry.validate_custom_filters() do
      :ok ->
        :ok

      {:error, errors} ->
        require Logger

        Logger.warning(
          "Custom filter validation failed during application startup:\n" <>
            Enum.map_join(errors, "\n", &"  - #{&1}")
        )

        {:error, errors}
    end
  end

  @doc """
  Infers filter configuration from Ash resource attribute definitions.
  """
  def infer_filter_config(key, resource, slot) do
    # Skip inference if filterable is false
    if not Map.get(slot, :filterable, false) do
      %{filter_type: :text, filter_options: []}
    else
      attribute = get_ash_attribute(resource, key)

      # Use explicit filter_type if provided, otherwise infer it
      filter_type = Map.get(slot, :filter_type) || Registry.infer_filter_type(attribute, key)

      # Validate custom filter exists at runtime
      filter_type =
        if Registry.custom_filter?(filter_type) do
          # Check if the module actually exists and is loadable
          module = Registry.get_filter(filter_type)

          if module && Code.ensure_loaded?(module) do
            filter_type
          else
            require Logger

            Logger.warning(
              "Custom filter :#{filter_type} is registered but module is not available " <>
                "for column '#{key}'. Falling back to text filter."
            )

            :text
          end
        else
          filter_type
        end

      default_options = Registry.default_options(filter_type, key)
      slot_options = Map.get(slot, :filter_options, [])

      # Merge slot options with defaults (slot options take precedence)
      merged_options = Keyword.merge(default_options, slot_options)

      # Enhance options with Ash-specific data for select/multi_select filters
      enhanced_options =
        case filter_type do
          :select -> enhance_select_options(merged_options, attribute, key)
          :multi_select -> enhance_select_options(merged_options, attribute, key)
          :multi_checkboxes -> enhance_select_options(merged_options, attribute, key)
          _ -> merged_options
        end

      %{filter_type: filter_type, filter_options: enhanced_options}
    end
  end

  # Private helper functions

  @doc """
  Processes raw filter value using the appropriate filter module.

  This function is public to enable comprehensive testing of custom filter processing.
  """
  def process_filter_value(raw_value, column) do
    # Use enhanced registry that includes custom filters
    filter_module = Registry.get_filter(column.filter_type)

    if filter_module do
      try do
        filter_module.process(raw_value, column)
      rescue
        error ->
          require Logger

          Logger.error(
            "Error processing filter value for custom filter :#{column.filter_type} " <>
              "on column '#{column.field}': #{inspect(error)}. Falling back to text processing."
          )

          # Fallback to text processing
          text_module = Registry.get_filter(:text)
          text_module.process(raw_value, column)
      end
    else
      # Log warning for missing custom filter
      if Registry.custom_filter?(column.filter_type) do
        require Logger

        Logger.warning(
          "Custom filter :#{column.filter_type} is registered but module is not available. " <>
            "Falling back to text processing for column '#{column.field}'"
        )
      end

      # Fallback to text processing
      text_module = Registry.get_filter(:text)
      text_module.process(raw_value, column)
    end
  end

  defp get_default_value(:date_range), do: %{from: "", to: ""}
  defp get_default_value(:number_range), do: %{min: "", max: ""}
  defp get_default_value(:multi_select), do: []
  defp get_default_value(:multi_checkboxes), do: []
  defp get_default_value(_), do: ""

  defp format_filter_value(filter, filter_type) do
    case {filter_type, filter} do
      {:date_range, %{value: %{from: from, to: to}}} ->
        %{from: from || "", to: to || ""}

      {:number_range, %{value: %{min: min, max: max}}} ->
        %{min: min || "", max: max || ""}

      {:multi_select, %{value: values}} when is_list(values) ->
        values

      {:multi_checkboxes, %{value: values}} when is_list(values) ->
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
      # Handle embedded field notation by converting URL-safe format to bracket notation
      converted_key = Cinder.Filter.Helpers.field_notation_from_url_safe(key)

      # Parse the field notation to check if it's an embedded field
      case Cinder.Filter.Helpers.parse_field_notation(converted_key) do
        {:embedded, embed_field, field_name} ->
          # Look up the embedded field attribute and then the nested field within it
          get_embedded_attribute(resource, embed_field, field_name)

        {:nested_embedded, embed_field, field_path} ->
          # Handle nested embedded fields
          get_nested_embedded_attribute(resource, embed_field, field_path)

        {:relationship, rel_path, field_name} ->
          # Handle relationship fields like "user.user_type" or "user.company.name"
          get_relationship_attribute(resource, rel_path, field_name)

        {:relationship_embedded, rel_path, embed_field, field_name} ->
          # Handle relationship + embedded fields
          get_relationship_embedded_attribute(resource, rel_path, embed_field, field_name)

        {:relationship_nested_embedded, rel_path, embed_field, field_path} ->
          # Handle relationship + nested embedded fields
          get_relationship_nested_embedded_attribute(resource, rel_path, embed_field, field_path)

        _ ->
          # Regular field lookup
          key_atom = if is_binary(key), do: String.to_atom(key), else: key
          get_regular_attribute(resource, key_atom)
      end
    rescue
      _ -> nil
    catch
      _ -> nil
    end
  end

  defp get_regular_attribute(resource, key_atom) do
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
  end

  defp get_embedded_attribute(resource, embed_field, field_name) do
    if Ash.Resource.Info.resource?(resource) do
      embed_atom = String.to_atom(embed_field)
      field_atom = String.to_atom(field_name)

      # Get the embedded resource attribute
      attributes = Ash.Resource.Info.attributes(resource)
      embed_attribute = Enum.find(attributes, &(&1.name == embed_atom))

      if embed_attribute && embed_attribute.type do
        # Get the embedded resource module
        embedded_resource = embed_attribute.type

        # Check if the embedded resource has the field
        if Ash.Resource.Info.resource?(embedded_resource) do
          embedded_attributes = Ash.Resource.Info.attributes(embedded_resource)
          nested_attribute = Enum.find(embedded_attributes, &(&1.name == field_atom))
          nested_attribute
        else
          nil
        end
      else
        nil
      end
    else
      nil
    end
  end

  defp get_nested_embedded_attribute(resource, embed_field, field_path) do
    if Ash.Resource.Info.resource?(resource) do
      embed_atom = String.to_atom(embed_field)

      # Get the embedded resource attribute
      attributes = Ash.Resource.Info.attributes(resource)
      embed_attribute = Enum.find(attributes, &(&1.name == embed_atom))

      if embed_attribute && embed_attribute.type do
        # Navigate through the nested path
        traverse_embedded_path(embed_attribute.type, field_path)
      else
        nil
      end
    else
      nil
    end
  end

  defp get_relationship_embedded_attribute(resource, rel_path, embed_field, field_name) do
    # Navigate to the related resource first
    related_resource = traverse_relationship_path(resource, rel_path)

    if related_resource do
      get_embedded_attribute(related_resource, embed_field, field_name)
    else
      nil
    end
  end

  defp get_relationship_nested_embedded_attribute(resource, rel_path, embed_field, field_path) do
    # Navigate to the related resource first
    related_resource = traverse_relationship_path(resource, rel_path)

    if related_resource do
      get_nested_embedded_attribute(related_resource, embed_field, field_path)
    else
      nil
    end
  end

  defp traverse_embedded_path(current_resource, [field_name]) do
    # Final field in the path
    if Ash.Resource.Info.resource?(current_resource) do
      field_atom = String.to_atom(field_name)
      attributes = Ash.Resource.Info.attributes(current_resource)
      Enum.find(attributes, &(&1.name == field_atom))
    else
      nil
    end
  end

  defp traverse_embedded_path(current_resource, [field_name | rest]) do
    # Navigate to the next embedded resource
    if Ash.Resource.Info.resource?(current_resource) do
      field_atom = String.to_atom(field_name)
      attributes = Ash.Resource.Info.attributes(current_resource)
      attribute = Enum.find(attributes, &(&1.name == field_atom))

      if attribute && attribute.type do
        traverse_embedded_path(attribute.type, rest)
      else
        nil
      end
    else
      nil
    end
  end

  defp get_relationship_attribute(resource, rel_path, field_name) do
    # Navigate to the related resource first
    related_resource = traverse_relationship_path(resource, rel_path)

    if related_resource do
      field_atom = String.to_atom(field_name)
      get_regular_attribute(related_resource, field_atom)
    else
      nil
    end
  end

  defp traverse_relationship_path(resource, [rel_name]) do
    # Final relationship in the path
    if Ash.Resource.Info.resource?(resource) do
      rel_atom = String.to_atom(rel_name)
      relationships = Ash.Resource.Info.relationships(resource)
      relationship = Enum.find(relationships, &(&1.name == rel_atom))

      if relationship do
        relationship.destination
      else
        nil
      end
    else
      nil
    end
  end

  defp traverse_relationship_path(resource, [rel_name | rest]) do
    # Navigate to the next related resource
    if Ash.Resource.Info.resource?(resource) do
      rel_atom = String.to_atom(rel_name)
      relationships = Ash.Resource.Info.relationships(resource)
      relationship = Enum.find(relationships, &(&1.name == rel_atom))

      if relationship do
        traverse_relationship_path(relationship.destination, rest)
      else
        nil
      end
    else
      nil
    end
  end

  defp enhance_select_options(default_options, attribute, key) do
    case extract_enum_options(attribute) do
      [] ->
        # No enum options found, return defaults
        # Convert URL-safe notation to bracket notation for proper humanization
        converted_key = Cinder.Filter.Helpers.field_notation_from_url_safe(key)
        humanized_key = Cinder.Filter.Helpers.humanize_embedded_field(converted_key)

        Keyword.merge(default_options, prompt: "All #{humanized_key}")

      options ->
        # Add enum options and prompt
        # Convert URL-safe notation to bracket notation for proper humanization
        converted_key = Cinder.Filter.Helpers.field_notation_from_url_safe(key)
        humanized_key = Cinder.Filter.Helpers.humanize_embedded_field(converted_key)

        default_options
        |> Keyword.put(:options, options)
        |> Keyword.put(:prompt, "All #{humanized_key}")
    end
  end

  @doc """
  Extracts enum options from Ash resource attribute.

  This function is public for testing purposes.
  """
  def extract_enum_options(nil), do: []

  def extract_enum_options(%{type: type, constraints: constraints}) do
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

  def extract_enum_options(%{type: {:one_of, values}}) when is_list(values) do
    enum_to_options(values, nil)
  end

  def extract_enum_options(_), do: []

  defp enum_to_options(values, enum_module) do
    Enum.map(values, fn value ->
      case value do
        atom when is_atom(atom) ->
          label =
            if enum_module && function_exported?(enum_module, :description, 1) do
              case apply(enum_module, :description, [atom]) do
                nil -> Cinder.Filter.humanize_atom(atom)
                description -> description
              end
            else
              Cinder.Filter.humanize_atom(atom)
            end

          {label, atom}

        string when is_binary(string) ->
          {String.capitalize(string), string}

        {value, label} ->
          {to_string(label), value}

        other ->
          {to_string(other), other}
      end
    end)
  end
end
