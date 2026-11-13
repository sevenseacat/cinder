# SPDX-FileCopyrightText: 2026 Cinder contributors <https://github.com/sevenseacat/cinder/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Cinder.Next.State do
  @moduledoc false
  # How a collection's state changes as the user works with it, as pure functions.
  # For now its state is a `Cinder.Engine.Query`; once there's more state that isn't
  # query (layout, hidden columns), this becomes the struct holding it all. The
  # selection is `Cinder.Next.RowSelection`'s.

  alias Cinder.Engine.{Argument, Field}
  alias Cinder.Next.Config

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
  The query when the declarations change from `old` to `config`. The user's sort,
  filters, argument values and search carry over, minus what's no longer
  declared, though a sort the user hadn't changed from the old default becomes the
  new one. The page size is the new config's. The page carries over too, if the
  records are the same (`same_records?`) and nothing else changed, and otherwise
  it's the first.
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
        page_size: config.pagination[:size]
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

  @doc "The query on its first page, as after anything that changes which records match."
  def first_page(query), do: %{query | page: 1, cursor: nil}
end
