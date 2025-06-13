defmodule Cinder.Theme.Override do
  @moduledoc """
  Data structure representing a theme override for a specific component.
  """

  defstruct [:component, properties: []]

  @type t :: %__MODULE__{
          component: atom(),
          properties: [Cinder.Theme.Property.t()]
        }
end
