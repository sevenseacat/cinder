defmodule Cinder.Theme.Property do
  @moduledoc """
  Data structure representing a single theme property setting.
  """

  defstruct [:key, :value]

  @type t :: %__MODULE__{
          key: atom(),
          value: String.t()
        }
end
