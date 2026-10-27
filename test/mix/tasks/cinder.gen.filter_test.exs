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
          "--no-config"
        ])

      assert_creates(igniter, "lib/my_app/filters/boxes.ex")

      content =
        igniter.rewrite
        |> Rewrite.source!("lib/my_app/filters/boxes.ex")
        |> Rewrite.Source.get(:content)

      assert content =~ "Cinder.Filters.MultiCheckboxes.render("
      refute content =~ "Cinder.Filters.Text"

      # Shown by Igniter after the changes are applied, not printed while building them
      assert [notice] = igniter.notices
      assert notice =~ "MyApp.Filters.Boxes has been generated"
    end
  end
end
