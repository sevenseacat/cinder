defmodule Cinder.ReuseTest do
  @moduledoc """
  REUSE compliance for what's published, checked here so `mix check` catches it without
  the (Python) `reuse` tool. CI runs `reuse lint` on the whole repo.

  Published files (the Hex package, and the guides published to HexDocs) carry their own
  copyright and licence header. Everything else, and the generated `i18n` files (a header
  would fail `mix gettext.extract --check-up-to-date`), are covered by `REUSE.toml`.
  """
  use ExUnit.Case, async: true

  # `reuse lint` reads any tag in a file as the file's own, so these are fenced off
  # REUSE-IgnoreStart
  @copyright ~r/SPDX-FileCopyrightText: 20\d\d Cinder contributors <https:\/\/github\.com\/sevenseacat\/cinder\/graphs\/contributors>/
  @licence "SPDX-License-Identifier: MIT"
  # REUSE-IgnoreEnd

  defp published_files do
    package_files =
      Mix.Project.config()[:package][:files]
      |> Enum.flat_map(fn path ->
        if File.dir?(path), do: Path.wildcard(Path.join(path, "**/*.*")), else: [path]
      end)

    Enum.reject(package_files ++ Path.wildcard("docs/*.md"), fn path ->
      path == "LICENSE" or String.starts_with?(path, ["i18n/", "LICENSES/"])
    end)
  end

  test "published files carry their copyright and licence" do
    missing =
      for path <- published_files(),
          content = File.read!(path),
          not (content =~ @copyright and content =~ @licence),
          do: path

    assert missing == []
  end

  test "the licence text ships with the package" do
    assert File.exists?("LICENSES/MIT.txt")
    assert "LICENSES" in Mix.Project.config()[:package][:files]
  end
end
