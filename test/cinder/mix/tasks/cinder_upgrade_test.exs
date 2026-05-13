defmodule Cinder.Mix.Tasks.CinderUpgradeTest do
  use ExUnit.Case, async: false

  if Code.ensure_loaded?(Igniter) do
    import Igniter.Test

    @old_app_css """
    @import "tailwindcss";
    @source "../../deps/cinder";
    """

    @new_app_css """
    @import "tailwindcss";
    @import "../../deps/cinder/priv/cinder.css";
    @import "../../deps/cinder/priv/themes/modern.css";
    """

    @v3_old """
    module.exports = {
      content: [
        "./js/**/*.js",
        "../deps/cinder/lib/**/*.*ex",
      ],
    }
    """

    setup do
      original = Application.get_env(:cinder, :default_theme, :not_set)

      on_exit(fn ->
        case original do
          :not_set -> Application.delete_env(:cinder, :default_theme)
          value -> Application.put_env(:cinder, :default_theme, value)
        end
      end)
    end

    describe "0.14.0 — v4 app.css migration" do
      test "replaces @source with new @import block plus configured theme" do
        assert upgrade_app_css(@old_app_css, "modern") == @new_app_css
      end

      test "resolves built-in theme module to its CSS file (including CamelCase like DaisyUI)" do
        assert upgrade_app_css(@old_app_css, Cinder.Themes.Dark) =~
                 ~s(@import "../../deps/cinder/priv/themes/dark.css";)

        assert upgrade_app_css(@old_app_css, Cinder.Themes.DaisyUI) =~
                 ~s(@import "../../deps/cinder/priv/themes/daisy_ui.css";)
      end

      test "no theme @import for custom module or unset default_theme" do
        defmodule CustomTheme do
        end

        for theme <- [CustomTheme, nil] do
          content = upgrade_app_css(@old_app_css, theme)
          assert content =~ ~s(@import "../../deps/cinder/priv/cinder.css";)
          refute content =~ "priv/themes/"
        end
      end

      test "idempotent when new format is already present" do
        test_project(files: %{"assets/css/app.css" => @new_app_css})
        |> Igniter.compose_task("cinder.upgrade", ["0.13.0", "0.14.0"])
        |> assert_unchanged("assets/css/app.css")
      end

      test "no-op when app.css is absent" do
        test_project()
        |> Igniter.compose_task("cinder.upgrade", ["0.13.0", "0.14.0"])
        |> assert_unchanged()
      end

      test "does not modify default_theme config" do
        Application.put_env(:cinder, :default_theme, "modern")

        test_project(
          files: %{
            "assets/css/app.css" => @old_app_css,
            "config/config.exs" => "import Config\nconfig :cinder, default_theme: \"modern\"\n"
          }
        )
        |> Igniter.compose_task("cinder.upgrade", ["0.13.0", "0.14.0"])
        |> assert_unchanged("config/config.exs")
      end
    end

    describe "0.14.0 — v3 tailwind.config.js migration" do
      test "replaces broad glob with enumerated paths + theme" do
        content = upgrade_v3(@v3_old, "modern")

        assert content =~ ~s("../deps/cinder/lib/cinder.ex")
        assert content =~ ~s("../deps/cinder/lib/cinder/filter/**/*.ex")
        assert content =~ ~s("../deps/cinder/lib/cinder/themes/modern.ex")
        refute content =~ ~s("../deps/cinder/lib/**/*.*ex")
      end

      test "no theme path when default_theme is unset" do
        content = upgrade_v3(@v3_old, nil)
        assert content =~ ~s("../deps/cinder/lib/cinder.ex")
        refute content =~ "lib/cinder/themes/"
      end

      test "idempotent when already enumerated" do
        already_migrated = ~s|module.exports = { content: ["../deps/cinder/lib/cinder.ex"] }|

        test_project(files: %{"assets/tailwind.config.js" => already_migrated})
        |> Igniter.compose_task("cinder.upgrade", ["0.13.0", "0.14.0"])
        |> assert_unchanged("assets/tailwind.config.js")
      end
    end

    defp upgrade_app_css(css, theme), do: run_upgrade("assets/css/app.css", css, theme)

    defp upgrade_v3(config, theme), do: run_upgrade("assets/tailwind.config.js", config, theme)

    defp run_upgrade(path, content, theme) do
      if theme,
        do: Application.put_env(:cinder, :default_theme, theme),
        else: Application.delete_env(:cinder, :default_theme)

      test_project(files: %{path => content})
      |> Igniter.compose_task("cinder.upgrade", ["0.13.0", "0.14.0"])
      |> then(&Rewrite.Source.get(Rewrite.source!(&1.rewrite, path), :content))
    end
  end
end
