defmodule Cinder.Filter.HelpersTest do
  use ExUnit.Case, async: true

  # The examples call the helpers unqualified, as a custom filter importing them would
  import Cinder.Filter.Helpers

  doctest Cinder.Filter.Helpers
end
