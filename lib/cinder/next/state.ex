# SPDX-FileCopyrightText: 2026 Cinder contributors <https://github.com/sevenseacat/cinder/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Cinder.Next.State do
  @moduledoc false
  # How a collection's state changes as the user works with it, and how it's read
  # from and written to the URL, as pure functions. For now its state is a
  # `Cinder.Engine.Query`; once there's more state that isn't query (layout, hidden
  # columns), this becomes the struct holding it all. The selection is
  # `Cinder.Next.RowSelection`'s. The URL is here, not in `Cinder.Params` (which turns
  # the query's strings into values), because that state goes in the URL too.

  alias Cinder.Engine.{Argument, Field, Page, Query}
  alias Cinder.Next.Config
  alias Cinder.Params

  @doc "The query a new collection starts with: the default sort, on the first page."
  def start(%Config{} = config) do
    %Query{sort: config.sort.default, page_size: config.pagination[:size]}
  end

  @doc """
  The query a URL's params ask for, from what the collection was started with.
  Anything in them the collection can't use is left out: the URL is the user's to
  edit.
  """
  def from_url(params, %Config{} = config) do
    opts = [
      search?: config.search != nil,
      pagination: config.pagination[:mode],
      arguments: config.arguments,
      sort_mode: config.sort.mode,
      page_sizes: config.pagination[:size_options]
    ]

    Params.from_url(params, config.fields, start(config), opts)
  end

  @doc "The query as URL params, leaving out whatever is as the collection started."
  def to_url(query, %Config{} = config) do
    Params.to_url(query, config.fields, start(config), arguments: config.arguments)
  end

  @doc "Every URL param the collection may write, so the URL's other params are kept."
  def url_keys(%Config{} = config) do
    Params.url_keys(config.fields, arguments: config.arguments)
  end

  @doc """
  The sort after clicking `field`, whose sort cycles through `cycle`. Additive
  (`mode`), the column clicked becomes the main sort and the others break its
  ties; exclusive, it's the only sort.
  """
  def toggle_sort(sort, field, cycle, mode) do
    others = Enum.reject(sort, &match?({^field, _direction}, &1))

    case {next_direction(cycle, List.keyfind(sort, field, 0)), mode} do
      {nil, :additive} -> others
      {nil, :exclusive} -> []
      {direction, :additive} -> [{field, direction} | others]
      {direction, :exclusive} -> [{field, direction}]
    end
  end

  # Unsorted, or a direction the cycle doesn't have (from the query or the URL),
  # starts the cycle again
  defp next_direction(cycle, current) do
    direction = if current, do: elem(current, 1)

    case Enum.find_index(cycle, &(&1 == direction)) do
      nil -> Enum.find(cycle, & &1)
      index -> Enum.at(cycle, rem(index + 1, length(cycle)))
    end
  end

  @doc """
  The query after choosing a page size (the form's string), on the first page. One
  that isn't offered (from a tampered event), or is the size shown, is ignored.
  """
  def change_page_size(query, size, %Config{} = config) do
    with %{size_options: options} <- config.pagination,
         {size, ""} <- Integer.parse(size),
         true <- size in options and size != query.page_size do
      {:ok, first_page(%{query | page_size: size})}
    else
      _ignored -> :ignore
    end
  end

  @doc """
  The query when the declarations change from `old` to `config`. The user's sort,
  filters, argument values, search and page size carry over, minus what's no longer
  declared or offered, though a sort or a page size the user hadn't changed from the
  old default becomes the new one. The page carries over too, if the records are the
  same (`same_records?`) and nothing else changed, and otherwise it's the first.
  """
  def carry_over(query, %Config{} = old, %Config{} = config, same_records?) do
    sortable = for %Field{sortable?: true, name: name} <- config.fields, do: name
    filterable = for %{column: column} <- config.filters, do: column.field
    searchable? = Enum.any?(config.fields, & &1.searchable?)
    arguments = for %Argument{param: param} <- config.arguments, do: param

    carried = %{
      query
      | sort: carry_over_sort(query.sort, old.sort.default, config.sort.default, sortable),
        filters: Map.take(query.filters, filterable),
        arguments: Map.take(query.arguments, arguments),
        search: if(searchable?, do: query.search, else: ""),
        page_size: carry_over_page_size(query.page_size, old.pagination, config.pagination)
    }

    if same_records? and first_page(carried) == first_page(query) do
      carried
    else
      first_page(carried)
    end
  end

  defp carry_over_sort(sort, old_default, new_default, sortable) do
    if sort == old_default do
      new_default
    else
      Enum.filter(sort, fn {field, _direction} -> field in sortable end)
    end
  end

  # Either may be `nil`, when the action doesn't page
  defp carry_over_page_size(size, old, new) do
    if size != old[:size] and size in (new[:size_options] || []), do: size, else: new[:size]
  end

  @doc """
  Where to go when the page shown has been emptied (by a bulk action deleting its
  records, or changing them so the read no longer reaches them), rather than show an
  empty page with records before it: the last page with records. Without a count to
  say which that is (an uncounted read, or keyset pages, whose cursors can't say),
  the first.
  """
  def leave_emptied_page(query, %Page{} = page, %Config{} = config) do
    cond do
      page.records != [] or first_page(query) == query -> :stay
      config.pagination[:mode] == :keyset -> {:move, first_page(query)}
      true -> {:move, %{query | page: last_page(page)}}
    end
  end

  defp last_page(%Page{count: count, page_size: size}) when is_integer(count) do
    max(div(count + size - 1, size), 1)
  end

  defp last_page(_uncounted), do: 1

  @doc "The query on its first page, as after anything that changes which records match."
  def first_page(query), do: %{query | page: 1, cursor: nil}
end
