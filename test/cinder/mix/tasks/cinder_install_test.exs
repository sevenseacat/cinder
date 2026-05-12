defmodule Cinder.Mix.Tasks.CinderInstallTest do
  use ExUnit.Case, async: true

  describe "Mix.Tasks.Cinder.Install" do
    test "task is available regardless of whether Igniter is loaded" do
      assert Code.ensure_loaded?(Mix.Tasks.Cinder.Install)
      assert function_exported?(Mix.Tasks.Cinder.Install, :run, 1)
    end
  end

  if Code.ensure_loaded?(Igniter) do
    import Igniter.Test

    @blank_app_css "@import \"tailwindcss\";\n"
    @blank_config "import Config\n"
    @v3_starting """
    module.exports = {
      content: [
        "./js/**/*.js",
      ],
    }
    """

    describe "Tailwind v4 install" do
      test "adds @import lines and notices other built-in themes" do
        result =
          test_project(files: %{"assets/css/app.css" => @blank_app_css})
          |> Igniter.compose_task("cinder.install", [])

        assert_has_patch(result, "assets/css/app.css", """
        |@import "tailwindcss";
        + |@import "../../deps/cinder/priv/cinder.css";
        + |@import "../../deps/cinder/priv/themes/daisy_ui.css";
        """)

        assert_has_notice(result, fn n ->
          # Other built-ins listed in the notice, but not the default (daisy_ui).
          n =~ "dark" and n =~ "modern" and n =~ "Other built-in themes:" and
            not String.contains?(n, "Other built-in themes: daisy_ui") and
            not String.contains?(n, ", daisy_ui")
        end)
      end

      test "is idempotent on the new @import format" do
        existing =
          @blank_app_css <>
            "@import \"../../deps/cinder/priv/cinder.css\";\n" <>
            "@import \"../../deps/cinder/priv/themes/daisy_ui.css\";\n"

        test_project(files: %{"assets/css/app.css" => existing})
        |> Igniter.compose_task("cinder.install", [])
        |> assert_unchanged("assets/css/app.css")
      end

      test "leaves the old @source format alone (upgrade migrates it)" do
        existing = @blank_app_css <> "@source \"../../deps/cinder\";\n"

        test_project(files: %{"assets/css/app.css" => existing})
        |> Igniter.compose_task("cinder.install", [])
        |> assert_unchanged("assets/css/app.css")
      end
    end

    describe "Tailwind v3 install" do
      test "adds enumerated content paths plus the default theme" do
        content =
          test_project(files: %{"assets/tailwind.config.js" => @v3_starting})
          |> Igniter.compose_task("cinder.install", [])
          |> source_content("assets/tailwind.config.js")

        for path <- [
              "../deps/cinder/lib/cinder.ex",
              "../deps/cinder/lib/cinder/*.ex",
              "../deps/cinder/lib/cinder/filters/**/*.ex",
              "../deps/cinder/lib/cinder/renderers/**/*.ex",
              "../deps/cinder/lib/cinder/themes/daisy_ui.ex"
            ],
            do: assert(content =~ "\"#{path}\"")

        refute content =~ ~s("../deps/cinder/lib/**/*.*ex")
      end

      test "is idempotent when any cinder path is already present" do
        existing = ~s|module.exports = { content: ["../deps/cinder/lib/cinder.ex"] }|

        test_project(files: %{"assets/tailwind.config.js" => existing})
        |> Igniter.compose_task("cinder.install", [])
        |> assert_unchanged("assets/tailwind.config.js")
      end
    end

    describe "default_theme config" do
      test "sets default_theme when missing" do
        test_project(
          files: %{"assets/css/app.css" => @blank_app_css, "config/config.exs" => @blank_config}
        )
        |> Igniter.compose_task("cinder.install", [])
        |> assert_has_patch("config/config.exs", """
        + |config :cinder, default_theme: "daisy_ui"
        """)
      end

      test "leaves default_theme alone when already set" do
        existing = @blank_config <> "config :cinder, default_theme: \"dark\"\n"

        test_project(
          files: %{"assets/css/app.css" => @blank_app_css, "config/config.exs" => existing}
        )
        |> Igniter.compose_task("cinder.install", [])
        |> assert_unchanged("config/config.exs")
      end
    end

    defp source_content(igniter, path) do
      igniter.rewrite |> Rewrite.source!(path) |> Rewrite.Source.get(:content)
    end
  end
end
