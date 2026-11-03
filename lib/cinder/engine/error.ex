# SPDX-FileCopyrightText: 2026 Cinder contributors <https://github.com/sevenseacat/cinder/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Cinder.Engine.Error do
  @moduledoc false
  # Why `Cinder.Engine.run/4` read no records.
  #
  #   * `inputs` - errors the user can fix, by the name of the read action argument
  #     they're about, as `{message, vars}` to translate (as Phoenix form errors are)
  #   * `reason` - `nil` when `inputs` are the only problem, or else the original
  #     error, for developers: the read failed for some other reason

  @type message :: {String.t(), keyword()}

  @type t :: %__MODULE__{
          inputs: %{String.t() => [message()]},
          reason: term()
        }

  defstruct inputs: %{}, reason: nil
end
