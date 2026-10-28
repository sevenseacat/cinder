defmodule Cinder.TranslationsTest do
  @moduledoc """
  `mix gettext.merge` pre-fills a new string from a similar one and marks it fuzzy, and Gettext
  uses fuzzy translations, so a reviewed `.po` file has none.
  """
  use ExUnit.Case, async: true

  test "no translation is fuzzy" do
    fuzzy =
      for path <- Path.wildcard("i18n/gettext/*/LC_MESSAGES/*.po"),
          {line, number} <- path |> File.read!() |> String.split("\n") |> Enum.with_index(1),
          String.starts_with?(line, "#,") and line =~ "fuzzy",
          do: "#{path}:#{number}"

    assert fuzzy == []
  end
end
