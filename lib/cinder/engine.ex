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

  alias Cinder.Engine.{Error, Field, Page, Query}
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

  @doc """
  Checks a field as declared (a `Cinder.Engine.Field`) against `resource`, and
  fills in the rest: its filter's type, module and options, and what showing it
  needs loaded.

  A filter's options are its type's defaults, then the field's enum values (for
  types that take `options`), then the declared ones.

  Anything wrong is the developer's mistake, so it's an error naming the field:
  a field the resource doesn't have, filtering, sorting or searching a field that
  can't be queried, or a filter type that doesn't exist.
  """
  @spec field(module(), Field.t()) :: {:ok, Field.t()} | {:error, String.t()}
  def field(resource, %Field{name: name} = field) do
    uses = [filtered: field.filter != nil, sorted: field.sortable?, searched: field.searchable?]

    with {:ok, resolved} <- resolve(resource, name),
         :ok <- queryable(resolved, uses),
         {:ok, filter} <- filter(resolved, field.filter) do
      load = if field.column?, do: Cinder.Field.load(resolved)
      {:ok, %{field | filter: filter, load: load}}
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
  Reads a page of records from `source` (a resource or query): `query`'s
  filters, arguments, search, sort and page, on the `fields` from `field/2`.

  Options, which come from the collection rather than the user:

    * `actor`, `tenant` and `scope` - as `Ash.read/2` takes them, which decides
      between them (an explicit actor or tenant wins over the scope's)
    * `action` - the read action, if not the source query's or the primary one
    * `query_opts` - more of `Ash.read/2`'s options. Each reaches the read, and the
      ones `Ash.Query.for_read/4` also takes reach the query when it's built, so
      the action's preparations see them. `load` is merged with the columns' loads.
    * `pagination` - `:offset` (default) or `:keyset`
    * `search_fn` - a function to search with instead of a `contains` on each
      searchable field, called as `search_fn.(query, searchable_columns, term)`
      with the `Ash.Query` so far, the searchable fields as column maps (`field`,
      `label`, `filter_type`, ...), and the search term. It returns the query.
    * `count?` - whether to count the records (default `true`)
    * `arguments` - the names of the read action arguments the user has inputs
      for, so errors about them go on those inputs

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
      arguments: query.arguments,
      search_term: query.search,
      sort_by: query.sort,
      current_page: query.page,
      page_size: query.page_size,
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
      search_fn: opts[:search_fn]
    ]

    case QueryBuilder.build_and_execute(source, options) do
      {:ok, result} -> {:ok, page(result, query, options[:pagination_mode])}
      {:error, reason} -> {:error, error(reason, Keyword.get(opts, :arguments, []))}
    end
  end

  # Ash wraps its errors in a class (`Ash.Error.Invalid`, `Ash.Error.Unknown`, ...),
  # with the errors themselves in `errors`
  defp error(reason, arguments) do
    errors = if is_map(reason), do: Map.get(reason, :errors, [reason]), else: [reason]
    {on_inputs, others} = Enum.split_with(errors, &on_input?(&1, arguments))

    # The conversion Phoenix forms use, so the messages are the ones a form would show.
    # One error can give several.
    inputs =
      on_inputs
      |> Enum.flat_map(&List.wrap(AshPhoenix.FormData.Error.to_form_error(&1)))
      |> Enum.group_by(&to_string(elem(&1, 0)), fn {_field, message, vars} -> {message, vars} end)

    %Error{inputs: inputs, reason: if(others != [], do: reason)}
  end

  # Only an argument with an input can be fixed by the user
  defp on_input?(error, arguments) do
    is_map(error) and to_string(Map.get(error, :field)) in arguments and
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

    with {:ok, module} <- filter_module(type) do
      defaults = module.default_options()

      # Only types that take `options` get the field's values as options
      enum_options =
        if values != [] and Keyword.has_key?(defaults, :options), do: [options: values], else: []

      options =
        defaults
        |> Keyword.merge(enum_options)
        |> Keyword.merge(Map.get(declared, :options, []))

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
          {:error,
           "can't be filtered: #{inspect(type)}'s module #{inspect(module)} can't be loaded"}
        end

      :error ->
        names = known |> Map.keys() |> Enum.sort() |> Enum.map_join(", ", &inspect/1)
        {:error, "can't be filtered: #{inspect(type)} is not a filter type (known: #{names})"}
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
