# SPDX-FileCopyrightText: 2025 Cinder contributors <https://github.com/sevenseacat/cinder/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Cinder.Column do
  @moduledoc """
  Column configuration and type inference for Cinder table components.

  Parses columns, inferring filter types,
  sort capabilities, and display options from Ash resource definitions.
  Supports relationship fields using dot notation (e.g., "user.name").
  """

  require Logger

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
          filter_warning: String.t() | nil
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
    :filter_warning
  ]

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
        filter_warning: nil
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

      # A column asking for sorting or filtering it can't have. A warning for now: these
      # become errors in 1.0
      if sort_warning, do: Logger.warning("Cinder Column: #{sort_warning}")
      if filter_warning, do: Logger.warning("Cinder Column: #{filter_warning}")

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
        filter_warning: filter_warning
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
      e ->
        Logger.warning(
          "Cinder: Column inference failed for #{inspect(key)}: #{Exception.message(e)}"
        )

        default_column_config()
    catch
      _ -> default_column_config()
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
        {auto_sortable, auto_warning} = queryable(resource, field, "sorted")

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

  # Determines filterability based on field nature and user intent
  defp determine_filterability(resource_or_query, field, slot) do
    # Extract the actual resource from query or resource
    resource = extract_resource_from_query_or_resource(resource_or_query)

    # Check if a custom filter_fn is provided - if so, always allow filtering
    # since the user is providing their own filtering logic
    has_custom_filter_fn = Map.get(slot, :filter_fn) != nil

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
        # If there's a custom filter_fn, allow filtering regardless of field existence
        if has_custom_filter_fn do
          {true, nil}
        else
          # User explicitly wants filtering - check if it's possible
          {auto_filterable, auto_warning} = queryable(resource, field, "filtered")

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
  end

  # Whether a column can be sorted or filtered by its field, with the reason if not. With no
  # Ash resource there.s nothing to check against, so it.s allowed
  @doc false
  def queryable(resource, field, verb) do
    if is_atom(resource) and resource != nil and Ash.Resource.Info.resource?(resource) do
      with {:ok, resolved} <- Cinder.Field.resolve(resource, field),
           nil <- Cinder.Field.query_error(resolved) do
        {true, nil}
      else
        :error -> {false, "Field '#{field}' does not exist on #{inspect(resource)}."}
        reason -> {false, "Field '#{field}' #{reason}, so it can't be #{verb}."}
      end
    else
      {true, nil}
    end
  end
end
