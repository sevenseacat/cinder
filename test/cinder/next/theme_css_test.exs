defmodule Cinder.Next.ThemeCssTest do
  use ExUnit.Case, async: true

  alias Cinder.Next.ThemeCss

  test "a key with a part becomes a rule on its class, applying the key's classes" do
    css = ThemeCss.convert(Cinder.Themes.Modern)

    assert css =~ "@layer cinder {"
    assert css =~ ~r/\.cinder-header-cell \{\s*@apply px-6 py-4 text-left/
    assert css =~ ~r/\.cinder-row\[data-selected\] \{\s*@apply bg-blue-50\/50;/
  end

  test "keys with no part are listed rather than dropped silently" do
    [_rules, unmapped] = String.split(ThemeCss.convert(Cinder.Themes.Modern), "Not carried over")

    assert unmapped =~ "page_size_container_class:"
    refute unmapped =~ " th_class:"
  end

  test "can be scoped to a data-cinder-theme" do
    assert ThemeCss.convert("modern", scope: "modern-converted") =~
             ~s([data-cinder-theme="modern-converted"] {)
  end
end
