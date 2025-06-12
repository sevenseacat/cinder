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
      iex> columns = [%{key: "title", filterable: true, filter_type: :text}]
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
    |> Enum.map(fn {key, filter} ->
      encoded_value =
        case filter.type do
          :multi_select when is_list(filter.value) ->
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
      column = Enum.find(columns, &(&1.key == string_key))

      if column && column.filterable && value != "" do
        filter_type = column.filter_type

        decoded_value =
          case filter_type do
            :multi_select ->
              String.split(value, ",")

            :date_range ->
              case String.split(value, ",") do
                [from, to] -> %{from: from, to: to}
                [from] -> %{from: from, to: ""}
                _ -> %{from: "", to: ""}
              end

            :number_range ->
              case String.split(value, ",") do
                [min, max] -> %{min: min, max: max}
                [min] -> %{min: min, max: ""}
                _ -> %{min: "", max: ""}
              end

            :boolean ->
              value

            _ ->
              value
          end

        operator =
          case filter_type do
            :text -> :contains
            :select -> :equals
            :multi_select -> :in
            :boolean -> :equals
            :date_range -> :between
            :number_range -> :between
            _ -> :equals
          end

        Map.put(acc, string_key, %{
          type: filter_type,
          value: decoded_value,
          operator: operator
        })
      else
        acc
      end
    end)
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
    sort_by
    |> Enum.map(fn {key, direction} ->
      case direction do
        :desc -> "-#{key}"
        _ -> key
      end
    end)
    |> Enum.join(",")
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
    |> Enum.filter(&(&1.filterable and &1.filter_type == :multi_select))
    |> Enum.reduce(filter_params, fn column, acc ->
      # If multi-select field is missing (all checkboxes unchecked), add it as empty array
      if not Map.has_key?(acc, column.key) do
        Map.put(acc, column.key, [])
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
end
