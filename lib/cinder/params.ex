# SPDX-FileCopyrightText: 2026 Cinder contributors <https://github.com/sevenseacat/cinder/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Cinder.Params do
  @moduledoc false
  # Strings to and from values: a filter form's params, and a collection's URL
  # params.
  #
  # The shell hands it what was typed or what's in the URL, and gets back the
  # values to query with, or the other way round. It doesn't touch Ash: what a
  # field is comes from `Cinder.Engine`.
  #
  # Input comes from users, so input that can't be used is left out, never an error.

  alias Cinder.Engine.{Argument, Field, Query}
  alias Cinder.{FilterManager, UrlManager}

  # The keys `to_url/4` writes that aren't a field's or an argument's
  @own_keys ~w(search sort page after before page_size)

  @doc """
  The filters in a filter form's params (`%{"genre" => "rock", "price_min" =>
  "10"}`), as `Cinder.Engine.Query`'s `filters`: each filterable field's input
  as its filter type's value. Input a field's filter can't use is left out.

  Given `Cinder.Engine.Argument`s instead, the same for their inputs, as
  `Cinder.Engine.Query`'s `arguments`.
  """
  @spec filters_from_params(%{String.t() => term()}, [Field.t() | Argument.t()]) ::
          %{String.t() => map()}
  def filters_from_params(params, inputs) do
    FilterManager.params_to_filters(params, Enum.map(inputs, &column_map/1))
  end

  defp column_map(%Field{} = field), do: Field.to_column_map(field)
  defp column_map(%Argument{} = argument), do: Argument.to_column_map(argument)

  # Every argument has an input
  defp filtered?(%Field{filter: filter}), do: filter != nil
  defp filtered?(%Argument{}), do: true

  @doc """
  The other way: `filters` as the values each filterable field's control shows
  (`"rock"`, `%{min: "10", max: ""}`), or its type's empty value if it isn't
  filtered. Takes `Cinder.Engine.Argument`s and their values too.
  """
  @spec filter_values(%{String.t() => map()}, [Field.t() | Argument.t()]) ::
          %{String.t() => term()}
  def filter_values(filters, inputs) do
    # A bridge: `build_filter_values` formats with a hardcoded list of types, so a
    # custom type gets its raw value. Each type should format its own, as each
    # parses its own URL value, when filter types are redesigned.
    columns = for input <- inputs, filtered?(input), do: column_map(input)
    FilterManager.build_filter_values(columns, filters)
  end

  @doc """
  A query as URL params, leaving out whatever matches `defaults` (the collection's
  starting query), so a collection as it started has none.

  Options:

    * `arguments` - the read action's `Cinder.Engine.Argument`s, whose values go
      in the URL under their `param`s, encoded as filters' are
  """
  @spec to_url(Query.t(), [Field.t()], Query.t(), keyword()) :: %{String.t() => String.t()}
  def to_url(%Query{} = query, fields, %Query{} = defaults, opts) do
    %{
      filters: Map.take(query.filters, filterable(fields)),
      sort_by: if(query.sort == defaults.sort, do: [], else: query.sort),
      current_page: query.page,
      after: Query.cursor(query, :after),
      before: Query.cursor(query, :before),
      page_size: query.page_size,
      default_page_size: defaults.page_size,
      search_term: query.search
    }
    |> UrlManager.encode_state()
    |> Map.new(fn {key, value} -> {to_string(key), value} end)
    |> Map.merge(unsorted(query.sort, defaults.sort))
    |> Map.merge(argument_params(query.arguments, opts))
  end

  # A URL without `sort` has the default sort, so no sort, when the default has
  # one, is an empty `sort`
  defp unsorted([], [_ | _]), do: %{"sort" => ""}
  defp unsorted(_sort, _default), do: %{}

  @doc """
  URL params as a query, with whatever isn't there from `defaults`. Params that
  aren't the collection's are ignored, and ones it can't use fall back to the
  default: sorts on fields that aren't sortable, filters a field's filter can't
  use, and page sizes that aren't allowed.

  Each filter's URL value goes to its type as the string `to_url/4` wrote, and
  the type parses it.

  Options:

    * `arguments` - the read action's `Cinder.Engine.Argument`s
    * `page_sizes` - the page sizes the URL may ask for (default: only the
      default's), so a URL can't ask for any number of records
    * `search?` - whether the collection can be searched (default: `true`)
    * `pagination` - if given, the paging mode: `:offset` ignores a cursor,
      `:keyset` a page number, and `nil` (not paged) both
    * `sort_mode` - `:exclusive` keeps only the first sort the collection can
      use, as it only ever sorts by one field (default: `:additive`, all of them)
  """
  @spec from_url(%{String.t() => term()}, [Field.t()], Query.t(), keyword()) :: Query.t()
  def from_url(params, fields, %Query{} = defaults, opts) do
    sort =
      if Map.has_key?(params, "sort") do
        params["sort"]
        |> UrlManager.decode_sort(Enum.map(fields, &Field.to_column_map/1))
        |> limit_sorts(Keyword.get(opts, :sort_mode, :additive))
      else
        defaults.sort
      end

    search? = Keyword.get(opts, :search?, true) and is_binary(params["search"])

    query = %Query{
      filters: filters_from_params(params, fields),
      arguments: filters_from_params(params, Keyword.get(opts, :arguments, [])),
      search: if(search?, do: params["search"], else: defaults.search),
      sort: sort,
      page: UrlManager.decode_page(params["page"]),
      cursor: url_cursor(params),
      page_size: page_size(params["page_size"], defaults.page_size, opts[:page_sizes])
    }

    case Keyword.fetch(opts, :pagination) do
      {:ok, :offset} -> %{query | cursor: defaults.cursor}
      {:ok, :keyset} -> %{query | page: defaults.page}
      {:ok, nil} -> %{query | page: defaults.page, cursor: defaults.cursor}
      :error -> query
    end
  end

  @doc """
  The keys `to_url/4` writes that aren't a field's or an argument's, so no field
  or argument `param` can be one.
  """
  @spec own_keys() :: [String.t()]
  def own_keys, do: @own_keys

  @doc """
  Every key `to_url/4` may write for `fields`, so whatever keeps a URL's other
  params knows which are the collection's. Takes `to_url/4`'s `arguments`.
  """
  @spec url_keys([Field.t()], keyword()) :: [String.t()]
  def url_keys(fields, opts) do
    @own_keys ++ filterable(fields) ++ argument_keys(opts)
  end

  defp filterable(fields) do
    for %Field{filter: filter, name: name} when filter != nil <- fields, do: name
  end

  defp limit_sorts(sort, :exclusive), do: Enum.take(sort, 1)
  defp limit_sorts(sort, _mode), do: sort

  # A URL may have both: `after` wins, as it does in `Cinder.UrlManager`
  defp url_cursor(params) do
    case {UrlManager.decode_cursor(params["after"]), UrlManager.decode_cursor(params["before"])} do
      {nil, nil} -> nil
      {nil, before} -> {:before, before}
      {after_cursor, _before} -> {:after, after_cursor}
    end
  end

  defp argument_keys(opts) do
    for %Argument{param: param} <- Keyword.get(opts, :arguments, []), do: param
  end

  defp argument_params(values, opts) do
    values
    |> Map.take(argument_keys(opts))
    |> UrlManager.encode_filters()
    |> Map.new(fn {key, value} -> {to_string(key), value} end)
  end

  defp page_size(param, default, allowed) do
    with param when is_binary(param) <- param,
         {size, ""} <- Integer.parse(param),
         true <- size in (allowed || [default]) do
      size
    else
      _ -> default
    end
  end
end
