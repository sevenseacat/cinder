defmodule Cinder.QueryBuilder do
  @moduledoc """
  Query building functionality for Cinder table components.

  Handles the construction of Ash queries with filters, sorting, and pagination
  for table data loading.
  """

  require Ash.Query
  require Logger

  @type filter :: %{type: atom(), value: any(), operator: atom()}
  @type filters :: %{String.t() => filter()}
  @type sort_by :: [{String.t(), :asc | :desc}]
  @type column :: %{
          field: String.t(),
          filterable: boolean(),
          filter_type: atom(),
          filter_fn: function() | nil,
          sort_fn: function() | nil
        }
  @type query_opts :: keyword()

  @doc """
  Builds a complete query with filters, sorting, and pagination.

  ## Parameters
  - `resource`: The Ash resource to query
  - `options`: Query building options including:
    - `:actor` - The current user/actor
    - `:filters` - Filter map
    - `:sort_by` - Sort specifications
    - `:page_size` - Number of records per page
    - `:current_page` - Current page number
    - `:columns` - Column definitions
    - `:query_opts` - Additional Ash query options

  ## Returns
  A tuple `{:ok, {results, page_info}}` or `{:error, reason}`
  """
  def build_and_execute(resource, options) do
    actor = Keyword.fetch!(options, :actor)
    filters = Keyword.get(options, :filters, %{})
    sort_by = Keyword.get(options, :sort_by, [])
    page_size = Keyword.get(options, :page_size, 25)
    current_page = Keyword.get(options, :current_page, 1)
    columns = Keyword.get(options, :columns, [])
    query_opts = Keyword.get(options, :query_opts, [])

    try do
      # Build the query with pagination, sorting, and filtering using Ash.Query.page
      query =
        resource
        |> Ash.Query.for_read(:read, %{}, actor: actor)
        |> apply_query_opts(query_opts)
        |> apply_filters(filters, columns)
        |> apply_sorting(sort_by, columns)
        |> Ash.Query.page(
          limit: page_size,
          offset: (current_page - 1) * page_size,
          count: true
        )

      # Execute the query to get paginated results with count in a single query
      case Ash.read(query, actor: actor) do
        {:ok, %{results: results, count: total_count}} ->
          page_info =
            build_page_info_with_total_count(results, current_page, page_size, total_count)

          {:ok, {results, page_info}}

        {:error, query_error} ->
          # Log query execution error with full context
          Logger.error(
            "Cinder table query execution failed for #{inspect(resource)}: #{inspect(query_error)}",
            %{
              resource: resource,
              filters: filters,
              sort_by: sort_by,
              current_page: current_page,
              page_size: page_size,
              query_opts: query_opts,
              error: inspect(query_error)
            }
          )

          {:error, query_error}
      end
    rescue
      error ->
        # Log exceptions (like calculation errors) with full context
        Logger.error(
          "Cinder table query crashed with exception for #{inspect(resource)}: #{inspect(error)}",
          %{
            resource: resource,
            filters: filters,
            sort_by: sort_by,
            current_page: current_page,
            page_size: page_size,
            query_opts: query_opts,
            exception: inspect(error),
            stacktrace: Exception.format_stacktrace(__STACKTRACE__)
          }
        )

        {:error, error}
    end
  end

  @doc """
  Applies query options like load and select to an Ash query.
  """
  def apply_query_opts(query, opts) do
    Enum.reduce(opts, query, fn
      {:load, load_opts}, query ->
        Ash.Query.load(query, load_opts)

      {:select, select_opts}, query ->
        Ash.Query.select(query, select_opts)

      {:filter, _filter_opts}, query ->
        # Filters now handled in apply_filters/3 function
        query

      _other, query ->
        query
    end)
  end

  @doc """
  Applies filters to an Ash query based on filter configuration and column definitions.
  """
  def apply_filters(query, filters, _columns) when filters == %{}, do: query

  def apply_filters(query, filters, columns) do
    Enum.reduce(filters, query, fn {field, filter_config}, query ->
      column = Enum.find(columns, &(&1.field == field))

      cond do
        column && column.filter_fn ->
          # Use custom filter function
          column.filter_fn.(query, filter_config)

        true ->
          # Apply standard filter based on type
          apply_standard_filter(query, field, filter_config, column)
      end
    end)
  end

  @doc """
  Applies standard filters by delegating to the appropriate filter module.
  """
  def apply_standard_filter(query, key, filter_config, _column) do
    %{type: type} = filter_config

    # Get the filter module from registry (includes both built-in and custom)
    case Cinder.Filters.Registry.get_filter(type) do
      nil ->
        require Logger
        Logger.warning("Unknown filter type: #{type}")
        query

      filter_module ->
        try do
          filter_module.build_query(query, key, filter_config)
        rescue
          error ->
            require Logger
            Logger.error("Error building query for filter #{type}: #{inspect(error)}")
            query
        end
    end
  end

  @doc """
  Applies sorting to an Ash query based on sort specifications and column definitions.
  """
  def apply_sorting(query, sort_by, _columns) when sort_by == [], do: query

  def apply_sorting(query, sort_by, columns) do
    # Validate sort_by input to prevent Protocol.UndefinedError
    unless is_list(sort_by) and Enum.all?(sort_by, &valid_sort_tuple?/1) do
      require Logger

      Logger.warning(
        "Invalid sort_by format: #{inspect(sort_by)}. Expected list of {field, direction} tuples."
      )

      query
    else
      # Check if any sorts have custom sort functions
      has_custom_sorts =
        sort_by
        |> Enum.any?(fn {field, _direction} ->
          column = Enum.find(columns, &(&1.field == field))
          column && column.sort_fn
        end)

      if has_custom_sorts do
        # Use custom logic when custom sort functions are present
        Enum.reduce(sort_by, query, fn {field, direction}, query ->
          column = Enum.find(columns, &(&1.field == field))

          cond do
            column && column.sort_fn ->
              # Use custom sort function
              column.sort_fn.(query, direction)

            String.contains?(field, ".") ->
              # Handle dot notation for relationship sorting
              sort_expr = build_expression_sort(field)
              Ash.Query.sort(query, [{sort_expr, direction}])

            true ->
              # Standard attribute sorting
              Ash.Query.sort(query, [{String.to_atom(field), direction}])
          end
        end)
      else
        # Use Ash sort input for standard sorting (more efficient)
        sort_list =
          Enum.map(sort_by, fn {field, direction} ->
            {String.to_atom(field), direction}
          end)

        if not Enum.empty?(sort_list) do
          Ash.Query.sort(query, sort_list)
        else
          query
        end
      end
    end
  end

  # Validates that a sort tuple has the correct format.
  defp valid_sort_tuple?({field, direction}) when is_binary(field) and direction in [:asc, :desc],
    do: true

  defp valid_sort_tuple?(_), do: false

  @doc """
  Builds expression sort for relationship fields using dot notation.
  """
  def build_expression_sort(key) do
    # Convert "author.name" to expression sort
    parts = String.split(key, ".")

    case parts do
      [rel, field] ->
        # For now, create a simple expression - this may need adjustment based on Ash version
        {String.to_atom(rel), String.to_atom(field)}

      [rel, field | _] ->
        # Handle complex nested fields by taking first two parts
        {String.to_atom(rel), String.to_atom(field)}

      _ ->
        String.to_atom(key)
    end
  end

  @doc """
  Toggles sort direction for a given key in the sort specification.

  Cycles through: none → ascending → descending → none
  """
  def toggle_sort_direction(current_sort, key) do
    case Enum.find(current_sort, fn {sort_key, _direction} -> sort_key == key end) do
      {^key, :asc} ->
        # Currently ascending, change to descending
        Enum.map(current_sort, fn
          {^key, :asc} -> {key, :desc}
          other -> other
        end)

      {^key, :desc} ->
        # Currently descending, remove sort
        Enum.reject(current_sort, fn {sort_key, _direction} -> sort_key == key end)

      nil ->
        # Not currently sorted, add ascending sort
        [{key, :asc} | current_sort]
    end
  end

  @doc """
  Gets the current sort direction for a given key.
  """
  def get_sort_direction(sort_by, key) do
    case Enum.find(sort_by, fn {sort_key, _direction} -> sort_key == key end) do
      {^key, direction} -> direction
      nil -> nil
    end
  end

  @doc """
  Builds pagination info from query results and total count.
  """
  def build_page_info_with_total_count(results, current_page, page_size, total_count) do
    total_pages = max(1, ceil(total_count / page_size))
    start_index = (current_page - 1) * page_size + 1
    actual_end_index = start_index + length(results) - 1

    %{
      current_page: current_page,
      total_pages: total_pages,
      total_count: total_count,
      has_next_page: current_page < total_pages,
      has_previous_page: current_page > 1,
      start_index: if(total_count > 0, do: start_index, else: 0),
      end_index: if(total_count > 0, do: max(actual_end_index, 0), else: 0)
    }
  end

  @doc """
  Builds error pagination info for failed queries.
  """
  def build_error_page_info do
    %{
      current_page: 1,
      total_pages: 1,
      total_count: 0,
      has_next_page: false,
      has_previous_page: false,
      start_index: 0,
      end_index: 0
    }
  end
end
