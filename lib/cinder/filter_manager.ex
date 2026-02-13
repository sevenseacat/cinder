defmodule Cinder.FilterManager do
  @moduledoc """
  Coordinator for Cinder's modular filter system.

  Acts as the main interface for filter operations while delegating
  to individual filter type modules for specific implementations.
  """

  use Phoenix.Component

  alias Cinder.Filters.Registry
  use Cinder.Messages

  import Cinder.Filter, only: [filter_id: 2, filter_id: 3]

  @type filter_type ::
          :text
          | :select
          | :multi_select
          | :multi_checkboxes
          | :date_range
          | :number_range
          | :boolean
          | :radio_group
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
    raw_filter_params = Map.get(assigns, :raw_filter_params, %{})

    assigns =
      assigns
      |> assign(:filterable_columns, filterable_columns)
      |> assign(:active_filters, active_filters)
      |> assign(:filter_values, filter_values)
      |> assign(:raw_filter_params, raw_filter_params)

    ~H"""
    <!-- Filter Controls (including search) -->
    <div :if={@filterable_columns != [] or Map.get(assigns, :show_search, false)} class={@theme.filter_container_class} data-key="filter_container_class">
      <!-- Filter Header -->
      <div class={@theme.filter_header_class} data-key="filter_header_class">
        <span class={@theme.filter_title_class} data-key="filter_title_class">
          {@filters_label}
          <span class={[@theme.filter_count_class, if(@active_filters == 0, do: "invisible", else: "")]} data-key="filter_count_class">
            ({@active_filters} {dngettext("cinder", "active", "active", @active_filters)})
          </span>
        </span>
        <button
          :if={@filterable_columns != []}
          phx-click="clear_all_filters"
          phx-target={@target}
          class={[@theme.filter_clear_all_class, if(@active_filters == 0, do: "invisible", else: "")]}
          data-key="filter_clear_all_class"
        >
          {dgettext("cinder", "Clear all")}
        </button>
      </div>

      <form phx-change="filter_change" phx-submit="filter_change" phx-target={@target}>
        <div class={@theme.filter_inputs_class} data-key="filter_inputs_class">
          <!-- Search Input (if enabled) - as first filter -->
          <div :if={Map.get(assigns, :show_search, false)} class={@theme.filter_input_wrapper_class} data-key="filter_input_wrapper_class">
            <label for={filter_id(@table_id, "search")} class={@theme.filter_label_class} data-key="filter_label_class">{Map.get(assigns, :search_label, dgettext("cinder", "Search"))}:</label>
            <div class="flex items-center space-x-2">
              <div class="flex-1 relative">
                <input
                  type="text"
                  id={filter_id(@table_id, "search")}
                  name="search"
                  value={Map.get(assigns, :search_term, "")}
                  placeholder={Map.get(assigns, :search_placeholder, dgettext("cinder", "Search..."))}
                  phx-debounce="300"
                  class={@theme.search_input_class}
                  data-key="search_input_class"
                />
                <div class="absolute inset-y-0 left-0 z-10 flex items-center pl-3 pointer-events-none">
                  <svg class={@theme.search_icon_class} data-key="search_icon_class" fill="none" stroke="currentColor" viewBox="0 0 24 24">
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
                data-key="filter_clear_button_class"
                title={dgettext("cinder", "Clear search")}
              >
                ×
              </button>
            </div>
          </div>

          <div :for={column <- @filterable_columns} class={@theme.filter_input_wrapper_class} data-key="filter_input_wrapper_class">
            <.filter_label
              column={column}
              table_id={@table_id}
              theme={@theme}
            />
            <.filter_input
              column={column}
              table_id={@table_id}
              current_value={Map.get(@filter_values, column.field, "")}
              filter_values={@filter_values}
              raw_filter_params={@raw_filter_params}
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
  Renders a filter label with appropriate accessibility attributes based on filter type.
  """
  def filter_label(assigns) do
    ~H"""
    <label
      class={[
        @theme.filter_label_class,
        if(@column.filter_type == :checkbox, do: "invisible", else: "")
      ]}
      for={label_for_attr(@column.filter_type, @table_id, @column.field)}
      phx-click={label_click_action(@column.filter_type, @table_id, @column.field)}
      data-key="filter_label_class"
    >{filter_label_text(@column)}:</label>
    """
  end

  defp filter_label_text(column) do
    case Keyword.get(column.filter_options || [], :label) do
      nil -> column.label
      label -> label
    end
  end

  # For single-input filters, return the filter ID for the `for` attribute
  defp label_for_attr(filter_type, table_id, field) when filter_type in [:text, :autocomplete] do
    filter_id(table_id, field)
  end

  # For range filters, point to the first (min/from) input
  defp label_for_attr(:number_range, table_id, field), do: filter_id(table_id, field, "min")
  defp label_for_attr(:date_range, table_id, field), do: filter_id(table_id, field, "from")

  # For dropdown filters, point to the button
  defp label_for_attr(filter_type, table_id, field)
       when filter_type in [:select, :multi_select] do
    "#{filter_id(table_id, field)}-button"
  end

  # For group filters, no `for` attribute (inner labels work)
  defp label_for_attr(_filter_type, _table_id, _field), do: nil

  # No click action needed - `for` attribute handles focus/activation
  defp label_click_action(_filter_type, _table_id, _field), do: nil

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
          table_id: assigns.table_id,
          target: assigns.target,
          filter_values: assigns.filter_values,
          raw_filter_params: Map.get(assigns, :raw_filter_params, %{})
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

        filter_assigns = %{
          table_id: assigns.table_id,
          target: assigns.target,
          filter_values: assigns.filter_values
        }

        text_module.render(fallback_column, assigns.current_value, assigns.theme, filter_assigns)
      end

    # Wrap with clear button
    assigns = assign(assigns, :filter_content, filter_content)

    ~H"""
    <div class="flex items-center">
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
        data-key="filter_clear_button_class"
        title={dgettext("cinder", "Clear filter")}
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
    if Map.get(slot, :filterable, false) do
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
      # Use explicit label if provided, otherwise humanize the field key
      label =
        Map.get(slot, :label) ||
          key
          |> Cinder.Filter.Helpers.field_notation_from_url_safe()
          |> Cinder.Filter.Helpers.humanize_embedded_field()

      enhanced_options =
        case filter_type do
          :select -> enhance_select_options(merged_options, attribute, label)
          :multi_select -> enhance_select_options(merged_options, attribute, label)
          :multi_checkboxes -> enhance_select_options(merged_options, attribute, label)
          _ -> merged_options
        end

      %{filter_type: filter_type, filter_options: enhanced_options}
    else
      %{filter_type: :text, filter_options: []}
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
          get_regular_attribute(resource, String.to_atom(key))
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
            :sum -> %{name: key_atom, type: aggregate.type || :integer}
            :avg -> %{name: key_atom, type: :decimal}
            :max -> %{name: key_atom, type: aggregate.type || :integer}
            :min -> %{name: key_atom, type: aggregate.type || :integer}
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

  defp enhance_select_options(options, attribute, label) do
    # Only set prompt if not already set to a truthy value
    options =
      if Keyword.get(options, :prompt) do
        options
      else
        Keyword.put(options, :prompt, dgettext("cinder", "All %{label}", label: label))
      end

    case extract_enum_options(attribute) do
      [] ->
        # No enum options found, return as-is
        options

      enum_options ->
        # Add enum options if not already set to a non-empty list
        if Keyword.get(options, :options, []) != [] do
          options
        else
          Keyword.put(options, :options, enum_options)
        end
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
            if enum_module && function_exported?(enum_module, :label, 1) do
              case apply(enum_module, :label, [atom]) do
                nil -> Cinder.Filter.humanize_atom(atom)
                label -> label
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
