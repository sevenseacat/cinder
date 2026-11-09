# SPDX-FileCopyrightText: 2026 Cinder contributors <https://github.com/sevenseacat/cinder/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Cinder.Next.State do
  @moduledoc false
  # How a collection's state changes as the user works with it, as pure functions.
  # For now its state is a `Cinder.Engine.Query` and the selected ids (a `MapSet` of
  # the strings the boxes carry), kept apart; once there's more state that isn't
  # query (layout, hidden columns), this becomes the struct holding it all.

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
  The sort to keep when the declarations change: the new default if the user
  hadn't changed it from the old one, or else theirs, minus fields that are no
  longer sortable.
  """
  def carry_over_sort(sort, old_default, new_default, sortable) do
    if sort == old_default do
      new_default
    else
      Enum.filter(sort, fn {field, _direction} -> field in sortable end)
    end
  end

  @doc """
  The filters, or argument values, to keep when the declarations change: those
  whose field is still filterable, or whose argument is still declared.
  """
  def carry_over_inputs(values, names), do: Map.take(values, names)

  @doc "The search to keep when the declarations change: all of it, while any field is searchable."
  def carry_over_search(_search, []), do: ""
  def carry_over_search(search, _searchable), do: search

  @doc """
  The page to keep when the declarations change: the same one if the read gives the
  same records (`same_source?`, and nothing in `query` but the page changed from
  `old`), or else the first.
  """
  def carry_over_page(query, old, same_source?) do
    if same_source? and first_page(query) == first_page(old) do
      query
    else
      first_page(query)
    end
  end

  @doc "The query on its first page, as after anything that changes which records match."
  def first_page(query), do: %{query | page: 1, cursor: nil}

  @doc """
  The selected ids after a record's box is clicked: `id` selected, or cleared if it
  was. Only an id in `selectable` (the page shown's records that can be selected)
  can be, so any other, from a forged event, changes nothing.
  """
  def toggle_selected(selected, id, selectable) do
    cond do
      id not in selectable -> selected
      id in selected -> MapSet.delete(selected, id)
      true -> MapSet.put(selected, id)
    end
  end

  @doc "The selected ids with every one of `selectable` (the page's) added."
  def select_page(selected, selectable), do: MapSet.union(selected, selectable)

  @doc "The selected ids with every one of `selectable` (the page's) removed."
  def clear_page(selected, selectable), do: MapSet.difference(selected, selectable)

  @doc """
  Whether every one of `selectable` (the page's) is selected, so the page's box is
  checked. A page with nothing selectable isn't.
  """
  def page_selected?(selected, selectable) do
    MapSet.size(selectable) > 0 and MapSet.subset?(selectable, selected)
  end
end
