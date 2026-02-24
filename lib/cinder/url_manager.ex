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
          sort_by: sort_by(),
          page_size: integer(),
          default_page_size: integer(),
          search_term: String.t()
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
  def encode_state(%{filters: filters, sort_by: sort_by} = state) do
    encoded_filters = encode_filters(filters)

    # Handle pagination state based on mode
    # For keyset pagination, we store after/before cursors; for offset, we store page number
    state_with_page =
      cond do
        # Keyset pagination with after cursor
        is_binary(Map.get(state, :after)) and Map.get(state, :after) != "" ->
          Map.put(encoded_filters, :after, state.after)

        # Keyset pagination with before cursor
        is_binary(Map.get(state, :before)) and Map.get(state, :before) != "" ->
          Map.put(encoded_filters, :before, state.before)

        # Offset pagination - store page number
        true ->
          current_page = Map.get(state, :current_page, 1)

          if current_page > 1 do
            Map.put(encoded_filters, :page, to_string(current_page))
          else
            encoded_filters
          end
      end

    # Add page_size if different from default
    state_with_page_size =
      case {Map.get(state, :page_size), Map.get(state, :default_page_size)} do
        {page_size, default_page_size}
        when is_integer(page_size) and is_integer(default_page_size) and
               page_size != default_page_size ->
          Map.put(state_with_page, :page_size, to_string(page_size))

        _ ->
          state_with_page
      end

    state_with_sort =
      if Enum.empty?(sort_by) do
        state_with_page_size
      else
        Map.put(state_with_page_size, :sort, encode_sort(sort_by))
      end

    # Add search if not empty
    search_term = Map.get(state, :search_term)

    state_with_search =
      if search_term in [nil, ""] do
        state_with_sort
      else
        Map.put(state_with_sort, :search, search_term)
      end

    # Add filter field names for UrlSync to know which params are table-managed
    filter_field_names = Map.get(state, :filter_field_names, [])

    if Enum.empty?(filter_field_names) do
      state_with_search
    else
      Map.put(state_with_search, :_filter_fields, Enum.join(filter_field_names, ","))
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
      sort_by: decode_sort(Map.get(url_params, "sort"), columns),
      page_size: decode_page_size(Map.get(url_params, "page_size")),
      search_term: decode_search(Map.get(url_params, "search")),
      after: decode_cursor(Map.get(url_params, "after")),
      before: decode_cursor(Map.get(url_params, "before"))
    }
  end

  def get_filters(url_state) when is_map(url_state), do: Map.get(url_state, :filters, %{})
  def get_filters(_), do: %{}

  def get_search(url_state) do
    url_state
    |> get_filters()
    |> Map.get("search", "")
    |> decode_search()
  end

  # Decodes search parameter from URL
  defp decode_search(nil), do: ""
  defp decode_search(""), do: ""
  defp decode_search(search_term) when is_binary(search_term), do: search_term
  defp decode_search(_), do: ""

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
    |> Enum.map(fn {key, filter} ->
      encoded_value =
        case filter.type do
          :multi_select when is_list(filter.value) ->
            Enum.join(filter.value, ",")

          :multi_checkboxes when is_list(filter.value) ->
            Enum.join(filter.value, ",")

          :date_range ->
            "#{filter.value.from},#{filter.value.to}"

          :number_range ->
            "#{filter.value.min},#{filter.value.max}"

          _ ->
            to_string(filter.value)
        end

      {String.to_atom(key), encoded_value}
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

      iex> Cinder.UrlManager.encode_sort([{"payment_date", :desc_nils_last}, {"created_at", :asc_nils_first}])
      "--payment_date,++created_at"

      iex> Cinder.UrlManager.encode_sort([{"score", :asc_nils_last}, {"priority", :desc_nils_first}])
      "-+score,+-priority"

  """
  def encode_sort(sort_by) when is_list(sort_by) do
    # Validate sort_by input to prevent Protocol.UndefinedError
    if Enum.all?(sort_by, &valid_sort_tuple?/1) do
      Enum.map_join(sort_by, ",", fn {key, direction} ->
        case direction do
          :asc -> key
          :desc -> "-#{key}"
          :asc_nils_first -> "++#{key}"
          :desc_nils_first -> "+-#{key}"
          :asc_nils_last -> "-+#{key}"
          :desc_nils_last -> "--#{key}"
        end
      end)
    else
      require Logger

      Logger.warning(
        "Invalid sort_by format in encode_sort: #{inspect(sort_by)}. Expected list of {field, direction} tuples."
      )

      ""
    end
  end

  @doc """
  Decodes sort string from URL parameters.

  Parses Ash sort string format into sort tuples.
  Fields prefixed with "-" are descending, others are ascending.

  ## Examples

      iex> Cinder.UrlManager.decode_sort("-title,created_at")
      [{"title", :desc}, {"created_at", :asc}]

      iex> Cinder.UrlManager.decode_sort("--payment_date,++created_at")
      [{"payment_date", :desc_nils_last}, {"created_at", :asc_nils_first}]

      iex> Cinder.UrlManager.decode_sort("-+score,+-priority")
      [{"score", :asc_nils_last}, {"priority", :desc_nils_first}]

  """
  def decode_sort(url_sort, columns) when is_binary(url_sort) and is_list(columns) do
    url_sort
    |> parse_sort_string()
    |> filter_valid_sorts(columns)
  end

  def decode_sort(nil, _columns), do: []
  def decode_sort("", _columns), do: []

  # Backward compatibility - if called without columns, parse but don't validate
  def decode_sort(url_sort) when is_binary(url_sort) do
    parse_sort_string(url_sort)
  end

  def decode_sort(nil), do: []
  def decode_sort(""), do: []

  # Helper function to parse sort string into {field, direction} tuples
  defp parse_sort_string(url_sort) do
    url_sort
    |> String.split(",")
    |> Enum.filter(&(&1 != ""))
    |> Enum.map(fn sort_item ->
      cond do
        String.starts_with?(sort_item, "--") ->
          # Double dash: desc_nils_last
          key = String.slice(sort_item, 2..-1//1)
          {key, :desc_nils_last}

        String.starts_with?(sort_item, "++") ->
          # Double plus: asc_nils_first
          key = String.slice(sort_item, 2..-1//1)
          {key, :asc_nils_first}

        String.starts_with?(sort_item, "+-") ->
          # Plus-dash: desc_nils_first
          key = String.slice(sort_item, 2..-1//1)
          {key, :desc_nils_first}

        String.starts_with?(sort_item, "-+") ->
          # Dash-plus: asc_nils_last
          key = String.slice(sort_item, 2..-1//1)
          {key, :asc_nils_last}

        String.starts_with?(sort_item, "-") ->
          # Single dash: desc
          key = String.slice(sort_item, 1..-1//1)
          {key, :desc}

        true ->
          # Default: field means asc
          {sort_item, :asc}
      end
    end)
  end

  # Helper function to filter sorts based on column definitions
  defp filter_valid_sorts(sorts, columns) do
    if Enum.empty?(columns) do
      sorts
    else
      Enum.filter(sorts, fn {field, _direction} ->
        field_sortable?(field, columns)
      end)
    end
  end

  # Helper function to check if a field is sortable
  defp field_sortable?(field, columns) do
    case Enum.find(columns, &(&1.field == field)) do
      nil -> false
      column when is_map(column) -> Map.get(column, :sortable, true)
      _column -> true
    end
  end

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
  Decodes page size from URL parameter.

  Returns 25 for invalid or missing page_size parameters.

  ## Examples

      iex> Cinder.UrlManager.decode_page_size("50")
      50

      iex> Cinder.UrlManager.decode_page_size("invalid")
      25

      iex> Cinder.UrlManager.decode_page_size(nil)
      25

  """
  def decode_page_size(page_size_param) when is_binary(page_size_param) do
    case Integer.parse(page_size_param) do
      {page_size, ""} when page_size > 0 -> page_size
      _ -> 25
    end
  end

  def decode_page_size(nil), do: 25
  def decode_page_size(_), do: 25

  @doc """
  Decodes keyset cursor from URL parameter for keyset pagination.

  Used for both `after` and `before` cursor parameters.
  Returns nil for missing or empty cursor parameters.

  ## Examples

      iex> Cinder.UrlManager.decode_cursor("g2wAAAABbQAAAARha3Vsag==")
      "g2wAAAABbQAAAARha3Vsag=="

      iex> Cinder.UrlManager.decode_cursor(nil)
      nil

      iex> Cinder.UrlManager.decode_cursor("")
      nil

  """
  def decode_cursor(nil), do: nil
  def decode_cursor(""), do: nil
  def decode_cursor(cursor) when is_binary(cursor), do: cursor
  def decode_cursor(_), do: nil

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
      if Map.has_key?(acc, column.field) do
        acc
      else
        Map.put(acc, column.field, [])
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
  # Supports standard and Ash built-in null handling directions.
  defp valid_sort_tuple?({field, direction})
       when is_binary(field) and
              direction in [
                :asc,
                :desc,
                :asc_nils_first,
                :desc_nils_first,
                :asc_nils_last,
                :desc_nils_last
              ],
       do: true

  defp valid_sort_tuple?(_), do: false
end
