defmodule Cinder.PackageTest do
  use ExUnit.Case, async: true

  test "ships JavaScript hooks with the package priv directory" do
    package_files = Mix.Project.config() |> Keyword.fetch!(:package) |> Keyword.fetch!(:files)

    assert "priv" in package_files
    assert File.regular?("priv/static/cinder_hooks.js")
  end
end
