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
          filter_fn: function() | nil
        }
  @type query_opts :: [
          {:load, term()}
          | {:select, list()}
          | {:tenant, term()}
          | {:timeout, timeout()}
          | {:authorize?, boolean()}
          | {:max_concurrency, pos_integer()}
        ]

  @doc """
  Builds a complete query with filters, sorting, and pagination.

  ## Parameters
  - `resource_or_query`: The Ash resource to query or a pre-built Ash.Query
  - `options`: Query building options including:
    - `:actor` - The current user/actor
    - `:filters` - Filter map
    - `:sort_by` - Sort specifications
    - `:page_size` - Number of records per page
    - `:current_page` - Current page number
    - `:columns` - Column definitions
    - `:query_opts` - Additional Ash query and execution options
    - `:search_term` - Global search term to search across searchable columns
    - `:search_fn` - Optional custom search function with signature `(query, searchable_columns, search_term)`

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

  Returns `{:ok, page}` on success or `{:error, reason}` on failure.

  The `page` value depends on the pagination mode and action configuration:

  - **Offset pagination** (`:pagination_mode` is `:offset`, default): Returns `Ash.Page.Offset` struct
  - **Keyset pagination** (`:pagination_mode` is `:keyset`): Returns `Ash.Page.Keyset` struct
  - **Non-paginated actions**: Returns `%{results: list()}` map (not a struct)

  All return types support accessing results via `page.results`.

  Note: Non-paginated actions return a plain map rather than an Ash.Page struct.
  This means pattern matching on `%Ash.Page.Offset{}` or `%Ash.Page.Keyset{}` will
  not match non-paginated results. Use `page.results` for consistent access.
  """
  def build_and_execute(resource_or_query, options) do
    explicit_actor = Keyword.fetch!(options, :actor)
    explicit_tenant = Keyword.get(options, :tenant)
    scope = Keyword.get(options, :scope)
    scope_opts = extract_scope_options(scope)

    # Explicit actor/tenant override scope values
    actor = explicit_actor || scope_opts[:actor]
    tenant = explicit_tenant || scope_opts[:tenant]
    filters = Keyword.get(options, :filters, %{})
    sort_by = Keyword.get(options, :sort_by, [])
    raw_page_size = Keyword.get(options, :page_size, 25)
    # Strip negative page sizes - use default instead
    page_size = if raw_page_size > 0, do: raw_page_size, else: 25
    current_page = Keyword.get(options, :current_page, 1)
    columns = Keyword.get(options, :columns, [])
    query_opts = Keyword.get(options, :query_opts, [])
    search_term = Keyword.get(options, :search_term, "")
    search_fn = Keyword.get(options, :search_fn)

    # Keyset pagination options
    pagination_mode = Keyword.get(options, :pagination_mode, :offset)
    after_keyset = Keyword.get(options, :after_keyset)
    before_keyset = Keyword.get(options, :before_keyset)

    try do
      # Query tenant as final fallback
      effective_tenant =
        tenant || if is_struct(resource_or_query, Ash.Query), do: resource_or_query.tenant

      # Normalize input to a query and extract resource for logging
      {base_query, resource} =
        normalize_resource_or_query(
          resource_or_query,
          actor,
          effective_tenant,
          scope_opts,
          query_opts
        )

      # Validate sort fields before applying them to prevent crashes
      case validate_sortable_fields(sort_by, resource) do
        :ok ->
          # Check if this is a bulk_actions request (returns IDs only, no pagination)
          if Keyword.get(options, :bulk_actions, false) do
            execute_bulk_actions(
              base_query,
              actor,
              effective_tenant,
              query_opts,
              filters,
              columns,
              search_term,
              search_fn,
              sort_by,
              Keyword.get(options, :id_field, :id)
            )
          else
            # Continue with normal query building
            prepared_query =
              base_query
              |> apply_query_opts(query_opts)
              |> apply_filters(filters, columns)
              |> apply_search(search_term, columns, search_fn)
              |> apply_sorting(sort_by)

            # Handle pagination based on action support
            case action_supports_pagination?(prepared_query) do
            true ->
              case pagination_mode do
                :keyset ->
                  execute_with_keyset_pagination(
                    prepared_query,
                    actor,
                    effective_tenant,
                    scope_opts,
                    query_opts,
                    page_size,
                    after_keyset,
                    before_keyset
                  )

                :offset ->
                  execute_with_pagination(
                    prepared_query,
                    actor,
                    effective_tenant,
                    scope_opts,
                    query_opts,
                    current_page,
                    page_size
                  )
              end

            false ->
              # Check if user has configured pagination but action doesn't support it
              if Keyword.get(options, :pagination_configured, false) do
                require Logger

                Logger.warning(
                  "Table configured with page_size but action #{inspect(prepared_query.action.name)} doesn't support pagination. " <>
                    "All records will be loaded into memory. Add 'pagination do ... end' to your action: " <>
                    "https://hexdocs.pm/ash/pagination.html"
                )
              end

              execute_without_pagination(
                prepared_query,
                actor,
                effective_tenant,
                scope_opts,
                query_opts,
                current_page,
                page_size
              )
            end
          end

        {:error, message} ->
          # Return validation error instead of crashing
          {:error, message}
      end
    rescue
      error ->
        # Log exceptions (like calculation errors) with full context
        resource = extract_resource_for_logging(resource_or_query)

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

  # Normalize input to always return {query, resource} tuple
  defp normalize_resource_or_query(%Ash.Query{} = query, actor, tenant, _scope_opts, query_opts) do
    # Fix nil action edge case
    updated_query =
      if is_nil(query.action) do
        %{query | action: Ash.Resource.Info.action(query.resource, :read)}
      else
        query
      end

    # Apply actor/tenant context to query for hooks and sub-queries
    context_query =
      updated_query
      |> maybe_set_tenant(tenant)
      |> maybe_set_actor(actor)

    # Apply query_opts (load, select, etc.) to the existing query
    final_query = apply_query_opts(context_query, query_opts)

    {final_query, query.resource}
  end

  defp normalize_resource_or_query(resource, actor, tenant, scope_opts, query_opts)
       when is_atom(resource) do
    query =
      Ash.Query.for_read(
        resource,
        :read,
        %{},
        build_ash_options(actor, tenant, scope_opts, query_opts)
      )

    {query, resource}
  end

  defp maybe_set_tenant(query, nil), do: query
  defp maybe_set_tenant(query, tenant), do: Ash.Query.set_tenant(query, tenant)

  defp maybe_set_actor(query, nil), do: query

  defp maybe_set_actor(query, actor) do
    existing_context = query.context || %{}
    new_context = Map.put(existing_context, :actor, actor)
    Ash.Query.set_context(query, new_context)
  end

  # Check if the action supports pagination
  defp action_supports_pagination?(%Ash.Query{action: nil}), do: false

  defp action_supports_pagination?(%Ash.Query{action: %{pagination: false}}), do: false

  defp action_supports_pagination?(%Ash.Query{action: %{pagination: pagination}})
       when not is_nil(pagination),
       do: true

  # Default for resources without explicit pagination
  defp action_supports_pagination?(_), do: true

  # Execute query with offset pagination (existing behavior)
  defp execute_with_pagination(
         query,
         actor,
         tenant,
         scope_opts,
         query_opts,
         current_page,
         page_size
       ) do
    paginated_query =
      Ash.Query.page(query,
        limit: page_size,
        offset: (current_page - 1) * page_size,
        count: true
      )

    case Ash.read(paginated_query, build_ash_options(actor, tenant, scope_opts, query_opts)) do
      # We pass offset: so Ash always returns Ash.Page.Offset
      {:ok, %Ash.Page.Offset{} = page} ->
        {:ok, page}

      {:error, query_error} ->
        log_query_error(query.resource, query_error, current_page, page_size, query_opts, tenant)
        {:error, query_error}
    end
  end

  # Execute query with keyset pagination (cursor-based)
  defp execute_with_keyset_pagination(
         query,
         actor,
         tenant,
         scope_opts,
         query_opts,
         page_size,
         after_keyset,
         before_keyset
       ) do
    # Build keyset pagination options
    keyset_opts =
      [limit: page_size, count: true]
      |> maybe_add_keyset_cursor(:after, after_keyset)
      |> maybe_add_keyset_cursor(:before, before_keyset)

    paginated_query = Ash.Query.page(query, keyset_opts)

    case Ash.read(paginated_query, build_ash_options(actor, tenant, scope_opts, query_opts)) do
      # Ash returns Offset or Keyset depending on app config and parameters, accept both
      {:ok, %Ash.Page.Keyset{} = page} ->
        {:ok, page}

      {:ok, %Ash.Page.Offset{} = page} ->
        {:ok, page}

      {:error, query_error} ->
        log_query_error(query.resource, query_error, 1, page_size, query_opts, tenant)
        {:error, query_error}
    end
  end

  defp maybe_add_keyset_cursor(opts, _key, nil), do: opts
  defp maybe_add_keyset_cursor(opts, key, cursor), do: Keyword.put(opts, key, cursor)

  # Execute query without pagination and return all results
  defp execute_without_pagination(
         query,
         actor,
         tenant,
         scope_opts,
         query_opts,
         _current_page,
         _page_size
       ) do
    case Ash.read(query, build_ash_options(actor, tenant, scope_opts, query_opts)) do
      {:ok, results} ->
        # No pagination - return nil (pagination controls won't be shown)
        # Wrap results in a simple struct-like map for consistent access via .results
        {:ok, %{results: results}}

      {:error, query_error} ->
        log_query_error(query.resource, query_error, 1, 0, query_opts, tenant)
        {:error, query_error}
    end
  end

  # Helper for consistent error logging
  defp log_query_error(resource, query_error, current_page, page_size, query_opts, tenant) do
    Logger.error(
      "Cinder table query execution failed for #{inspect(resource)}: #{inspect(query_error)}",
      %{
        resource: resource,
        current_page: current_page,
        page_size: page_size,
        query_opts: query_opts,
        tenant: tenant,
        error: inspect(query_error)
      }
    )
  end

  # Extract resource for logging from either resource or query
  defp extract_resource_for_logging(%Ash.Query{resource: resource}), do: resource
  defp extract_resource_for_logging(resource) when is_atom(resource), do: resource
  defp extract_resource_for_logging(_), do: :unknown

  # Execute bulk actions query - returns only IDs, no pagination
  # Used for bulk operations where we need all matching record IDs
  defp execute_bulk_actions(
         base_query,
         actor,
         tenant,
         query_opts,
         filters,
         columns,
         search_term,
         search_fn,
         sort_by,
         id_field
       ) do
    # Only select the ID field for efficiency
    bulk_query_opts = Keyword.put(query_opts, :select, [id_field])

    prepared_query =
      base_query
      |> apply_query_opts(bulk_query_opts)
      |> apply_filters(filters, columns)
      |> apply_search(search_term, columns, search_fn)
      |> apply_sorting(sort_by)

    case Ash.read(prepared_query, build_ash_options(actor, tenant, query_opts)) do
      {:ok, results} ->
        # Extract just the IDs from results
        ids = Enum.map(results, &Map.get(&1, id_field))
        {:ok, ids}

      {:error, query_error} ->
        log_query_error(prepared_query.resource, query_error, 1, 0, query_opts, tenant)
        {:error, query_error}
    end
  end

  @doc """
  Applies query options like load and select to an Ash query.

  Warns if unsupported options are provided.
  """
  def apply_query_opts(query, opts) do
    validate_query_opts(opts)

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

  @supported_query_opts [:load, :select, :tenant, :timeout, :authorize?, :max_concurrency]

  defp validate_query_opts(opts) do
    unsupported_opts =
      opts
      |> Keyword.keys()
      |> Enum.uniq()
      |> Enum.reject(&(&1 in @supported_query_opts))

    if unsupported_opts != [] do
      Logger.warning("""
      Unsupported query_opts provided: #{inspect(unsupported_opts)}

      Supported query_opts are: #{inspect(@supported_query_opts)}
      """)
    end
  end

  @doc """
  Applies filters to an Ash query based on filter configuration and column definitions.
  """
  def apply_filters(query, filters, _columns) when filters == %{}, do: query

  def apply_filters(query, filters, columns) do
    Enum.reduce(filters, query, fn {field, filter_config}, query ->
      column = Enum.find(columns, &(&1.field == field))

      if column && column.filter_fn do
        # Use custom filter function
        column.filter_fn.(query, filter_config)
      else
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
  Applies global search to an Ash query across searchable columns.

  ## Parameters
  - `query`: The Ash query to modify
  - `search_term`: The search term to filter by (empty/nil terms are ignored)
  - `columns`: List of column definitions to find searchable fields
  - `custom_search_fn`: Optional table-level custom search function

  ## Custom Search Function Signature
  `search_fn(query, searchable_columns, search_term)`

  ## Returns
  The modified query with search conditions applied, or the original query
  if no search term is provided or no searchable columns exist.

  ## Examples

      # Default search across searchable columns
      query = apply_search(query, "widget", columns, nil)

      # Custom search function
      def custom_search(query, searchable_columns, search_term) do
        # Custom implementation
      end
      query = apply_search(query, "widget", columns, &custom_search/3)

  """
  def apply_search(query, search_term, columns, custom_search_fn \\ nil)

  def apply_search(query, search_term, _columns, _custom_search_fn)
      when search_term in [nil, ""] do
    query
  end

  def apply_search(query, search_term, columns, custom_search_fn) do
    searchable_columns = Enum.filter(columns, & &1.searchable)

    cond do
      Enum.empty?(searchable_columns) ->
        query

      custom_search_fn ->
        # Custom table-level search function gets all searchable columns
        custom_search_fn.(query, searchable_columns, search_term)

      true ->
        # Default search: OR logic across searchable columns using text filter infrastructure
        build_default_search(query, searchable_columns, search_term)
    end
  end

  # Builds default search using OR logic across searchable columns
  defp build_default_search(query, searchable_columns, search_term) do
    require Ash.Query

    try do
      # Build filter conditions for each valid searchable column
      filter_conditions = build_search_conditions(query, searchable_columns, search_term)

      # Apply the combined search conditions
      case filter_conditions do
        [] ->
          # No valid searchable fields found
          require Logger
          Logger.warning("Error building search filter for one or more searchable columns")
          query

        [single_condition] ->
          # Single field search - apply directly
          Ash.Query.filter(query, ^single_condition)

        conditions ->
          # Multiple fields - combine with OR logic
          combined_condition = combine_conditions_with_or(conditions)
          Ash.Query.filter(query, ^combined_condition)
      end
    rescue
      error ->
        require Logger
        Logger.warning("Error building default search query: #{inspect(error)}")
        query
    end
  end

  # Builds individual filter conditions for searchable columns
  defp build_search_conditions(query, searchable_columns, search_term) do
    Enum.reduce(searchable_columns, [], fn column, acc ->
      # Convert URL-safe field notation to bracket notation if needed
      field_name = Cinder.Filter.Helpers.field_notation_from_url_safe(column.field)

      # Test if this field can be filtered by building a test query
      # Use case-insensitive search by wrapping with Ash.CiString
      case_insensitive_term = Ash.CiString.new(search_term)

      test_query =
        Cinder.Filter.Helpers.build_ash_filter(
          query,
          field_name,
          case_insensitive_term,
          :contains
        )

      # Only include fields that don't produce errors
      if Enum.empty?(test_query.errors) and not is_nil(test_query.filter) do
        [test_query.filter | acc]
      else
        acc
      end
    end)
  end

  # Combines multiple filter conditions with OR logic
  defp combine_conditions_with_or([first_condition | remaining_conditions]) do
    import Ash.Expr

    Enum.reduce(remaining_conditions, first_condition, fn condition, acc ->
      expr(^acc or ^condition)
    end)
  end

  @doc """
  Applies sorting to an Ash query based on sort specifications.
  """
  def apply_sorting(query, sort_by) when sort_by == [], do: query

  def apply_sorting(query, sort_by) do
    # Validate sort_by input to prevent Protocol.UndefinedError
    if is_list(sort_by) and Enum.all?(sort_by, &valid_sort_tuple?/1) do
      # Clear any existing sorts to ensure table sorts take precedence
      # Only call unset on actual Ash.Query structs, not on resources
      query =
        if is_struct(query, Ash.Query) do
          Ash.Query.unset(query, :sort)
        else
          query
        end

      # Process sorts individually to handle relationship sorts properly
      # Convert URL-safe field notation and handle embedded fields with calc expressions
      Enum.reduce(sort_by, query, fn {field, direction}, acc_query ->
        # Convert URL-safe embedded field notation (e.g., "settings__a" -> "settings[:a]")
        converted_field = Cinder.Filter.Helpers.field_notation_from_url_safe(field)

        # Parse field to determine if it needs special handling for embedded fields
        case Cinder.Filter.Helpers.parse_field_notation(converted_field) do
          {:embedded, embed_field, field_name} ->
            apply_embedded_sort(acc_query, [], embed_field, [field_name], direction)

          {:nested_embedded, embed_field, field_path} ->
            apply_embedded_sort(acc_query, [], embed_field, field_path, direction)

          {:relationship_embedded, rel_path, embed_field, field_name} ->
            apply_embedded_sort(acc_query, rel_path, embed_field, [field_name], direction)

          {:relationship_nested_embedded, rel_path, embed_field, field_path} ->
            apply_embedded_sort(acc_query, rel_path, embed_field, field_path, direction)

          _ ->
            # Regular fields and relationships - use converted field name directly
            Ash.Query.sort(acc_query, [{converted_field, direction}])
        end
      end)
    else
      require Logger

      Logger.warning(
        "Invalid sort_by format: #{inspect(sort_by)}. Expected list of {field, direction} tuples."
      )

      query
    end
  end

  # Helper function to apply embedded field sorting using calc expressions
  defp apply_embedded_sort(query, rel_path, embed_field, field_path, direction) do
    import Ash.Expr

    rel_path_atoms = Enum.map(rel_path, &String.to_atom/1)
    embed_atom = String.to_atom(embed_field)
    field_atoms = Enum.map(field_path, &String.to_atom/1)

    sort_expr =
      case rel_path_atoms do
        [] ->
          # Direct embedded field: profile__name
          calc(get_path(^ref(embed_atom), ^field_atoms))

        _ ->
          # Relationship + embedded: user.profile__name
          full_path = rel_path_atoms ++ [embed_atom]
          calc(get_path(^ref(full_path), ^field_atoms))
      end

    Ash.Query.sort(query, [{sort_expr, direction}])
  end

  # Validates that a sort tuple has the correct format.
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
  Toggles sort direction using custom cycle configuration.

  Supports custom sort cycles like [nil, :desc_nils_last, :asc_nils_first].

  Falls back to standard toggle_sort_direction/2 if no custom cycle provided.
  """
  def toggle_sort_with_cycle(current_sort, key, sort_cycle \\ nil) do
    cycle = sort_cycle || [nil, :asc, :desc]

    case Enum.find(current_sort, fn {sort_key, _direction} -> sort_key == key end) do
      {^key, current_direction} ->
        # Find current position in cycle and advance to next
        current_index = Enum.find_index(cycle, &(&1 == current_direction))
        next_index = if current_index, do: current_index + 1, else: 1

        if next_index >= length(cycle) do
          # End of cycle, remove sort (nil state)
          Enum.reject(current_sort, fn {sort_key, _direction} -> sort_key == key end)
        else
          next_direction = Enum.at(cycle, next_index)

          if next_direction == nil do
            # Next state is nil, remove sort
            Enum.reject(current_sort, fn {sort_key, _direction} -> sort_key == key end)
          else
            # Update to next direction in cycle
            Enum.map(current_sort, fn
              {^key, _} -> {key, next_direction}
              other -> other
            end)
          end
        end

      nil ->
        # Not currently sorted, start with first non-nil value in cycle
        first_direction = Enum.find(cycle, &(&1 != nil))

        if first_direction do
          [{key, first_direction} | current_sort]
        else
          # Cycle has no non-nil values, fall back to standard
          toggle_sort_direction(current_sort, key)
        end
    end
  end

  @doc """
  Toggles sort direction with special handling for query-extracted sorts.

  When a column has a sort from query extraction, the first user click
  provides intuitive behavior:
  - desc (from query) → asc (user takes control)
  - asc (from query) → desc (user takes control)

  After first click, follows standard toggle cycle.
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

  # Extract options from an Ash scope, returning empty list if scope is nil or invalid
  defp extract_scope_options(nil), do: []

  defp extract_scope_options(scope) do
    try do
      Ash.Scope.to_opts(scope)
    rescue
      _ -> []
    end
  end

  # Build options for Ash.Query.for_read/3 and Ash.read/2
  # Scope options provide base, explicit actor/tenant override
  defp build_ash_options(actor, tenant, scope_opts, query_opts) do
    scope_opts
    |> Keyword.put(:actor, actor)
    |> maybe_add_tenant(tenant)
    |> maybe_add_ash_options(query_opts)
  end

  @doc """
  Determines if a calculation can be sorted at the database level.

  Checks if a calculation has an `expression/2` function that allows it to be
  converted to a database expression for sorting.

  ## Parameters
  - `calculation` - An Ash calculation struct

  ## Returns
  - `true` if the calculation can be sorted at the database level
  - `false` if the calculation is computed in-memory and cannot be sorted

  ## Examples

      # Database-level calculation (using expr())
      calculation_sortable?(%{calculation: {Ash.Resource.Calculation.Expression, _}})
      # => true

      # In-memory calculation without expression/2
      calculation_sortable?(%{calculation: {MyCalcModule, _}})
      # => false (if MyCalcModule doesn't implement expression/2)
  """
  def calculation_sortable?(%{calculation: {Ash.Resource.Calculation.Expression, _}}), do: true

  def calculation_sortable?(%{calculation: {module, _opts}}) when is_atom(module) do
    function_exported?(module, :expression, 2)
  end

  def calculation_sortable?(_), do: false

  @doc """
  Retrieves calculation information for a given field from an Ash resource.

  ## Parameters
  - `resource` - Ash resource module
  - `field_name` - Field name as atom or string

  ## Returns
  - Calculation struct if the field is a calculation
  - `nil` if the field is not a calculation or doesn't exist

  ## Examples

      get_calculation_info(User, :full_name)
      # => %{name: :full_name, calculation: {...}, ...} or nil
  """
  def get_calculation_info(resource, field_name) when is_atom(resource) do
    try do
      calculations = Ash.Resource.Info.calculations(resource)
      field_atom = if is_binary(field_name), do: String.to_atom(field_name), else: field_name

      Enum.find(calculations, &(&1.name == field_atom))
    rescue
      _ -> nil
    end
  end

  def get_calculation_info(_resource, _field_name) do
    # Not an Ash resource, no calculations
    nil
  end

  @doc """
  Validates that all fields in a sort list can be sorted at the database level.

  Checks each sort field to ensure it's not an in-memory calculation that would
  cause crashes or undefined behavior when sorting is attempted.

  ## Parameters
  - `sort_by` - List of `{field, direction}` tuples
  - `resource` - Ash resource module

  ## Returns
  - `:ok` if all fields can be sorted
  - `{:error, message}` if any fields cannot be sorted

  ## Examples

      validate_sortable_fields([{"name", :asc}], User)
      # => :ok

      validate_sortable_fields([{"in_memory_calc", :asc}], User)
      # => {:error, "Cannot sort by in-memory calculations..."}
  """
  def validate_sortable_fields(sort_by, resource) when is_atom(resource) do
    try do
      resource_info = build_resource_info(resource)

      {unsortable_fields, details} =
        sort_by
        |> Enum.reduce({[], []}, fn {field, _direction}, acc ->
          validate_single_sort_field(field, resource, resource_info, acc)
        end)

      build_validation_result(unsortable_fields, details)
    rescue
      error ->
        require Logger
        Logger.warning("Failed to validate sortable fields: #{inspect(error)}")
        :ok
    end
  end

  # Builds a map of resource information needed for field validation.
  # Extracts calculations, attributes, and relationships for efficient lookup.
  defp build_resource_info(resource) do
    calculations = Ash.Resource.Info.calculations(resource)
    calculation_map = Map.new(calculations, &{&1.name, &1})

    # Get all valid field names for existence validation
    attributes = Ash.Resource.Info.attributes(resource) |> Enum.map(& &1.name)
    relationships = Ash.Resource.Info.relationships(resource) |> Enum.map(& &1.name)
    aggregates = Ash.Resource.Info.aggregates(resource) |> Enum.map(& &1.name)

    valid_fields =
      MapSet.new(attributes ++ relationships ++ aggregates ++ Map.keys(calculation_map))

    %{
      calculation_map: calculation_map,
      valid_fields: valid_fields
    }
  end

  # Validates a single sort field against resource information.
  # Returns updated {unsortable_fields, details} tuple.
  defp validate_single_sort_field(field, resource, _resource_info, {unsortable, details}) do
    field_string = to_string(field)

    # Use comprehensive field validation that handles embedded fields
    if validate_field_existence(resource, field_string) do
      # Parse field to handle relationship calculations for sortability check
      {target_resource, target_field} = resolve_field_resource(resource, field_string)

      target_field_atom =
        if is_binary(target_field), do: String.to_atom(target_field), else: target_field

      # Check if it's a calculation that needs validation
      case get_calculation_info(target_resource, target_field_atom) do
        nil ->
          # Regular field that exists - should be sortable
          {unsortable, details}

        calc ->
          # It's a calculation - check if sortable
          validate_calculation_sortability(field, calc, {unsortable, details})
      end
    else
      detail = "#{field} (field does not exist on #{inspect(resource)})"
      {[field | unsortable], [detail | details]}
    end
  end

  # Validates whether a calculation can be sorted at the database level.
  # Checks if the calculation implements expression/2 for database-level sorting.
  defp validate_calculation_sortability(field, calc, {unsortable, details}) do
    if calculation_sortable?(calc) do
      {unsortable, details}
    else
      detail =
        case calc.calculation do
          {module, _} ->
            "#{field} (#{inspect(module)} - missing expression/2)"

          other ->
            "#{field} (#{inspect(other)})"
        end

      {[field | unsortable], [detail | details]}
    end
  end

  @doc """
  Resolves a field to its target resource and field name.
  Handles relationship traversal (e.g., "user.profile.first_name" -> {Profile, "first_name"})
  """
  def resolve_field_resource(resource, field) when is_binary(field) do
    case String.split(field, ".", parts: 2) do
      [single_field] ->
        # Direct field on the main resource
        {resource, single_field}

      [relationship_name, remaining_field] ->
        # Relationship field - try to resolve the target resource
        try do
          if is_atom(resource) and Ash.Resource.Info.resource?(resource) do
            case Ash.Resource.Info.relationship(resource, String.to_atom(relationship_name)) do
              %{destination: destination_resource} ->
                # Recursively resolve the remaining field path
                resolve_field_resource(destination_resource, remaining_field)

              nil ->
                # Relationship not found, treat as direct field
                {resource, field}
            end
          else
            # Not an Ash resource, can't resolve relationships
            {resource, field}
          end
        rescue
          _ ->
            # Error resolving relationship, fall back to direct field
            {resource, field}
        end
    end
  end

  def resolve_field_resource(resource, field), do: {resource, to_string(field)}

  @doc """
  Validates field existence on a resource, handling all field types including embedded fields.

  Supports:
  - Direct fields: "name"
  - Relationship fields: "user.profile.name"
  - Embedded fields: "profile__first_name" (URL-safe) or "profile[:first_name]" (bracket notation)
  - Mixed fields: "user.profile__address__street"
  """
  def validate_field_existence(resource, field) when is_binary(field) do
    # Convert underscore notation to bracket notation first
    bracket_notation_field = Cinder.Filter.Helpers.field_notation_from_url_safe(field)

    case Cinder.Filter.Helpers.parse_field_notation(bracket_notation_field) do
      {:direct, field_name} ->
        field_exists_on_resource?(resource, field_name)

      {:relationship, rel_path, target_field} ->
        # Resolve through relationship chain
        case resolve_relationship_resource(resource, rel_path) do
          {:ok, target_resource} ->
            field_exists_on_resource?(target_resource, target_field)

          {:error, _} ->
            false
        end

      {:embedded, embed_field, nested_field} ->
        # Validate embedded field
        validate_embedded_field(resource, embed_field, nested_field)

      {:nested_embedded, embed_field, nested_path} ->
        # Validate nested embedded field
        validate_nested_embedded_field(resource, embed_field, nested_path)

      {:relationship_embedded, rel_path, embed_field, nested_field} ->
        # Resolve relationship then validate embedded field
        validate_relationship_embedded_field(resource, rel_path, embed_field, nested_field)

      {:relationship_nested_embedded, rel_path, embed_field, nested_path} ->
        # Resolve relationship then validate nested embedded field
        validate_relationship_nested_embedded_field(resource, rel_path, embed_field, nested_path)

      {:invalid, _} ->
        false
    end
  rescue
    _ ->
      # If parsing or validation fails, assume field doesn't exist
      false
  end

  def validate_field_existence(resource, field), do: field_exists_on_resource?(resource, field)

  # Resolves a relationship path to get the target resource
  defp resolve_relationship_resource(resource, rel_path) do
    try do
      if is_atom(resource) and Ash.Resource.Info.resource?(resource) do
        Enum.reduce_while(rel_path, {:ok, resource}, fn rel_name, {:ok, current_resource} ->
          case Ash.Resource.Info.relationship(current_resource, String.to_atom(rel_name)) do
            %{destination: destination_resource} ->
              {:cont, {:ok, destination_resource}}

            nil ->
              {:halt,
               {:error, "Relationship #{rel_name} not found on #{inspect(current_resource)}"}}
          end
        end)
      else
        {:error, "Not an Ash resource"}
      end
    rescue
      error ->
        {:error, "Error resolving relationship: #{inspect(error)}"}
    end
  end

  # Validates an embedded field exists on the resource
  defp validate_embedded_field(resource, embed_field, nested_field) do
    try do
      if is_atom(resource) and Ash.Resource.Info.resource?(resource) do
        embed_field_atom = String.to_atom(embed_field)

        # Check if embed_field is an embedded attribute
        case Ash.Resource.Info.attribute(resource, embed_field_atom) do
          %{type: {:array, embedded_type}} when is_atom(embedded_type) ->
            # Array of embedded resources - check if nested field exists on embedded type
            validate_embedded_resource_field(embedded_type, nested_field)

          %{type: embedded_type} when is_atom(embedded_type) ->
            # Single embedded resource - check if nested field exists on embedded type
            validate_embedded_resource_field(embedded_type, nested_field)

          %{type: :map} ->
            # Map type - assume nested field is valid (can't validate structure)
            true

          %{type: {:array, :map}} ->
            # Array of maps - assume nested field is valid
            true

          nil ->
            # Embed field doesn't exist
            false

          _ ->
            # Field exists but is not embedded type
            false
        end
      else
        # Not an Ash resource, assume field exists
        true
      end
    rescue
      _ ->
        false
    end
  end

  # Validates a nested embedded field path
  defp validate_nested_embedded_field(resource, embed_field, nested_path) do
    try do
      if is_atom(resource) and Ash.Resource.Info.resource?(resource) do
        embed_field_atom = String.to_atom(embed_field)

        case Ash.Resource.Info.attribute(resource, embed_field_atom) do
          %{type: {:array, embedded_type}} when is_atom(embedded_type) ->
            # Array of embedded resources - validate nested path on embedded type
            validate_nested_path_on_embedded_resource(embedded_type, nested_path)

          %{type: embedded_type} when is_atom(embedded_type) ->
            # Single embedded resource - validate nested path on embedded type
            validate_nested_path_on_embedded_resource(embedded_type, nested_path)

          %{type: :map} ->
            # Map type - assume nested path is valid (can't validate structure)
            true

          %{type: {:array, :map}} ->
            # Array of maps - assume nested path is valid
            true

          nil ->
            # Embed field doesn't exist
            false

          _ ->
            # Field exists but is not embedded type
            false
        end
      else
        true
      end
    rescue
      _ ->
        false
    end
  end

  # Validates a nested path on an embedded resource type
  defp validate_nested_path_on_embedded_resource(embedded_type, nested_path) do
    case nested_path do
      [single_field] ->
        # Single nested field - check if it exists on embedded resource
        validate_embedded_resource_field(embedded_type, single_field)

      [next_embed_field | remaining_path] ->
        # Multi-level nesting - recursively validate
        try do
          if is_atom(embedded_type) and Ash.Resource.Info.resource?(embedded_type) do
            next_embed_atom = String.to_atom(next_embed_field)

            case Ash.Resource.Info.attribute(embedded_type, next_embed_atom) do
              %{type: {:array, deeper_embedded_type}} when is_atom(deeper_embedded_type) ->
                validate_nested_path_on_embedded_resource(deeper_embedded_type, remaining_path)

              %{type: deeper_embedded_type} when is_atom(deeper_embedded_type) ->
                validate_nested_path_on_embedded_resource(deeper_embedded_type, remaining_path)

              %{type: :map} ->
                # Map type - assume remaining path is valid
                true

              %{type: {:array, :map}} ->
                # Array of maps - assume remaining path is valid
                true

              nil ->
                # Field doesn't exist on this embedded resource
                false

              _ ->
                # Field exists but is not embedded type
                false
            end
          else
            # Not an Ash resource, assume valid
            true
          end
        rescue
          _ ->
            false
        end

      _ ->
        false
    end
  end

  # Validates a relationship + embedded field combination
  defp validate_relationship_embedded_field(resource, rel_path, embed_field, nested_field) do
    case resolve_relationship_resource(resource, rel_path) do
      {:ok, target_resource} ->
        validate_embedded_field(target_resource, embed_field, nested_field)

      {:error, _} ->
        false
    end
  end

  # Validates a relationship + nested embedded field combination
  defp validate_relationship_nested_embedded_field(resource, rel_path, embed_field, nested_path) do
    case resolve_relationship_resource(resource, rel_path) do
      {:ok, target_resource} ->
        validate_nested_embedded_field(target_resource, embed_field, nested_path)

      {:error, _} ->
        false
    end
  end

  # Validates that a field exists on an embedded resource type
  defp validate_embedded_resource_field(embedded_type, field_name) do
    try do
      if is_atom(embedded_type) and Ash.Resource.Info.resource?(embedded_type) do
        field_exists_on_resource?(embedded_type, field_name)
      else
        # Not an Ash resource, assume field exists
        true
      end
    rescue
      _ ->
        true
    end
  end

  @doc """
  Checks if a field exists on a resource (including attributes, relationships, calculations, aggregates)
  """
  def field_exists_on_resource?(resource, field_atom) do
    try do
      if is_atom(resource) and Ash.Resource.Info.resource?(resource) do
        field_atom = if is_binary(field_atom), do: String.to_atom(field_atom), else: field_atom

        # Get all valid field types
        attributes = Ash.Resource.Info.attributes(resource) |> Enum.map(& &1.name)
        relationships = Ash.Resource.Info.relationships(resource) |> Enum.map(& &1.name)
        calculations = Ash.Resource.Info.calculations(resource) |> Enum.map(& &1.name)
        aggregates = Ash.Resource.Info.aggregates(resource) |> Enum.map(& &1.name)

        valid_fields = MapSet.new(attributes ++ relationships ++ calculations ++ aggregates)

        # Check the target field on the resolved resource
        MapSet.member?(valid_fields, field_atom)
      else
        # Not an Ash resource, assume field exists
        true
      end
    rescue
      _ ->
        # Error checking resource, assume field exists
        true
    end
  end

  # Builds the final validation result from collected unsortable fields and details.
  # Returns :ok if no issues found, or {:error, message} with helpful details.
  defp build_validation_result([], _details), do: :ok

  defp build_validation_result(unsortable_fields, details) do
    field_list = Enum.join(unsortable_fields, ", ")
    detail_list = Enum.join(details, ", ")

    {:error,
     "Cannot sort by invalid fields: #{field_list}. " <>
       "Details: #{detail_list}. " <>
       "Fields must exist on the resource and calculations must be database-level (using expr()) to be sortable."}
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
