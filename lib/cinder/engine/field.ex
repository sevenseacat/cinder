# SPDX-FileCopyrightText: 2026 Cinder contributors <https://github.com/sevenseacat/cinder/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Cinder.Engine.Field do
  @moduledoc """
  A field as the engine understands it, from `Cinder.Engine.field/3`.

  `filter`, `sortable?` and `searchable?` are what the developer allowed, so
  they're what input from outside the template (the URL, a search term) is
  checked against. `filter` is `nil` when the field can't be filtered. `load` is
  what showing the field needs loaded, for `Ash.Query.load/2`, or `nil`.
  """

  @type filter :: %{type: atom(), options: keyword()}

  @type t :: %__MODULE__{
          name: String.t(),
          filter: filter() | nil,
          sortable?: boolean(),
          searchable?: boolean(),
          load: term()
        }

  @enforce_keys [:name]
  defstruct [:name, :filter, :load, sortable?: false, searchable?: false]
end
