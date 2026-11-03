# SPDX-FileCopyrightText: 2026 Cinder contributors <https://github.com/sevenseacat/cinder/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Cinder.Engine.Field do
  @moduledoc false
  # A field of a collection. The shell fills in what the template declares, and
  # `Cinder.Engine.field/2` checks it against the resource and fills in the rest.
  # `run/4` and `Cinder.Params` take fields that have been through it.
  #
  #   * `filter` - `nil` if it isn't filtered. As declared, `%{}` with an optional
  #     `type` (inferred if missing) and `options`; once filled in, the type, its
  #     module (for the shell to render the control and check options with) and the
  #     options
  #   * `sortable?` and `searchable?` - what the developer allowed, so what input
  #     from outside the template (the URL, a search term) is checked against
  #   * `column?` - whether it's a column, so can be shown (hidden or not)
  #   * `load` - filled in: what showing it as a column needs loaded, for
  #     `Ash.Query.load/2`, or `nil`

  @type filter :: %{type: atom(), module: module(), options: keyword()}

  @type t :: %__MODULE__{
          name: String.t(),
          filter: filter() | %{optional(:type) => atom(), optional(:options) => keyword()} | nil,
          sortable?: boolean(),
          searchable?: boolean(),
          column?: boolean(),
          load: term()
        }

  @enforce_keys [:name]
  defstruct [:name, :filter, :load, sortable?: false, searchable?: false, column?: false]

  # The column map the engine's internals (`QueryBuilder`, `FilterManager`,
  # `UrlManager`), filter types and a custom `search_fn` read, with every key set.
  # Remove when the internals stop needing column maps.
  @doc false
  def to_column_map(%__MODULE__{} = field) do
    %{
      field: field.name,
      label: field.name,
      filterable: field.filter != nil,
      filter_type: field.filter && field.filter.type,
      filter_options: (field.filter && field.filter.options) || [],
      filter_fn: nil,
      searchable: field.searchable?,
      sortable: field.sortable?
    }
  end
end
