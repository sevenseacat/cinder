defmodule Cinder.UrlManager do
  @moduledoc """
  URL state management for Cinder table components.

  Handles encoding and decoding of table state (filters, pagination, sorting)
  to/from URL parameters for browser history and bookmark support.
  """

  @type filter_value ::
          String.t()
          | [String.t()]
          | %{from: String.t(), to: String.t()}
          | %{min: String.t(), max: String.t()}
  @type filter :: %{type: atom(), value: filter_value(), operator: atom()}
  @type sort_by :: [{String.t(), :asc | :desc}]
  @type table_state :: %{
          filters: %{String.t() => filter()},
          current_page: integer(),
          sort_by: sort_by()
        }
  @type url_params :: %{atom() => String.t()}

  @doc """
  Encodes table state into URL parameters.

  ## Examples

      iex> state = %{
      ...>   filters: %{"title" => %{type: :text, value: "test", operator: :contains}},
      ...>   current_page: 2,
      ...>   sort_by: [{"title", :desc}]
      ...> }
      iex> Cinder.UrlManager.encode_state(state)
      %{title: "test", page: "2", sort: "-title"}

  """
  def encode_state(%{filters: filters, current_page: current_page, sort_by: sort_by}) do
    encoded_filters = encode_filters(filters)

    state =
      if current_page > 1 do
        Map.put(encoded_filters, :page, to_string(current_page))
      else
        encoded_filters
      end

    if not Enum.empty?(sort_by) do
      Map.put(state, :sort, encode_sort(sort_by))
    else
      state
    end
  end

  @doc """
  Decodes URL parameters into table state components.

  Takes URL parameters and column definitions to properly decode filter values
  based on their types.

  ## Examples

      iex> url_params = %{"title" => "test", "page" => "2", "sort" => "-title"}
      iex> columns = [%{field: "title", filterable: true, filter_type: :text}]
      iex> Cinder.UrlManager.decode_state(url_params, columns)
      %{
        filters: %{"title" => %{type: :text, value: "test", operator: :contains}},
        current_page: 2,
        sort_by: [{"title", :desc}]
      }

  """
  def decode_state(url_params, columns) do
    %{
      filters: decode_filters(url_params, columns),
      current_page: decode_page(Map.get(url_params, "page")),
      sort_by: decode_sort(Map.get(url_params, "sort"))
    }
  end

  @doc """
  Encodes filters for URL parameters.

  Converts filter values to strings appropriate for URL encoding.
  Different filter types are encoded differently:
  - Multi-select: comma-separated values
  - Date/number ranges: "from,to" or "min,max" format
  - Others: string representation
  """
  def encode_filters(filters) when is_map(filters) do
    filters
    |> Enum.filter(fn
      {_key, filter} when is_map(filter) -> 
        Map.has_key?(filter, :type) and not is_nil(Map.get(filter, :type))
      _ -> false
    end)
    |> Enum.map(fn {key, filter} ->
      encoded_value =
        case Map.get(filter, :type) do
          :multi_select ->
            value = Map.get(filter, :value, [])
            if is_list(value) do
              Enum.join(value, ",")
            else
              to_string(value)
            end

          :multi_checkboxes ->
            value = Map.get(filter, :value, [])
            if is_list(value) do
              Enum.join(value, ",")
            else
              to_string(value)
            end

          :date_range ->
            value = Map.get(filter, :value, %{})
            if is_map(value) do
              "#{Map.get(value, :from, "")},#{Map.get(value, :to, "")}"
            else
              to_string(value)
            end

          :number_range ->
            value = Map.get(filter, :value, %{})
            if is_map(value) do
              "#{Map.get(value, :min, "")},#{Map.get(value, :max, "")}"
            else
              to_string(value)
            end

          _ ->
            to_string(Map.get(filter, :value, ""))
        end

      # Safely convert key to atom
      atom_key = 
        cond do
          is_atom(key) -> key
          is_binary(key) -> String.to_atom(key)
          true -> String.to_atom(to_string(key))
        end

      {atom_key, encoded_value}
    end)
    |> Enum.into(%{})
  end

  @doc """
  Decodes filters from URL parameters using column definitions.

  Uses column metadata to properly parse filter values according to their types.
  """
  def decode_filters(url_params, columns) when is_map(url_params) and is_list(columns) do
    url_params
    |> Enum.reduce(%{}, fn {key, value}, acc ->
      # Convert string keys to match column keys
      string_key = to_string(key)
      column = Enum.find(columns, &(&1.field == string_key))

      if column && column.filterable && value != "" do
        filter_type = column.filter_type

        # Preprocess URL values for specific filter types
        processed_value = preprocess_url_value(value, filter_type)

        # Use filter module's process/2 function to properly decode the value
        filter_module = Cinder.Filters.Registry.get_filter(filter_type)

        if filter_module do
          try do
            decoded_filter = filter_module.process(processed_value, column)

            if decoded_filter do
              Map.put(acc, string_key, decoded_filter)
            else
              acc
            end
          rescue
            error ->
              require Logger

              Logger.error(
                "Error processing URL filter value for #{filter_type}: #{inspect(error)}. " <>
                  "Skipping invalid filter."
              )

              acc
          end
        else
          require Logger
          Logger.warning("Unknown filter type: #{filter_type}. Skipping filter.")
          acc
        end
      else
        acc
      end
    end)
  end

  # Preprocesses URL values based on filter type before passing to filter modules
  defp preprocess_url_value(value, filter_type) do
    case filter_type do
      type when type in [:multi_select, :multi_checkboxes] ->
        # Split comma-separated values for multi-select filters
        String.split(value, ",")

      _ ->
        # For other types, use the value as-is
        value
    end
  end

  @doc """
  Encodes sort state for URL parameters.

  Converts sort tuples to Ash-compatible sort string format.
  Descending sorts are prefixed with "-".

  ## Examples

      iex> Cinder.UrlManager.encode_sort([{"title", :desc}, {"created_at", :asc}])
      "-title,created_at"

  """
  def encode_sort(sort_by) when is_list(sort_by) do
    # Validate sort_by input to prevent Protocol.UndefinedError
    unless Enum.all?(sort_by, &valid_sort_tuple?/1) do
      require Logger

      Logger.warning(
        "Invalid sort_by format in encode_sort: #{inspect(sort_by)}. Expected list of {field, direction} tuples."
      )

      ""
    else
      sort_by
      |> Enum.map(fn {key, direction} ->
        case direction do
          :desc -> "-#{key}"
          _ -> key
        end
      end)
      |> Enum.join(",")
    end
  end

  @doc """
  Decodes sort string from URL parameters.

  Parses Ash sort string format into sort tuples.
  Fields prefixed with "-" are descending, others are ascending.

  ## Examples

      iex> Cinder.UrlManager.decode_sort("-title,created_at")
      [{"title", :desc}, {"created_at", :asc}]

  """
  def decode_sort(url_sort) when is_binary(url_sort) do
    url_sort
    |> String.split(",")
    |> Enum.filter(&(&1 != ""))
    |> Enum.map(fn sort_item ->
      case String.starts_with?(sort_item, "-") do
        true ->
          key = String.slice(sort_item, 1..-1//1)
          {key, :desc}

        false ->
          {sort_item, :asc}
      end
    end)
  end

  def decode_sort(nil), do: []
  def decode_sort(""), do: []

  @doc """
  Decodes page number from URL parameter.

  Returns 1 for invalid or missing page parameters.

  ## Examples

      iex> Cinder.UrlManager.decode_page("5")
      5

      iex> Cinder.UrlManager.decode_page("invalid")
      1

      iex> Cinder.UrlManager.decode_page(nil)
      1

  """
  def decode_page(page_param) when is_binary(page_param) do
    case Integer.parse(page_param) do
      {page, ""} when page > 0 -> page
      _ -> 1
    end
  end

  def decode_page(nil), do: 1
  def decode_page(_), do: 1

  @doc """
  Sends state change notification to parent LiveView.

  Used by components to notify their parent when table state changes,
  allowing the parent to update the URL accordingly.
  """
  def notify_state_change(socket, state) do
    if socket.assigns[:on_state_change] do
      encoded_state = encode_state(state)
      # Send to the current LiveView process
      send(self(), {socket.assigns.on_state_change, socket.assigns.id, encoded_state})
    end

    socket
  end

  @doc """
  Ensures multi-select fields are included in filter parameters.

  Multi-select filters that have no selected values need to be explicitly
  included as empty arrays to distinguish from filters that weren't processed.
  """
  def ensure_multiselect_fields(filter_params, columns)
      when is_map(filter_params) and is_list(columns) do
    columns
    |> Enum.filter(&(&1.filterable and &1.filter_type in [:multi_select, :multi_checkboxes]))
    |> Enum.reduce(filter_params, fn column, acc ->
      # If multi-select field is missing (all checkboxes unchecked), add it as empty array
      if not Map.has_key?(acc, column.field) do
        Map.put(acc, column.field, [])
      else
        acc
      end
    end)
  end

  @doc """
  Validates URL parameters for potential security issues.

  Performs basic validation to ensure URL parameters are safe to process.
  Returns {:ok, params} for valid parameters or {:error, reason} for invalid ones.
  """
  def validate_url_params(params) when is_map(params) do
    # Basic validation - check for reasonable parameter sizes
    max_param_length = 1000
    max_params_count = 50

    cond do
      map_size(params) > max_params_count ->
        {:error, "Too many URL parameters"}

      Enum.any?(params, fn {_key, value} -> String.length(to_string(value)) > max_param_length end) ->
        {:error, "URL parameter too long"}

      true ->
        {:ok, params}
    end
  end

  def validate_url_params(_), do: {:error, "Invalid URL parameters format"}

  # Validates that a sort tuple has the correct format for URL encoding.
  defp valid_sort_tuple?({field, direction}) when is_binary(field) and direction in [:asc, :desc],
    do: true

  defp valid_sort_tuple?(_), do: false
end
