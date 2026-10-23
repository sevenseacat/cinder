defmodule Mix.Tasks.Cinder.Gen.FilterTest do
  use ExUnit.Case, async: true

  import Igniter.Test

  describe "template resolution" do
    test "multi_checkboxes template delegates to Cinder.Filters.MultiCheckboxes" do
      igniter =
        test_project()
        |> Igniter.compose_task("cinder.gen.filter", [
          "MyApp.Filters.Boxes",
          "boxes",
          "--template",
          "multi_checkboxes",
          "--no-tests",
          "--no-config",
          "--no-setup"
        ])

      assert_creates(igniter, "lib/my_app/filters/boxes.ex")

      content =
        igniter.rewrite
        |> Rewrite.source!("lib/my_app/filters/boxes.ex")
        |> Rewrite.Source.get(:content)

      assert content =~ "Cinder.Filters.MultiCheckboxes.render("
      refute content =~ "Cinder.Filters.Text"
    end
  end

  # The new shell (spike): a generated filter renders like its base until customised
  test "delegates the new shell's callbacks the base has, and only those" do
    content = generated("select")
    assert content =~ "def view(filter, ctx), do: Cinder.Filters.Select.view(filter, ctx)"
    assert content =~ "def control(assigns), do: Cinder.Filters.Select.control(assigns)"
    refute content =~ "options_schema"

    # Text renders as the default input, and a date range has its own options
    refute generated("text") =~ "def control("

    assert generated("date_range") =~
             "def options_schema, do: Cinder.Filters.DateRange.options_schema()"
  end

  defp generated(template) do
    test_project()
    |> Igniter.compose_task("cinder.gen.filter", [
      "MyApp.Filters.Custom",
      "custom",
      "--template",
      template,
      "--no-tests",
      "--no-config",
      "--no-setup"
    ])
    |> Map.fetch!(:rewrite)
    |> Rewrite.source!("lib/my_app/filters/custom.ex")
    |> Rewrite.Source.get(:content)
  end
end
