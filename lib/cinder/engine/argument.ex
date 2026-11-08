# SPDX-FileCopyrightText: 2026 Cinder contributors <https://github.com/sevenseacat/cinder/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Cinder.Engine.Argument do
  @moduledoc false
  # An argument of a collection's read action, that the user gives a value for. The
  # shell fills in what the template declares, and `Cinder.Engine.argument/3`
  # checks it against the action and fills in the rest.
  #
  #   * `param` - what it goes by in the form and the URL, and so in
  #     `Cinder.Engine.Query`'s `arguments`: its name, unless that clashes. Filled
  #     in from `name` if not given.
  #   * `input` - the control for its value, which works as a filter's does: as
  #     declared, `%{}` with an optional `type` (inferred if missing) and
  #     `options`; once filled in, the type, its module and the options
  #   * `required?` - filled in: whether the action needs a value (it can't be
  #     `nil` and has no default)

  @type input :: %{type: atom(), module: module(), options: keyword()}

  @type t :: %__MODULE__{
          name: String.t(),
          param: String.t() | nil,
          input: input() | %{optional(:type) => atom(), optional(:options) => keyword()},
          required?: boolean()
        }

  @enforce_keys [:name]
  defstruct [:name, :param, input: %{}, required?: false]

  # The column map the engine's internals (`FilterManager`, `UrlManager`) and filter
  # types read, as for a `Cinder.Engine.Field`. Remove with `Field.to_column_map/1`.
  @doc false
  def to_column_map(%__MODULE__{} = argument) do
    %{
      field: argument.param,
      label: argument.name,
      filterable: true,
      filter_type: argument.input[:type],
      filter_options: argument.input[:options] || [],
      filter_fn: nil,
      searchable: false,
      sortable: false
    }
  end
end
