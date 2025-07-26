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
          sort_fn: function() | nil,
          filter_fn: function() | nil,
          search_fn: function() | nil,
          searchable: boolean(),
          options: list()
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
    :sort_fn,
    :filter_fn,
    :search_fn,
    :searchable,
    :options
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
        sort_fn: nil,
        filter_fn: nil,
        search_fn: nil,
        searchable: false,
        options: []
      }
    else
      # Parse relationship information if field contains dots
      {base_field, relationship_info} = parse_relationship_key(field)

      # Infer column configuration from Ash resource (only if slot allows filtering)
      inferred = infer_from_resource(resource, base_field, relationship_info, slot)

      # Merge slot configuration with inferred defaults
      merged_config = merge_config(slot, inferred)

      # Create column struct
      %__MODULE__{
        field: field,
        label: Map.get(merged_config, :label, humanize_key(field)),
        sortable: Map.get(merged_config, :sortable, true),
        filterable: Map.get(merged_config, :filterable, false),
        filter_type: Map.get(merged_config, :filter_type, :text),
        filter_options: Map.get(merged_config, :filter_options, []),
        class: Map.get(merged_config, :class, ""),
        slot: slot,
        relationship: Map.get(relationship_info, :relationship),
        display_field: Map.get(relationship_info, :field),
        sort_fn: Map.get(merged_config, :sort_fn),
        filter_fn: Map.get(merged_config, :filter_fn),
        search_fn: Map.get(merged_config, :search_fn),
        searchable: Map.get(merged_config, :searchable, false),
        options: Map.get(merged_config, :options, [])
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
              sortable: true,
              filterable: true,
              searchable: false,
              filter_type: filter_config.filter_type,
              filter_options: filter_config.filter_options
            }
          else
            %{
              sortable: true,
              filterable: false,
              searchable: false,
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
      :date_range,
      :number_range
    ]

    errors =
      if column.filter_type not in valid_filter_types do
        ["Invalid filter type: #{column.filter_type}" | errors]
      else
        errors
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
        :sort_fn,
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
      sortable: true,
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
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end

  defp humanize_key(field), do: humanize_key(to_string(field))
end
