defmodule Cinder.Column do
  @moduledoc """
  Column configuration and type inference for Cinder table components.

  Provides intelligent column parsing that can automatically infer filter types,
  sort capabilities, and display options from Ash resource definitions.
  Supports relationship fields using dot notation (e.g., "user.name").
  """

  @type t :: %__MODULE__{
          field: String.t(),
          label: String.t(),
          sortable: boolean(),
          filterable: boolean(),
          filter_type: atom(),
          filter_options: keyword(),
          class: String.t(),
          slot: map(),
          relationship: String.t() | nil,
          display_field: String.t() | nil,
          filter_fn: function() | nil,
          search_fn: function() | nil,
          searchable: boolean(),
          options: list(),
          sort_warning: String.t() | nil,
          filter_warning: String.t() | nil,
          global_attrs: keyword()
        }

  defstruct [
    :field,
    :label,
    :sortable,
    :filterable,
    :filter_type,
    :filter_options,
    :class,
    :slot,
    :relationship,
    :display_field,
    :filter_fn,
    :search_fn,
    :searchable,
    :options,
    :sort_warning,
    :filter_warning,
    global_attrs: []
  ]

  # Known slot attributes that are handled explicitly
  @known_slot_attrs [
    :field,
    :label,
    :filter,
    :filter_options,
    :sort,
    :search,
    :class,
    :__slot__,
    :inner_block
  ]

  @doc """
  Parses and normalizes column definitions from slots and resource information.

  ## Parameters
  - `slots` - List of column slot definitions
  - `resource` - Ash resource module for type inference

  ## Returns
  List of normalized Column structs
  """
  def parse_columns(slots, resource) when is_list(slots) do
    Enum.map(slots, fn slot ->
      parse_column(slot, resource)
    end)
  end

  @doc """
  Parses a single column definition with automatic type inference.
  """
  def parse_column(slot, resource) do
    field = Map.get(slot, :field)

    # Handle action columns without fields
    if is_nil(field) or field == "" do
      # For action columns, provide minimal defaults
      %__MODULE__{
        field: nil,
        label: Map.get(slot, :label, ""),
        sortable: false,
        filterable: false,
        filter_type: :text,
        filter_options: [],
        class: Map.get(slot, :class, ""),
        slot: slot,
        relationship: nil,
        display_field: nil,
        filter_fn: nil,
        search_fn: nil,
        searchable: false,
        options: [],
        sort_warning: nil,
        filter_warning: nil,
        global_attrs: extract_global_attrs(slot)
      }
    else
      # Parse relationship information if field contains dots
      {base_field, relationship_info} = parse_relationship_key(field)

      # Infer column configuration from Ash resource (only if slot allows filtering)
      inferred = infer_from_resource(resource, base_field, relationship_info, slot)

      # Merge slot configuration with inferred defaults
      merged_config = merge_config(slot, inferred)
      # Check if this field is a non-sortable calculation
      {sortable, sort_warning} = determine_sortability(resource, field, slot)

      # Check if this field is a non-filterable calculation
      {filterable, filter_warning} = determine_filterability(resource, field, slot)

      # Log warnings if calculation has issues
      if sort_warning do
        require Logger
        Logger.info("Cinder Column: #{sort_warning}")
      end

      if filter_warning do
        require Logger
        Logger.info("Cinder Column: #{filter_warning}")
      end

      # Create column struct
      %__MODULE__{
        field: field,
        label: Map.get(merged_config, :label, humanize_key(field)),
        sortable: sortable,
        filterable: filterable,
        filter_type: Map.get(merged_config, :filter_type, :text),
        filter_options: Map.get(merged_config, :filter_options, []),
        class: Map.get(slot, :class, ""),
        slot: slot,
        relationship: Map.get(relationship_info, :relationship),
        display_field: Map.get(relationship_info, :field),
        filter_fn: Map.get(merged_config, :filter_fn),
        search_fn: Map.get(merged_config, :search_fn),
        searchable: Map.get(merged_config, :searchable, false),
        options: Map.get(merged_config, :options, []),
        sort_warning: sort_warning,
        filter_warning: filter_warning,
        global_attrs: extract_global_attrs(slot)
      }
    end
  end

  @doc """
  Infers column configuration from Ash resource attribute definitions.
  """
  def infer_from_resource(resource, key, relationship_info \\ %{}, slot \\ %{}) do
    try do
      if Ash.Resource.Info.resource?(resource) do
        # Use existing FilterManager inference for backward compatibility
        # Only infer filter config if the slot allows filtering
        base_config =
          if Map.get(slot, :filterable, false) do
            filter_config = Cinder.FilterManager.infer_filter_config(key, resource, slot)

            %{
              sortable: Map.get(slot, :sortable, false),
              filterable: true,
              searchable: Map.get(slot, :search, false),
              filter_type: filter_config.filter_type,
              filter_options: filter_config.filter_options
            }
          else
            %{
              sortable: Map.get(slot, :sortable, false),
              filterable: false,
              searchable: Map.get(slot, :search, false),
              filter_type: :text,
              filter_options: []
            }
          end

        # Handle relationship fields if needed
        case relationship_info do
          %{relationship: _rel_name, field: _field_name} ->
            # For now, use the same inference - we can enhance this later
            base_config

          _ ->
            base_config
        end
      else
        default_column_config()
      end
    rescue
      _ -> default_column_config()
    catch
      _ -> default_column_config()
    end
  end

  @doc """
  Validates a column configuration.
  """
  def validate(%__MODULE__{} = column) do
    errors = []

    errors = if column.field in [nil, ""], do: ["Field cannot be empty" | errors], else: errors
    errors = if column.label in [nil, ""], do: ["Label cannot be empty" | errors], else: errors

    # Validate filter type
    valid_filter_types = [
      :text,
      :select,
      :multi_select,
      :multi_checkboxes,
      :boolean,
      :checkbox,
      :date_range,
      :number_range
    ]

    errors =
      if column.filter_type in valid_filter_types do
        errors
      else
        ["Invalid filter type: #{column.filter_type}" | errors]
      end

    case errors do
      [] -> {:ok, column}
      _ -> {:error, Enum.reverse(errors)}
    end
  end

  @doc """
  Merges slot configuration with inferred defaults.
  """
  def merge_config(slot, inferred) do
    # Slot configuration takes precedence over inferred values, but preserve
    # inferred filter_options when slot options are empty
    slot_config =
      Map.take(slot, [
        :label,
        :sortable,
        :filterable,
        :filter_type,
        :filter_options,
        :class,
        :filter_fn,
        :search_fn,
        :searchable,
        :options
      ])

    # Handle filter_options specially - merge slot options with inferred options
    slot_config =
      case Map.get(slot_config, :filter_options, []) do
        # Let inferred options take precedence when slot has no options
        [] ->
          Map.delete(slot_config, :filter_options)

        # Merge slot options with inferred options when slot has options
        slot_options ->
          inferred_options = Map.get(inferred, :filter_options, [])
          merged_options = Keyword.merge(inferred_options, slot_options)
          Map.put(slot_config, :filter_options, merged_options)
      end

    Map.merge(inferred, slot_config)
  end

  # Private helper functions

  defp extract_global_attrs(slot) when is_map(slot) do
    slot
    |> Map.drop(@known_slot_attrs)
    |> Enum.filter(fn {key, _value} ->
      key_str = to_string(key)

      String.starts_with?(key_str, "data-") or
        String.starts_with?(key_str, "aria-") or
        key in [:role, :title]
    end)
    |> Enum.to_list()
  end

  defp parse_relationship_key(field) when is_binary(field) do
    case String.split(field, ".", parts: 2) do
      [single_field] ->
        {single_field, %{}}

      [relationship, field_name] ->
        {field, %{relationship: relationship, field: field_name}}
    end
  end

  defp parse_relationship_key(field), do: {to_string(field), %{}}

  defp default_column_config do
    %{
      sortable: false,
      filterable: false,
      filter_type: :text,
      filter_options: [],
      searchable: false
    }
  end

  defp humanize_key(field) when is_binary(field) do
    field
    |> String.replace("_", " ")
    |> String.replace(".", " > ")
    |> String.split()
    |> Enum.map_join(" ", &String.capitalize/1)
  end

  defp humanize_key(field), do: humanize_key(to_string(field))

  # Extracts the resource from either an Ash.Query struct or a resource module.
  # This allows the column parsing to work with both queries and resource modules.
  defp extract_resource_from_query_or_resource(%Ash.Query{resource: resource}), do: resource
  defp extract_resource_from_query_or_resource(resource) when is_atom(resource), do: resource
  defp extract_resource_from_query_or_resource(other), do: other

  defp determine_sortability(resource_or_query, field, slot) do
    # Extract the actual resource from query or resource
    resource = extract_resource_from_query_or_resource(resource_or_query)

    # Check if the slot explicitly set sortable (user override)
    slot_sortable = Map.get(slot, :sortable)

    case slot_sortable do
      nil ->
        # No user request for sorting, default to false
        {false, nil}

      false ->
        # User explicitly disabled sorting
        {false, nil}

      true ->
        # User explicitly wants sorting - check if it's possible
        {auto_sortable, auto_warning} = determine_auto_sortability(resource, field)

        if auto_sortable do
          # User wants to enable sorting on something that can be sorted - OK
          {true, nil}
        else
          # User wants to enable sorting on something that can't be sorted
          # Keep it non-sortable and show the warning about why it can't work
          {false, auto_warning}
        end
    end
  end

  # Determines sortability based purely on the field's nature (ignoring user overrides)
  defp determine_auto_sortability(resource, field) do
    # Validate field existence first using comprehensive validation
    if Cinder.QueryBuilder.validate_field_existence(resource, field) do
      # Parse field to handle relationship calculations
      {target_resource, target_field} =
        Cinder.QueryBuilder.resolve_field_resource(resource, field)

      # Check if this field is a calculation on the target resource
      case Cinder.QueryBuilder.get_calculation_info(target_resource, target_field) do
        nil ->
          # Not a calculation, should be sortable
          {true, nil}

        calc ->
          if Cinder.QueryBuilder.calculation_sortable?(calc) do
            {true, nil}
          else
            warning =
              "Field '#{field}' is an in-memory calculation and cannot be sorted. " <>
                "Consider using expr() for database-level calculations that support sorting."

            {false, warning}
          end
      end
    else
      warning = "Field '#{field}' does not exist on #{inspect(resource)}."
      {false, warning}
    end
  end

  # Determines filterability based on field nature and user intent
  defp determine_filterability(resource_or_query, field, slot) do
    # Extract the actual resource from query or resource
    resource = extract_resource_from_query_or_resource(resource_or_query)

    # Check if the slot explicitly set filterable (user override)
    slot_filterable = Map.get(slot, :filterable)

    case slot_filterable do
      nil ->
        # No user request for filtering, default to false
        {false, nil}

      false ->
        # User explicitly disabled filtering
        {false, nil}

      true ->
        # User explicitly wants filtering - check if it's possible
        {auto_filterable, auto_warning} = determine_auto_filterability(resource, field)

        if auto_filterable do
          # User wants filtering on something that can be filtered - OK
          {true, nil}
        else
          # User wants filtering on something that can't be filtered
          # Keep it non-filterable and show the warning about why it can't work
          {false, auto_warning}
        end
    end
  end

  # Determines filterability based purely on the field's nature (ignoring user overrides)
  defp determine_auto_filterability(resource, field) do
    # Validate field existence first using comprehensive validation
    if Cinder.QueryBuilder.validate_field_existence(resource, field) do
      # Parse field to handle relationship calculations
      {target_resource, target_field} =
        Cinder.QueryBuilder.resolve_field_resource(resource, field)

      # Check if this field is a calculation on the target resource
      case Cinder.QueryBuilder.get_calculation_info(target_resource, target_field) do
        nil ->
          # Not a calculation, should be filterable
          {true, nil}

        calc ->
          if Cinder.QueryBuilder.calculation_sortable?(calc) do
            # Database-level calculations can be filtered
            {true, nil}
          else
            warning =
              "Field '#{field}' is an in-memory calculation and cannot be filtered. " <>
                "Consider using expr() for database-level calculations that support filtering."

            {false, warning}
          end
      end
    else
      warning = "Field '#{field}' does not exist on #{inspect(resource)}."
      {false, warning}
    end
  end
end
