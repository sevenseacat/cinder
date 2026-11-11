# SPDX-FileCopyrightText: 2026 Cinder contributors <https://github.com/sevenseacat/cinder/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Cinder.Engine do
  @moduledoc false
  # The Ash layer: the only part of Cinder that touches Ash.
  #
  # The shell asks it what a resource's fields are and how they can be filtered,
  # searched and sorted, what sort a given query already has, and for a page of
  # records. It answers with Cinder's own data, never Ash structs or column maps,
  # so what's behind it can change without the shell changing.
  #
  # Turning form and URL strings into values belongs to `Cinder.Params`, not here.

  alias Cinder.BulkActionExecutor
  alias Cinder.Engine.{Argument, BulkAction, Error, Field, Page, Query}
  alias Cinder.Filters.Registry
  alias Cinder.QueryBuilder

  @date_types [
    Ash.Type.Date,
    Ash.Type.DateTime,
    Ash.Type.UtcDatetime,
    Ash.Type.UtcDatetimeUsec,
    Ash.Type.NaiveDatetime
  ]

  @number_types [Ash.Type.Integer, Ash.Type.Decimal, Ash.Type.Float]

  # Read options the engine sets itself, from the query it's given
  @set_read_opts [:action, :actor, :tenant, :scope, :page, :return_query?]

  @doc """
  The read options a caller may give in `run/4`'s `query_opts`: `Ash.read/2`'s,
  without the ones the engine sets, as a `Spark.Options` schema.
  """
  @spec read_opts() :: keyword()
  def read_opts, do: Keyword.drop(Ash.read_opts(), @set_read_opts)

  @doc """
  Checks a field as declared (a `Cinder.Engine.Field`) against `source` (a
  resource, or a query on one), and fills in the rest: its filter's type, module
  and options, what showing it needs loaded, and its path.

  A filter's options are its type's defaults, then the field's enum values (for
  types that take `options`), then the declared ones.

  Anything wrong is the developer's mistake, so it's an error naming the field:
  a field the resource doesn't have, filtering, sorting or searching a field that
  can't be queried, or a filter type that doesn't exist.
  """
  @spec field(Ash.Query.t() | module(), Field.t()) :: {:ok, Field.t()} | {:error, String.t()}
  def field(source, %Field{name: name} = field) do
    uses = [filtered: field.filter != nil, sorted: field.sortable?, searched: field.searchable?]

    with {:ok, resolved} <- resolve(Ash.Query.new(source).resource, name),
         :ok <- queryable(resolved, uses),
         {:ok, filter} <- filter(resolved, field.filter) do
      load = if field.column?, do: Cinder.Field.load(resolved)
      path = Enum.map(resolved.relationships, &to_string/1) ++ [to_string(resolved.name)]
      {:ok, %{field | filter: filter, load: load, path: path ++ resolved.embedded_path}}
    else
      {:error, problem} -> {:error, "#{inspect(name)} #{problem}"}
    end
  end

  @doc """
  The sort already on `query` that the collection can show: its sorts on
  sortable `fields`, in order, as `[{name, direction}]`. A resource has none.
  """
  @spec query_sorts(Ash.Query.t() | module(), [Field.t()]) :: [{String.t(), atom()}]
  def query_sorts(%Ash.Query{sort: sort}, fields) do
    sortable = for %Field{sortable?: true, name: name} <- fields, do: name

    Enum.flat_map(sort, fn {key, direction} ->
      name = sort_name(key)
      if name in sortable, do: [{name, direction}], else: []
    end)
  end

  def query_sorts(_resource, _fields), do: []

  # An attribute or aggregate is its name, a calculation carries its name, and a
  # relationship path (`"artist.name"`) is an unnamed expression of the field
  defp sort_name(name) when is_atom(name), do: Atom.to_string(name)

  defp sort_name(%Ash.Query.Calculation{calc_name: name}) when not is_nil(name) do
    Atom.to_string(name)
  end

  defp sort_name(%Ash.Query.Calculation{opts: opts}) do
    case opts[:expr] do
      %Ash.Query.Ref{relationship_path: [_ | _] = path} = ref ->
        Enum.map_join(path ++ [Ash.Query.Ref.name(ref)], ".", &to_string/1)

      _ ->
        nil
    end
  end

  defp sort_name(_key), do: nil

  @doc """
  The attribute that identifies each of `source`'s records, for selecting them: its
  resource's primary key. A primary key that isn't one attribute (several, or none)
  is an error, as no one field identifies a record.
  """
  @spec primary_key(Ash.Query.t() | module()) :: {:ok, atom()} | {:error, String.t()}
  def primary_key(source) do
    resource = Ash.Query.new(source).resource

    case Ash.Resource.Info.primary_key(resource) do
      [key] ->
        {:ok, key}

      keys ->
        {:error, "#{inspect(resource)}'s primary key isn't a single attribute: #{inspect(keys)}"}
    end
  end

  @doc """
  Checks an action to run on `source`'s selected records: an update or destroy
  action (an atom, or a string matched to their names), or a function, which is
  the developer's to run and so isn't checked.
  """
  @spec bulk_action(Ash.Query.t() | module(), atom() | String.t() | function()) ::
          {:ok, BulkAction.t()} | {:error, String.t()}
  def bulk_action(_source, action) when is_function(action, 2) do
    {:ok, %BulkAction{action: action}}
  end

  def bulk_action(source, action) do
    resource = Ash.Query.new(source).resource

    actions =
      for %{type: type} = found <- Ash.Resource.Info.actions(resource),
          type in [:update, :destroy],
          do: found

    case Enum.find(actions, &(to_string(&1.name) == to_string(action))) do
      nil ->
        {:error,
         "#{inspect(resource)} has no update or destroy action #{inspect(action)} " <>
           "(its update and destroy actions: #{Enum.map_join(actions, ", ", &inspect(&1.name))})"}

      found ->
        {:ok, %BulkAction{action: found.name, type: found.type}}
    end
  end

  @doc """
  The options a caller may give in `run_bulk_action/4`'s `action_opts`, as a
  `Spark.Options` schema: `Ash.bulk_update/4`'s or `Ash.bulk_destroy/4`'s, without
  the ones the engine sets. A function's are its own, so they have no schema.
  """
  @spec bulk_action_opts(BulkAction.t()) :: keyword() | nil
  def bulk_action_opts(%BulkAction{type: :update}), do: bulk_opts(Ash.bulk_update_opts())
  def bulk_action_opts(%BulkAction{type: :destroy}), do: bulk_opts(Ash.bulk_destroy_opts())
  def bulk_action_opts(%BulkAction{type: nil}), do: nil

  defp bulk_opts(schema), do: Keyword.drop(schema, [:actor, :tenant, :scope])

  @doc """
  The read action `source` is read with: the query's, or `action` (an atom, or a
  string matched to the resource's read actions' names), or the primary read.

  A query that already reads with an action is one `Ash.Query.for_read/4` has
  prepared, so asking for a different one is an error, as is an action that isn't
  one of the resource's reads.
  """
  @spec read_action(Ash.Query.t() | module(), atom() | String.t() | nil) ::
          {:ok, atom()} | {:error, String.t()}
  def read_action(source, action) do
    query = Ash.Query.new(source)
    reads = for %{type: :read, name: name} <- Ash.Resource.Info.actions(query.resource), do: name
    named = Enum.find(reads, &(to_string(&1) == to_string(action)))

    cond do
      action == nil and query.action != nil ->
        {:ok, query.action.name}

      action == nil ->
        {:ok, Ash.Resource.Info.primary_action!(query.resource, :read).name}

      named == nil ->
        {:error,
         "#{inspect(query.resource)} has no read action #{inspect(action)} " <>
           "(its read actions: #{Enum.map_join(reads, ", ", &inspect/1)})"}

      query.action != nil and query.action.name != named ->
        {:error,
         "the query already reads with #{inspect(query.action.name)}, " <>
           "so it can't read with #{inspect(named)}"}

      true ->
        {:ok, named}
    end
  end

  @doc """
  Checks an argument as declared (a `Cinder.Engine.Argument`) against `action`
  (from `read_action/2`), and fills in the rest: its input's type, module and
  options, as a filter's, and whether it's required.

  An argument the action doesn't have is an error, as is any argument for a query
  already prepared for its action: its preparations have run without it.
  """
  @spec argument(Ash.Query.t() | module(), atom(), Argument.t()) ::
          {:ok, Argument.t()} | {:error, String.t()}
  def argument(source, action, %Argument{name: name} = argument) do
    query = Ash.Query.new(source)
    action = Ash.Resource.Info.action(query.resource, action)
    found = Enum.find(action.arguments, &(to_string(&1.name) == name))

    cond do
      query.action != nil ->
        {:error,
         "#{inspect(name)} can't be given: the query is already prepared for " <>
           "#{inspect(query.action.name)}, so the action has run without it. " <>
           "Give the action as `action` instead"}

      found == nil ->
        {:error,
         "#{inspect(name)} is not an argument of " <>
           "#{inspect(query.resource)}'s #{inspect(action.name)} action"}

      true ->
        input(argument, found)
    end
  end

  defp input(argument, found) do
    ash_type = Ash.Type.get_type(found.type)
    values = enum_values(ash_type, found.constraints)
    type = Map.get(argument.input, :type) || infer_input_type(ash_type, values)

    case control(type, values, Map.get(argument.input, :options, [])) do
      {:ok, input} ->
        required? = found.allow_nil? == false and is_nil(found.default)
        param = argument.param || argument.name
        {:ok, %{argument | input: input, required?: required?, param: param}}

      {:error, problem} ->
        {:error, "#{inspect(argument.name)} can't be an input: #{problem}"}
    end
  end

  # An argument takes a single value, so a single date, not a range, and a number
  # is typed. A list takes several.
  defp infer_input_type(ash_type, values) do
    cond do
      match?({:array, _}, ash_type) -> :multi_select
      values != [] -> :select
      ash_type == Ash.Type.Boolean -> :boolean
      ash_type == Ash.Type.Date -> :date
      true -> :text
    end
  end

  @doc """
  Whether `source` read with `action` (from `read_action/2`) can page by `mode`
  (`:offset` or `:keyset`), and if so whether it can count the records: Ash's read
  fails if asked to do either when the action can't.
  """
  @spec pagination(Ash.Query.t() | module(), atom(), :offset | :keyset) ::
          {:ok, %{count?: boolean()}} | {:error, String.t()}
  def pagination(source, action, mode) when mode in [:offset, :keyset] do
    query = Ash.Query.new(source)
    action = Ash.Resource.Info.action(query.resource, action)
    can_page? = if mode == :offset, do: :offset?, else: :keyset?
    action_name = "#{inspect(query.resource)}'s #{inspect(action.name)} action"

    case action.pagination do
      %{^can_page? => true, countable: countable} -> {:ok, %{count?: countable != false}}
      %{} -> {:error, "#{action_name} doesn't paginate by #{mode}"}
      _none -> {:error, "#{action_name} doesn't paginate"}
    end
  end

  @doc """
  Reads a page of records from `source` (a resource or query): `query`'s
  filters, arguments (each its input's value, as a filter's), search, sort and
  page, on the `fields` from `field/2`.

  Options, which come from the collection rather than the user:

    * `actor`, `tenant` and `scope` - as `Ash.read/2` takes them, which decides
      between them (an explicit actor or tenant wins over the scope's)
    * `action` - the read action, if not the source query's or the primary one
    * `query_opts` - more of `Ash.read/2`'s options, those in `read_opts/0`. Each
      reaches the read, and the ones `Ash.Query.for_read/4` also takes reach the
      query when it's built, so the action's preparations see them. `load` is
      merged with the columns' loads.
    * `pagination` - `:offset` (default) or `:keyset`
    * `search_fn` - a function to search with instead of a case-insensitive
      `contains` on each searchable field, called as `search_fn.(query, fields, text)`
      with the `Ash.Query` so far, the searchable fields in order, each as
      `%{name: "artist.name", expr: <Ash expression>}`, and the search text. It
      returns the query.
    * `count?` - whether to count the records (default `true`)
    * `arguments` - the read action's `Cinder.Engine.Argument`s, from
      `argument/3`: `query`'s `arguments` are under their `param`s, and so are
      errors about them, which the user can fix. Values for any others are left out.

  Every column's `load` is loaded, along with any in `query_opts`.

  A read that fails gives a `Cinder.Engine.Error`: the errors on read action
  arguments the user can fix, and the original error if it failed otherwise.
  """
  @spec run(Ash.Query.t() | module(), [Field.t()], Query.t(), keyword()) ::
          {:ok, Page.t()} | {:error, Error.t()}
  def run(source, fields, %Query{} = query, opts) do
    {load, read_opts} = opts |> Keyword.get(:query_opts, []) |> Keyword.pop(:load)
    loads = List.wrap(load) ++ for %Field{load: load} when not is_nil(load) <- fields, do: load

    options = [
      columns: Enum.map(fields, &Field.to_column_map/1),
      filters: query.filters,
      arguments: argument_values(query.arguments, opts[:arguments] || []),
      search_term: query.search,
      sort_by: query.sort,
      current_page: query.page,
      page_size: query.page_size || %Query{}.page_size,
      after_keyset: Query.cursor(query, :after),
      before_keyset: Query.cursor(query, :before),
      scope: opts[:scope],
      actor: opts[:actor],
      tenant: opts[:tenant],
      action: opts[:action],
      query_opts: [load: loads],
      read_opts: read_opts,
      pagination_mode: Keyword.get(opts, :pagination, :offset),
      count_mode: Keyword.get(opts, :count?, true),
      search_fn: search_fn(opts[:search_fn], source, fields)
    ]

    case QueryBuilder.build_and_execute(source, options) do
      {:ok, result} -> {:ok, page(result, query, options[:pagination_mode])}
      {:error, reason} -> {:error, error(reason, opts[:arguments] || [])}
    end
  end

  @doc """
  Runs `bulk_action` (from `bulk_action/2`) on the records whose primary keys are
  `ids` (as strings), reached as the collection reads them: from `source`, with
  its read action and that action's arguments. A selected record they can't read
  isn't acted on. The user's filters and search aren't applied, as a record they
  hide is still selected.

  Options, as `run/4` takes them: `actor`, `tenant`, `scope`, `action`,
  `arguments` and `query_opts` (only those the query takes when it's built). And:

    * `argument_values` - the arguments' values, as `run/4`'s query has them
    * `action_opts` - more options for the action: an update or destroy action's
      are `Ash.bulk_update/4`'s or `Ash.bulk_destroy/4`'s (with `return_errors?:
      true` unless given), and a function gets them as `bulk_options`, as a code
      interface takes them

  An update or destroy gives Ash's `Ash.BulkResult`, and a function what it
  returns: `{:ok, result}`, or `{:partial_success, result}` when some records
  failed and the rest changed, or `{:error, reason}`. A function that raises is an
  error with its message.
  """
  @spec run_bulk_action(Ash.Query.t() | module(), BulkAction.t(), [String.t()], keyword()) ::
          {:ok, term()} | {:partial_success, Ash.BulkResult.t()} | {:error, term()}
  def run_bulk_action(source, %BulkAction{action: action}, ids, opts) do
    {:ok, key} = primary_key(source)
    {_load, read_opts} = opts |> Keyword.get(:query_opts, []) |> Keyword.pop(:load)
    auth = Keyword.take(opts, [:actor, :tenant, :scope])

    options =
      [
        action: opts[:action],
        arguments: argument_values(opts[:argument_values] || %{}, opts[:arguments] || []),
        read_opts: read_opts
      ] ++ auth

    with {:ok, query} <- QueryBuilder.build_query(source, options) do
      execute_opts = [resource: query, ids: ids, id_field: key] ++ auth
      BulkActionExecutor.execute(action, [action_opts: opts[:action_opts] || []] ++ execute_opts)
    end
  end

  # The action takes each by its name
  defp argument_values(values, arguments) do
    for %Argument{name: name, param: param} <- arguments,
        %{value: value} <- [values[param]],
        into: %{},
        do: {name, value}
  end

  # `QueryBuilder` calls a search function with column maps, which stay behind the
  # engine: the shell's gets each searchable field's name and expression instead
  defp search_fn(nil, _source, _fields), do: nil

  defp search_fn(search_fn, source, fields) do
    resource = Ash.Query.new(source).resource

    searchable =
      for %Field{searchable?: true, name: name} <- fields do
        {:ok, resolved} = Cinder.Field.resolve(resource, name)
        %{name: name, expr: Cinder.Field.expr(resolved)}
      end

    fn query, _columns, text -> search_fn.(query, searchable, text) end
  end

  # Ash wraps its errors in a class (`Ash.Error.Invalid`, `Ash.Error.Unknown`, ...),
  # with the errors themselves in `errors`
  defp error(reason, arguments) do
    params = Map.new(arguments, &{&1.name, &1.param})
    errors = if is_map(reason), do: Map.get(reason, :errors, [reason]), else: [reason]
    {on_inputs, others} = Enum.split_with(errors, &on_input?(&1, params))

    # The conversion Phoenix forms use, so the messages are the ones a form would show.
    # One error can give several.
    inputs =
      on_inputs
      |> Enum.flat_map(&List.wrap(AshPhoenix.FormData.Error.to_form_error(&1)))
      |> Enum.group_by(&params[to_string(elem(&1, 0))], fn {_field, message, vars} ->
        {message, vars}
      end)

    %Error{inputs: inputs, reason: if(others != [], do: reason)}
  end

  # Only an argument with an input can be fixed by the user
  defp on_input?(error, params) do
    is_map(error) and Map.has_key?(params, to_string(Map.get(error, :field))) and
      AshPhoenix.FormData.Error.impl_for(error) != nil
  end

  # With no cursor, an action that can page either way pages by offset, whatever
  # was asked for. Its records still have their cursors, so in keyset mode it's
  # the first keyset page.
  defp page(%Ash.Page.Offset{} = page, _query, :keyset) do
    keyset_page(page, nil)
  end

  defp page(%Ash.Page.Offset{} = page, _query, _mode) do
    %Page{
      records: page.results,
      page: div(page.offset, page.limit) + 1,
      page_size: page.limit,
      count: page.count,
      more?: page.more?,
      previous?: page.offset > 0
    }
  end

  defp page(%Ash.Page.Keyset{} = page, query, _mode), do: keyset_page(page, query.cursor)
  defp page(%{results: records}, _query, _mode), do: %Page{records: records}

  # Ash's `more?` is whether there's more in the direction read: after the cursor,
  # or before it. Reading before a cursor means coming back from the page it's on,
  # so there's always a next page, and reading after one always has a previous.
  defp keyset_page(page, cursor) do
    {more?, previous?} =
      case cursor do
        {:before, _cursor} -> {true, page.more?}
        {:after, _cursor} -> {page.more?, true}
        nil -> {page.more?, false}
      end

    %Page{
      records: page.results,
      page_size: page.limit,
      count: page.count,
      more?: more?,
      previous?: previous?,
      first_cursor: keyset(List.first(page.results)),
      last_cursor: keyset(List.last(page.results))
    }
  end

  defp keyset(nil), do: nil
  defp keyset(record), do: record.__metadata__[:keyset]

  defp resolve(resource, name) do
    case Cinder.Field.resolve(resource, name) do
      {:ok, resolved} -> {:ok, resolved}
      :error -> {:error, "is not a field of #{inspect(resource)}"}
    end
  end

  # Only asked of a field that's queried: any field can be shown
  defp queryable(resolved, uses) do
    case {for({use, true} <- uses, do: use), Cinder.Field.query_error(resolved)} do
      {[_ | _] = used, problem} when is_binary(problem) ->
        {:error, "can't be #{Enum.join(used, " or ")}: it #{problem}"}

      _ ->
        :ok
    end
  end

  defp filter(_resolved, nil), do: {:ok, nil}

  defp filter(resolved, declared) do
    ash_type = Ash.Type.get_type(Cinder.Field.type(resolved))
    values = enum_values(ash_type, Cinder.Field.constraints(resolved))
    type = Map.get(declared, :type) || infer_type(ash_type, values)

    with {:error, problem} <- control(type, values, Map.get(declared, :options, [])) do
      {:error, "can't be filtered: #{problem}"}
    end
  end

  # A filter's control, or an argument's input: its type's module and options
  defp control(type, values, declared_options) do
    with {:ok, module} <- filter_module(type) do
      defaults = module.default_options()

      # Only types that take `options` get the field's values as options
      enum_options =
        if values != [] and Keyword.has_key?(defaults, :options), do: [options: values], else: []

      options =
        defaults
        |> Keyword.merge(enum_options)
        |> Keyword.merge(declared_options)

      {:ok, %{type: type, module: module, options: options}}
    end
  end

  defp filter_module(type) do
    known = Registry.all_filters_with_custom()

    case Map.fetch(known, type) do
      {:ok, module} ->
        if Code.ensure_loaded?(module) do
          {:ok, module}
        else
          {:error, "#{inspect(type)}'s module #{inspect(module)} can't be loaded"}
        end

      :error ->
        names = known |> Map.keys() |> Enum.sort() |> Enum.map_join(", ", &inspect/1)
        {:error, "#{inspect(type)} is not a filter type (known: #{names})"}
    end
  end

  # When nothing fits better, a text filter works on any field: it compares as strings
  defp infer_type(ash_type, values) do
    cond do
      match?({:array, _}, ash_type) -> :multi_select
      values != [] -> :select
      ash_type in @date_types -> :date_range
      ash_type == Ash.Type.Boolean -> :boolean
      ash_type in @number_types -> :number_range
      true -> :text
    end
  end

  # `{label, value}` pairs, from an enum type or a `one_of` constraint. An array's
  # values are its items', with the items' constraints under `:items`.
  defp enum_values({:array, item}, constraints) do
    enum_values(item, Keyword.get(constraints, :items, []))
  end

  defp enum_values(type, constraints) do
    cond do
      Keyword.has_key?(constraints, :one_of) ->
        Enum.map(constraints[:one_of], &{humanize(&1), &1})

      is_atom(type) and Spark.implements_behaviour?(type, Ash.Type.Enum) ->
        Enum.map(type.values(), &{type.label(&1) || humanize(&1), &1})

      true ->
        []
    end
  end

  defp humanize(value) when is_atom(value), do: Cinder.Filter.humanize_atom(value)
  defp humanize(value), do: to_string(value)
end
