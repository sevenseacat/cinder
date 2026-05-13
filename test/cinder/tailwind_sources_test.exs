defmodule Cinder.TailwindSourcesTest do
  use ExUnit.Case, async: true

  @moduledoc """
  Guardrail tests for the Tailwind `@source` enumeration in `priv/cinder.css`
  and the per-theme files in `priv/themes/`.

  If a new top-level directory under `lib/cinder/` or a new built-in theme
  is added and these files don't match, users silently lose class detection.
  """

  @lib_cinder "lib/cinder"
  @priv_cinder_css "priv/cinder.css"

  test "priv/cinder.css enumerates every non-theme subdir under lib/cinder/" do
    css = File.read!(@priv_cinder_css)

    expected = expected_subdirs()
    enumerated = enumerated_subdirs(css)

    assert expected -- enumerated == [] and enumerated -- expected == [],
           "priv/cinder.css out of sync with #{@lib_cinder}/. Expected #{inspect(expected)}, got #{inspect(enumerated)}"

    assert css =~ ~s(@source "../lib/cinder.ex";)
    assert css =~ ~s(@source "../lib/cinder/*.ex";)
  end

  test "every lib/cinder/themes/*.ex has a matching priv/themes/*.css that points at it" do
    themes = File.ls!("lib/cinder/themes") |> Enum.map(&Path.rootname/1)

    for theme <- themes do
      css_path = "priv/themes/#{theme}.css"
      assert File.exists?(css_path), "missing #{css_path}"

      assert File.read!(css_path) =~ ~s(@source "../../lib/cinder/themes/#{theme}.ex";),
             "#{css_path} must @source the matching .ex"
    end

    # No orphans.
    priv_themes = File.ls!("priv/themes") |> Enum.map(&Path.rootname/1)
    assert priv_themes -- themes == []
  end

  test "Cinder.Tailwind.subdirs/0 matches lib/cinder/ structure" do
    assert Cinder.Tailwind.subdirs() |> Enum.sort() == expected_subdirs()
  end

  defp expected_subdirs do
    @lib_cinder
    |> File.ls!()
    |> Enum.filter(&File.dir?(Path.join(@lib_cinder, &1)))
    |> Enum.reject(&(&1 == "themes"))
    |> Enum.sort()
  end

  defp enumerated_subdirs(css) do
    ~r{cinder/([^/*"]+)/\*\*/\*\.ex}
    |> Regex.scan(css, capture: :all_but_first)
    |> List.flatten()
    |> Enum.sort()
  end
end
