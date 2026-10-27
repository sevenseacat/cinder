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

  @doc false
  # Builds a query with filters, sorting, and action applied, but does not execute it.
  # Returns `{:ok, prepared_query}` or `{:error, reason}`. Internal helper used
  # by `build_and_execute/2` and the LiveComponent's on_query_change path to
  # capture the pre-pagination query for notification to parent LiveViews.
  def build_query(resource_or_query, options) do
    filters = Keyword.get(options, :filters, %{})
    sort_by = Keyword.get(options, :sort_by, [])
    columns = Keyword.get(options, :columns, [])
    query_opts = Keyword.get(options, :query_opts, [])
    search_term = Keyword.get(options, :search_term, "")
    search_fn = Keyword.get(options, :search_fn)

    try do
      base_query = Ash.Query.new(resource_or_query)
      resource = base_query.resource

      case validate_sortable_fields(sort_by, resource) do
        :ok ->
          prepared_query =
            base_query
            |> apply_filters(filters, columns)
            |> apply_search(search_term, columns, search_fn)
            |> apply_sorting(sort_by)
            |> apply_action(options)

          {:ok, prepared_query}

        {:error, _message} = error ->
          error
      end
    rescue
      error ->
        resource = extract_resource_for_logging(resource_or_query)

        Logger.error(
          "Cinder query building crashed with exception for #{inspect(resource)}: #{inspect(error)}",
          %{
            resource: resource,
            filters: filters,
            sort_by: sort_by,
            query_opts: query_opts,
            tenant: Keyword.get(options, :tenant),
            exception: inspect(error),
            stacktrace: Exception.format_stacktrace(__STACKTRACE__)
          }
        )

        {:error, error}
    end
  end

  @doc """
  Builds a complete query with filters, sorting, and pagination, then executes it.

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
  - `:tracer` - Tracer module(s) to use for the query (see `Ash.Tracer`)

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
    case build_query(resource_or_query, options) do
      {:ok, prepared_query} ->
        execute(prepared_query, options)

      {:error, _} = error ->
        error
    end
  end

  @doc false
  # Executes an already-built query with pagination. Internal helper so the
  # LiveComponent can build the query once (for on_query_change notification)
  # and then execute it without rebuilding.
  #
  # Auth opts (`scope:` / `actor:` / `tenant:`) are passed straight to
  # `Ash.read` — Ash handles precedence between opts and what's already on
  # the query (per `Ash.Actions.Helpers.set_context_and_get_opts`).
  def execute(%Ash.Query{} = prepared_query, options) do
    raw_page_size = Keyword.get(options, :page_size, 25)
    # Strip negative page sizes - use default instead
    page_size = if raw_page_size > 0, do: raw_page_size, else: 25
    current_page = Keyword.get(options, :current_page, 1)
    query_opts = Keyword.get(options, :query_opts, [])
    ash_opts = build_read_opts(options)

    # Keyset pagination options
    pagination_mode = Keyword.get(options, :pagination_mode, :offset)
    count? = Keyword.get(options, :count_mode, true) == true
    after_keyset = Keyword.get(options, :after_keyset)
    before_keyset = Keyword.get(options, :before_keyset)

    try do
      case action_supports_pagination?(prepared_query) do
        true ->
          case pagination_mode do
            :keyset ->
              execute_with_keyset_pagination(
                prepared_query,
                ash_opts,
                page_size,
                after_keyset,
                before_keyset,
                count?
              )

            :offset ->
              execute_with_pagination(prepared_query, ash_opts, current_page, page_size, count?)
          end

        false ->
          # Check if user has configured pagination but action doesn't support it
          if Keyword.get(options, :pagination_configured, false) do
            Logger.warning(
              "Table configured with page_size but action #{inspect(prepared_query.action.name)} doesn't support pagination. " <>
                "All records will be loaded into memory. Add 'pagination do ... end' to your action: " <>
                "https://hexdocs.pm/ash/pagination.html"
            )
          end

          execute_without_pagination(prepared_query, ash_opts)
      end
    rescue
      error ->
        Logger.error(
          "Cinder table query crashed with exception for #{inspect(prepared_query.resource)}: #{inspect(error)}",
          %{
            resource: prepared_query.resource,
            current_page: current_page,
            page_size: page_size,
            query_opts: query_opts,
            tenant: Keyword.get(options, :tenant),
            exception: inspect(error),
            stacktrace: Exception.format_stacktrace(__STACKTRACE__)
          }
        )

        {:error, error}
    end
  end

  @doc false
  def count(%Ash.Query{} = prepared_query, options) do
    Ash.count(prepared_query, build_read_opts(options))
  end

  # Prepare the query for execution by ensuring it has an action set.
  #
  # If the caller supplied an already-prepared `Ash.Query` (`query.action != nil`),
  # we leave its auth setup alone — explicit `actor:` / `tenant:` / `scope:`
  # from options still take effect, but only via the opts handed to `Ash.read`
  # at execution time. The query struct itself is not mutated.
  #
  # If the query is unprepared, we hand `scope:` + explicit `actor:` / `tenant:`
  # straight to `Ash.Query.for_read` and let Ash apply its documented precedence
  # (`deps/ash/lib/ash/scope.ex` — explicit wins for actor/tenant/authorize?,
  # context deep-merges, tracers concatenate).
  defp apply_action(query, options) do
    query = apply_query_opts(query, Keyword.get(options, :query_opts, []))

    if query.action do
      maybe_warn_action_mismatch(query, Keyword.get(options, :action))
      query
    else
      action_name =
        Keyword.get(options, :action) ||
          Ash.Resource.Info.primary_action!(query.resource, :read).name

      Ash.Query.for_read(query, action_name, %{}, build_for_read_opts(options))
    end
  end

  defp maybe_warn_action_mismatch(_query, nil), do: :ok
  defp maybe_warn_action_mismatch(%Ash.Query{action: %{name: same}}, same), do: :ok

  defp maybe_warn_action_mismatch(query, action) do
    Logger.warning(
      "Cinder: ignoring explicit `action: #{inspect(action)}` because the supplied query is already prepared for action `#{inspect(query.action.name)}`"
    )
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
  defp execute_with_pagination(query, ash_opts, current_page, page_size, count?) do
    paginated_query =
      Ash.Query.page(query,
        limit: page_size,
        offset: (current_page - 1) * page_size,
        count: count?
      )

    case Ash.read(paginated_query, ash_opts) do
      # We pass offset: so Ash always returns Ash.Page.Offset
      {:ok, %Ash.Page.Offset{} = page} ->
        {:ok, page}

      {:error, query_error} ->
        log_query_error(query.resource, query_error, current_page, page_size, ash_opts)
        {:error, query_error}
    end
  end

  # Execute query with keyset pagination (cursor-based)
  defp execute_with_keyset_pagination(
         query,
         ash_opts,
         page_size,
         after_keyset,
         before_keyset,
         count?
       ) do
    # Build keyset pagination options
    keyset_opts =
      [limit: page_size, count: count?]
      |> maybe_add_keyset_cursor(:after, after_keyset)
      |> maybe_add_keyset_cursor(:before, before_keyset)

    paginated_query = Ash.Query.page(query, keyset_opts)

    case Ash.read(paginated_query, ash_opts) do
      # Ash returns Offset or Keyset depending on app config and parameters, accept both
      {:ok, %Ash.Page.Keyset{} = page} ->
        {:ok, page}

      {:ok, %Ash.Page.Offset{} = page} ->
        {:ok, page}

      {:error, query_error} ->
        log_query_error(query.resource, query_error, 1, page_size, ash_opts)
        {:error, query_error}
    end
  end

  defp maybe_add_keyset_cursor(opts, _key, nil), do: opts
  defp maybe_add_keyset_cursor(opts, key, cursor), do: Keyword.put(opts, key, cursor)

  # Execute query without pagination and return all results
  defp execute_without_pagination(query, ash_opts) do
    case Ash.read(query, ash_opts) do
      {:ok, results} ->
        # No pagination - return nil (pagination controls won't be shown)
        # Wrap results in a simple struct-like map for consistent access via .results
        {:ok, %{results: results}}

      {:error, query_error} ->
        log_query_error(query.resource, query_error, 1, 0, ash_opts)
        {:error, query_error}
    end
  end

  # Helper for consistent error logging
  defp log_query_error(resource, query_error, current_page, page_size, ash_opts) do
    Logger.error(
      "Cinder table query execution failed for #{inspect(resource)}: #{inspect(query_error)}",
      %{
        resource: resource,
        current_page: current_page,
        page_size: page_size,
        ash_opts: ash_opts,
        tenant: Keyword.get(ash_opts, :tenant),
        error: inspect(query_error)
      }
    )
  end

  # Extract resource for logging from either resource or query
  defp extract_resource_for_logging(%Ash.Query{resource: resource}), do: resource
  defp extract_resource_for_logging(resource) when is_atom(resource), do: resource
  defp extract_resource_for_logging(_), do: :unknown

  @doc """
  The loads that showing these column fields needs, for `Ash.Query.load/2`: their
  calculations and aggregates, and the relationships in their paths. Attributes and
  embedded fields need none.

  Fields that can't be resolved on the resource, and calculations with required
  arguments, are skipped: a slot showing them needs an explicit `load`.

  For example, `["title", "artist.name", "artist.album_count"]` on an album resource
  gives `[artist: [:album_count]]`.
  """
  def infer_loads(resource, fields) do
    fields
    |> Enum.flat_map(fn field ->
      with {:ok, resolved} <- Cinder.Field.resolve(resource, field),
           load when not is_nil(load) <- Cinder.Field.load(resolved) do
        [load]
      else
        _nothing_to_load -> []
      end
    end)
    |> Enum.reduce([], &merge_load/2)
  end

  # Merges one field's load into the others, keeping first-seen order
  defp merge_load({name, nested}, loads) do
    case List.keyfind(loads, name, 0) do
      {^name, existing} ->
        List.keyreplace(loads, name, 0, {name, Enum.reduce(nested, existing, &merge_load/2)})

      nil ->
        loads ++ [{name, nested}]
    end
  end

  defp merge_load(name, loads) do
    if name in loads, do: loads, else: loads ++ [name]
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

  @supported_query_opts [
    :load,
    :select,
    :tenant,
    :timeout,
    :authorize?,
    :max_concurrency,
    :tracer
  ]

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

    # Get the filter module from registry (includes both built-in and custom)
    case Cinder.Filters.Registry.get_filter(type) do
      nil ->
        require Logger
        Logger.warning("Unknown filter type: #{type}")
        query

      # A filter that fails to build raises through to `build_query/2`, which fails the
      # load: dropping it would show data the filter was there to exclude
      filter_module ->
        filter_module.build_query(query, key, filter_config)
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
    # Existing filters stay on the outer query, not inside each search branch.
    # A column whose filter can't be built then leaves `filter` nil and is
    # skipped, rather than adding a branch that is just the existing filters.
    search_query = query |> Ash.Query.new() |> Ash.Query.unset(:filter)

    Enum.reduce(searchable_columns, [], fn column, acc ->
      # Use case-insensitive search by wrapping with Ash.CiString
      case_insensitive_term = Ash.CiString.new(search_term)

      test_query =
        Cinder.Filter.Helpers.build_ash_filter(
          search_query,
          column.field,
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

      # Process sorts individually to handle relationship sorts properly,
      # giving embedded fields special handling with calc expressions
      Enum.reduce(sort_by, query, fn {field, direction}, acc_query ->
        # Parse field to determine if it needs special handling for embedded fields
        case Cinder.Filter.Helpers.parse_field_notation(field) do
          {:embedded, embed_field, field_name} ->
            apply_embedded_sort(acc_query, [], embed_field, [field_name], direction)

          {:nested_embedded, embed_field, field_path} ->
            apply_embedded_sort(acc_query, [], embed_field, field_path, direction)

          {:relationship_embedded, rel_path, embed_field, field_name} ->
            apply_embedded_sort(acc_query, rel_path, embed_field, [field_name], direction)

          {:relationship_nested_embedded, rel_path, embed_field, field_path} ->
            apply_embedded_sort(acc_query, rel_path, embed_field, field_path, direction)

          _ ->
            # Regular fields and relationships - use the field name directly
            Ash.Query.sort(acc_query, [{field, direction}])
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

    rel_path_atoms = Enum.map(rel_path, &Cinder.Filter.Helpers.declared_field_atom/1)
    embed_atom = Cinder.Filter.Helpers.declared_field_atom(embed_field)
    field_atoms = Enum.map(field_path, &Cinder.Filter.Helpers.declared_field_atom/1)

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
  Applies default sorts for columns with nil-less sort cycles.

  Columns whose `sort_cycle` does not contain `nil` imply "always sorted".
  For any such column not already present in `query_sorts`, the first value
  in the cycle is appended as a default sort (preserving declaration order).

  Query sorts always take precedence.
  """
  def default_sorts_from_cycles(columns, query_sorts) do
    sorted_fields = MapSet.new(query_sorts, fn {field, _dir} -> field end)

    cycle_defaults =
      columns
      |> Enum.filter(fn col ->
        col.sortable && nil not in col.sort_cycle && col.field not in sorted_fields
      end)
      |> Enum.map(fn col -> {col.field, hd(col.sort_cycle)} end)

    query_sorts ++ cycle_defaults
  end

  @doc """
  Toggles sort direction using custom cycle configuration.

  Supports custom sort cycles like [nil, :desc_nils_last, :asc_nils_first].

  Falls back to standard toggle_sort_direction/2 if no custom cycle provided.

  ## Options

  * `sort_mode` - `:additive` (default) adds to existing sorts, `:exclusive` replaces them
  """
  def toggle_sort_with_cycle(current_sort, key, sort_cycle \\ nil, sort_mode \\ :additive)

  def toggle_sort_with_cycle(current_sort, key, sort_cycle, sort_mode) do
    cycle = sort_cycle || [nil, :asc, :desc]

    case Enum.find(current_sort, fn {sort_key, _direction} -> sort_key == key end) do
      {^key, current_direction} ->
        # Find current position in cycle and advance, wrapping around
        current_index = Enum.find_index(cycle, &(&1 == current_direction))
        next_index = if current_index, do: rem(current_index + 1, length(cycle)), else: 1

        next_direction = Enum.at(cycle, next_index)

        if next_direction == nil do
          # Next state is nil, remove sort
          remove_sort(current_sort, key, sort_mode)
        else
          # Update to next direction in cycle
          Enum.map(current_sort, fn
            {^key, _} -> {key, next_direction}
            other -> other
          end)
        end

      nil ->
        # Not currently sorted, start with first non-nil value in cycle
        first_direction = Enum.find(cycle, &(&1 != nil))

        if first_direction do
          add_sort(current_sort, key, first_direction, sort_mode)
        else
          # Cycle has no non-nil values, fall back to standard
          toggle_sort_direction(current_sort, key)
        end
    end
  end

  defp add_sort(_current_sort, key, direction, :exclusive), do: [{key, direction}]
  defp add_sort(current_sort, key, direction, :additive), do: [{key, direction} | current_sort]

  defp remove_sort(_current_sort, _key, :exclusive), do: []

  defp remove_sort(current_sort, key, :additive) do
    Enum.reject(current_sort, fn {sort_key, _direction} -> sort_key == key end)
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

  # Auth options handed to Ash. We pass `scope:` through untouched and let Ash
  # apply its documented precedence (`deps/ash/lib/ash/scope.ex:43-51`).
  #
  # Nil actor/tenant/scope are filtered out *before* reaching Ash. Cinder
  # collection attrs use nil as "not supplied", so an unset `actor=` prop
  # arrives here as `nil` — and Ash's literal semantics treat an explicit
  # `actor: nil` as "erase scope's actor", which would punish the common case
  # of `scope={@scope}` without `actor=`. Filtering nils preserves the most
  # common intent. Users who genuinely want to suppress scope's actor can
  # build a scope that returns `:error` from `get_actor/1`.
  defp build_auth_opts(options) do
    []
    |> maybe_put(:scope, Keyword.get(options, :scope))
    |> maybe_put(:actor, Keyword.get(options, :actor))
    |> maybe_put(:tenant, Keyword.get(options, :tenant))
  end

  defp maybe_put(opts, _key, nil), do: opts
  defp maybe_put(opts, key, value), do: Keyword.put(opts, key, value)

  # Opts handed to `Ash.Query.for_read/4`. Auth opts plus query_opts that
  # for_read recognises (see `Ash.Query.for_read_opts/0`).
  defp build_for_read_opts(options) do
    query_opts = Keyword.get(options, :query_opts, [])

    options
    |> build_auth_opts()
    |> Keyword.merge(Keyword.take(query_opts, [:authorize?, :tracer]))
  end

  # Opts handed to `Ash.read/2`. Auth opts plus query_opts that affect execution.
  defp build_read_opts(options) do
    query_opts = Keyword.get(options, :query_opts, [])

    options
    |> build_auth_opts()
    |> Keyword.merge(Keyword.take(query_opts, [:timeout, :authorize?, :max_concurrency, :tracer]))
  end

  # Deprecated: Cinder resolves fields with `Cinder.Field` now. Kept as wrappers over it
  # until 1.0.

  @doc false
  @deprecated "Internal to Cinder, and removed in 1.0"
  def calculation_sortable?(calculation), do: Cinder.Field.expression?(calculation)

  @doc false
  @deprecated "Internal to Cinder, and removed in 1.0"
  def get_calculation_info(resource, field_name) do
    if ash_resource?(resource), do: Ash.Resource.Info.calculation(resource, field_name)
  end

  @doc false
  @deprecated "Internal to Cinder, and removed in 1.0"
  def resolve_field_resource(resource, field) when is_binary(field) do
    case Cinder.Field.resolve(resource, field) do
      {:ok, resolved} -> {resolved.resource, field |> String.split(".") |> List.last()}
      :error -> {resource, field}
    end
  end

  def resolve_field_resource(resource, field), do: {resource, to_string(field)}

  @doc false
  @deprecated "Internal to Cinder, and removed in 1.0"
  def validate_field_existence(resource, field) do
    not ash_resource?(resource) or Cinder.Field.resolve(resource, to_string(field)) != :error
  end

  @doc false
  @deprecated "Internal to Cinder, and removed in 1.0"
  def field_exists_on_resource?(resource, field) do
    case ash_resource?(resource) && Cinder.Field.resolve(resource, to_string(field)) do
      false -> true
      {:ok, %{relationships: [], kind: kind}} -> kind != :embedded
      _ -> false
    end
  end

  defp ash_resource?(resource),
    do: is_atom(resource) and resource != nil and Ash.Resource.Info.resource?(resource)

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
      unless Ash.Resource.Info.resource?(resource) do
        raise ArgumentError, "#{inspect(resource)} is not an Ash resource"
      end

      problems =
        for {field, _direction} <- sort_by,
            problem = sort_problem(resource, to_string(field)),
            do: {field, "#{field} (#{problem})"}

      build_validation_result(Enum.map(problems, &elem(&1, 0)), Enum.map(problems, &elem(&1, 1)))
    rescue
      error ->
        require Logger
        Logger.warning("Failed to validate sortable fields: #{inspect(error)}")
        {:error, "Failed to validate sort fields: #{Exception.message(error)}"}
    end
  end

  # Why a field can't be sorted by, or nil
  defp sort_problem(resource, field) do
    case Cinder.Field.resolve(resource, field) do
      {:ok, resolved} -> Cinder.Field.query_error(resolved)
      :error -> "field does not exist on #{inspect(resource)}"
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
    |> Enum.map(fn
      {field, direction} when is_atom(field) -> {Atom.to_string(field), direction}
      {field, direction} when is_binary(field) -> {field, direction}
    end)
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

  # Handle calc expressions for calculations
  # These are stored with a simple atom as the calc_name
  defp normalize_sort_tuple({
         %{module: Ash.Resource.Calculation.Expression, calc_name: calc_name},
         direction
       })
       when is_atom(calc_name) and not is_nil(calc_name) and direction in [:asc, :desc] do
    {calc_name, direction}
  end

  # Handle calc expressions from embedded field sorts (e.g., weather__clear) and relationship field sorts (e.g., artist.name)
  # The sort is an Ash.Query.Calculation with module: Ash.Resource.Calculation.Expression
  # and opts containing expr: %Ash.Query.Call{name: :get_path, args: [{:_ref, [], :field}, [:path]]}
  defp normalize_sort_tuple({
         %{module: Ash.Resource.Calculation.Expression, opts: opts},
         direction
       })
       when direction in [:asc, :desc] do
    case Keyword.get(opts, :expr) do
      %{name: :get_path, args: [{:_ref, [], embed_name}, field_path]} ->
        embed_str = to_string(embed_name)
        field_str = field_path |> Enum.map_join("__", &to_string/1)
        {"#{embed_str}__#{field_str}", direction}

      %{relationship_path: rel_path, attribute: attr}
      when is_list(rel_path) and rel_path != [] and not is_nil(attr) ->
        relationship = Enum.map_join(rel_path, ".", &to_string/1)

        attribute =
          case attr do
            # Handles calculations & aggregates on relationships
            %Ash.Query.Calculation{calc_name: cn, name: n} -> cn || n
            v -> v
          end

        {"#{relationship}.#{attribute}", direction}

      _ ->
        nil
    end
  end

  defp normalize_sort_tuple(_), do: nil

  # Check if a sort tuple is valid for table display
  defp valid_table_sort?(nil, _columns), do: false

  defp valid_table_sort?({_field, direction}, _columns) when direction not in [:asc, :desc],
    do: false

  defp valid_table_sort?({field, _direction}, columns)
       when is_list(columns) and columns != [] do
    field_name = if is_atom(field), do: Atom.to_string(field), else: field

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
end
