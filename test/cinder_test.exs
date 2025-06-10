defmodule CinderTest do
  use ExUnit.Case
  doctest Cinder

  test "greets the world" do
    assert Cinder.hello() == :world
  end
end
