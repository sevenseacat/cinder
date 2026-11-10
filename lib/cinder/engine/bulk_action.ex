# SPDX-FileCopyrightText: 2026 Cinder contributors <https://github.com/sevenseacat/cinder/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Cinder.Engine.BulkAction do
  @moduledoc false
  # What runs on a collection's selected records, from `Cinder.Engine.bulk_action/2`.
  #
  #   * `action` - an update or destroy action's name, or a function given a query
  #     for the selected records and the options to run it with
  #   * `type` - the action's type (`:update` or `:destroy`), or `nil` for a
  #     function

  @type t :: %__MODULE__{
          action: atom() | (Ash.Query.t(), keyword() -> term()),
          type: :update | :destroy | nil
        }

  @enforce_keys [:action]
  defstruct [:action, :type]
end
