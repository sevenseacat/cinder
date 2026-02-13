defmodule Mix.Tasks.Cinder.UpgradeTest do
  use ExUnit.Case, async: true
  import Igniter.Test

  describe "rename_boolean_theme_keys/2" do
    test "renames filter_boolean_* to filter_radio_group_* in theme modules" do
      igniter =
        test_project()
        |> Igniter.create_new_file("lib/my_app/custom_theme.ex", """
        defmodule MyApp.CustomTheme do
          use Cinder.Theme

          set :filter_boolean_container_class, "flex space-x-6"
          set :filter_boolean_option_class, "flex items-center"
          set :filter_boolean_radio_class, "h-4 w-4"
          set :filter_boolean_label_class, "text-sm"
        end
        """)
        |> apply_igniter!()

      result =
        igniter
        |> Mix.Tasks.Cinder.Upgrade.rename_boolean_theme_keys(%{})

      assert_has_patch(result, "lib/my_app/custom_theme.ex", """
      - |  set(:filter_boolean_container_class, "flex space-x-6")
      - |  set(:filter_boolean_option_class, "flex items-center")
      - |  set(:filter_boolean_radio_class, "h-4 w-4")
      - |  set(:filter_boolean_label_class, "text-sm")
      + |  set(:filter_radio_group_container_class, "flex space-x-6")
      + |  set(:filter_radio_group_option_class, "flex items-center")
      + |  set(:filter_radio_group_radio_class, "h-4 w-4")
      + |  set(:filter_radio_group_label_class, "text-sm")
      """)
    end

    test "does not modify non-theme modules" do
      igniter =
        test_project()
        |> Igniter.create_new_file("lib/my_app/something.ex", """
        defmodule MyApp.Something do
          def filter_boolean_container_class, do: "test"
        end
        """)
        |> apply_igniter!()

      result =
        igniter
        |> Mix.Tasks.Cinder.Upgrade.rename_boolean_theme_keys(%{})

      assert result.warnings == []
      assert result.issues == []
    end
  end
end
