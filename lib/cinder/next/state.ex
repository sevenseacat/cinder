# SPDX-FileCopyrightText: 2026 Cinder contributors <https://github.com/sevenseacat/cinder/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Cinder.Next.State do
  @moduledoc false
  # How a collection's state changes as the user works with it, as pure functions.
  # For now its state is a `Cinder.Engine.Query`; once there's state that isn't
  # query (selection, layout, hidden columns), this becomes the struct holding it all.

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

  @doc "The filters to keep when the declarations change: those still filterable."
  def carry_over_filters(filters, filterable), do: Map.take(filters, filterable)
end
