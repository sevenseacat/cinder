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
    - `:query_opts` - Additional Ash query and execution options

  ## Supported Query Options

  The `:query_opts` parameter accepts both query building and execution options:

  ### Query Building Options
  - `:select` - Select specific attributes (handled by `Ash.Query.select/2`)
  - `:load` - Load relationships and calculations (handled by `Ash.Query.load/2`)

  ### Execution Options
  These options are passed to both `Ash.Query.for_read/3` and `Ash.read/2`:
  - `:timeout` - Query timeout in milliseconds or `:infinity` (e.g., `:timer.seconds(30)`)
  - `:authorize?` - Whether to run authorization during query execution
  - `:max_concurrency` - Maximum number of processes for parallel loading

  ### Usage Examples

      # Simple timeout for long-running queries
      query_opts: [timeout: :timer.seconds(30)]

      # Query building options
      query_opts: [select: [:name, :email], load: [:posts]]

      # Combined query building and execution options
      query_opts: [
        timeout: :timer.seconds(20),
        authorize?: false,
        select: [:title, :content],
        load: [:author, :comments]
      ]

  ## Returns
  A tuple `{:ok, {results, page_info}}` or `{:error, reason}`
  """
  def build_and_execute(resource, options) do
    actor = Keyword.fetch!(options, :actor)
    tenant = Keyword.get(options, :tenant)
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
        |> Ash.Query.for_read(:read, %{}, build_ash_options(actor, tenant, query_opts))
        |> apply_query_opts(query_opts)
        |> apply_filters(filters, columns)
        |> apply_sorting(sort_by, columns)
        |> Ash.Query.page(
          limit: page_size,
          offset: (current_page - 1) * page_size,
          count: true
        )

      # Execute the query to get paginated results with count in a single query
      case Ash.read(query, build_ash_options(actor, tenant, query_opts)) do
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
              tenant: tenant,
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
            tenant: tenant,
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

      {:tenant, tenant}, query ->
        Ash.Query.set_tenant(query, tenant)

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

    # Convert URL-safe field notation to bracket notation
    field_name = Cinder.Filter.Helpers.field_notation_from_url_safe(key)

    # Get the filter module from registry (includes both built-in and custom)
    case Cinder.Filters.Registry.get_filter(type) do
      nil ->
        require Logger
        Logger.warning("Unknown filter type: #{type}")
        query

      filter_module ->
        try do
          filter_module.build_query(query, field_name, filter_config)
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
      # Clear any existing sorts to ensure table sorts take precedence
      # Only call unset on actual Ash.Query structs, not on resources
      query =
        if is_struct(query, Ash.Query) do
          Ash.Query.unset(query, :sort)
        else
          query
        end

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

  Provides a predictable three-step cycle:
  - none → ascending → descending → none

  When starting with extracted query sorts, use `toggle_sort_from_query/2`
  for better UX that handles the transition from query state to user control.
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
  Toggles sort direction with special handling for query-extracted sorts.

  When a column has a sort from query extraction, the first user click
  provides intuitive behavior:
  - desc (from query) → asc (user takes control)
  - asc (from query) → desc (user takes control)
  Then follows normal toggle cycle.

  This provides better UX when tables start with pre-sorted queries.
  """
  def toggle_sort_from_query(current_sort, key) do
    case Enum.find(current_sort, fn {sort_key, _direction} -> sort_key == key end) do
      {^key, :asc} ->
        # Currently ascending, change to descending
        Enum.map(current_sort, fn
          {^key, :asc} -> {key, :desc}
          other -> other
        end)

      {^key, :desc} ->
        # Currently descending, flip to ascending (better UX than removing)
        # This gives users the opposite direction first, then normal cycle
        Enum.map(current_sort, fn
          {^key, :desc} -> {key, :asc}
          other -> other
        end)

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

  # Build options for Ash.Query.for_read/3 and Ash.read/2
  defp build_ash_options(actor, tenant, query_opts) do
    [actor: actor]
    |> maybe_add_tenant(tenant)
    |> maybe_add_ash_options(query_opts)
  end

  @doc """
  Extracts sort information from an Ash query for table UI initialization.

  Takes an Ash query and returns sort information in the format expected by
  the table component: `[{field_name, direction}]`

  ## Parameters
  - `query` - An Ash.Query struct or resource module
  - `columns` - Column definitions to map query sorts to table fields

  ## Returns
  A list of `{field_name, direction}` tuples where:
  - `field_name` is a string matching table column field names
  - `direction` is `:asc` or `:desc`

  ## Examples

      # Query with sorts
      query = User |> Ash.Query.for_read(:read) |> Ash.Query.sort([{:name, :desc}, {:created_at, :asc}])
      extract_query_sorts(query, columns)
      # => [{"name", :desc}, {"created_at", :asc}]

      # Resource module (no sorts)
      extract_query_sorts(User, columns)
      # => []
  """
  def extract_query_sorts(query, columns \\ [])

  def extract_query_sorts(query, _columns) when is_atom(query) do
    # Resource module has no sorts
    []
  end

  def extract_query_sorts(%Ash.Query{sort: sorts}, columns) when is_list(sorts) do
    sorts
    |> Enum.map(&normalize_sort_tuple/1)
    |> Enum.filter(&valid_table_sort?(&1, columns))
    |> Enum.map(fn {field, direction} -> {Atom.to_string(field), direction} end)
  end

  def extract_query_sorts(_query, _columns) do
    # Unknown query type or no sorts
    []
  end

  # Normalize different sort tuple formats to {field, direction}
  defp normalize_sort_tuple({field, direction})
       when is_atom(field) and direction in [:asc, :desc] do
    {field, direction}
  end

  defp normalize_sort_tuple(field) when is_atom(field) do
    {field, :asc}
  end

  defp normalize_sort_tuple(_), do: nil

  # Check if a sort tuple is valid for table display
  defp valid_table_sort?(nil, _columns), do: false

  defp valid_table_sort?({_field, direction}, _columns) when direction not in [:asc, :desc],
    do: false

  defp valid_table_sort?({field, _direction}, columns)
       when is_list(columns) and length(columns) > 0 do
    field_name = Atom.to_string(field)

    Enum.any?(columns, fn column ->
      column_field = Map.get(column, :field) || Map.get(column, "field")

      case column_field do
        atom_field when is_atom(atom_field) -> Atom.to_string(atom_field) == field_name
        string_field when is_binary(string_field) -> string_field == field_name
        _ -> false
      end
    end)
  end

  defp valid_table_sort?({_field, _direction}, _columns) do
    # If no columns provided, assume all sorts are valid
    true
  end

  # Add tenant to options if provided
  defp maybe_add_tenant(options, nil), do: options
  defp maybe_add_tenant(options, tenant), do: Keyword.put(options, :tenant, tenant)

  # Add execution Ash options from query_opts
  defp maybe_add_ash_options(options, query_opts) do
    # Extract execution options from query_opts and pass them to both query building and execution
    # Options like :actor, :tenant are already handled separately
    # Query building options like :select, :load are handled by apply_query_opts/2
    execution_options = [
      # How long to wait for query execution - needed for both phases
      :timeout,
      # Whether to run authorization during execution - needed for both phases
      :authorize?,
      # For parallel loading during execution
      :max_concurrency
    ]

    Enum.reduce(execution_options, options, fn key, acc ->
      case Keyword.get(query_opts, key) do
        nil -> acc
        value -> Keyword.put(acc, key, value)
      end
    end)
  end
end
