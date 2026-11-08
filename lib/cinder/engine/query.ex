# SPDX-FileCopyrightText: 2026 Cinder contributors <https://github.com/sevenseacat/cinder/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Cinder.Engine.Query do
  @moduledoc false
  # What `Cinder.Engine.run/4` reads: the parts of a collection's state that pick
  # its records, which change as the user filters, searches, sorts and pages.
  #
  # `arguments` are the arguments' inputs' values, as `filters` are the fields',
  # under each argument's `param`. An empty `sort` leaves the source query's own
  # sort alone. `page` is for offset pagination, and `cursor` (`{:after | :before,
  # cursor}`) for keyset.
  # `page_size` is `nil` when the collection isn't paged; an action that pages
  # anyway uses the default.

  @type t :: %__MODULE__{
          filters: %{String.t() => map()},
          arguments: %{String.t() => map()},
          search: String.t(),
          sort: [{String.t(), atom()}],
          page: pos_integer(),
          cursor: nil | {:after | :before, String.t()},
          page_size: pos_integer() | nil
        }

  defstruct filters: %{},
            arguments: %{},
            search: "",
            sort: [],
            page: 1,
            cursor: nil,
            page_size: 25

  @doc "The keyset cursor to read `direction` (`:after` or `:before`) of, if that's the way it reads."
  @spec cursor(t(), :after | :before) :: String.t() | nil
  def cursor(%__MODULE__{cursor: {direction, cursor}}, direction), do: cursor
  def cursor(%__MODULE__{}, _direction), do: nil
end
