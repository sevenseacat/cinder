defmodule Mix.Tasks.Cinder.UpgradeTest do
  use ExUnit.Case, async: true
  import Igniter.Test

  alias Mix.Tasks.Cinder.Upgrade

  describe "transform_component_blocks/1" do
    test "transforms single component block" do
      input = """
      defmodule MyApp.Theme do
        use Cinder.Theme

        component Cinder.Components.Table do
          set :container_class, "custom-container"
        end
      end
      """

      result = Upgrade.transform_component_blocks(input)

      assert result =~ "# Table"
      assert result =~ ~s(set :container_class, "custom-container")
      refute result =~ "component Cinder.Components.Table do"
    end

    test "transforms multiple component blocks" do
      input = """
      defmodule MyApp.Theme do
        use Cinder.Theme

        component Cinder.Components.Table do
          set :container_class, "table-container"
          set :row_class, "table-row"
        end

        component Cinder.Components.Filters do
          set :filter_container_class, "filter-container"
        end
      end
      """

      result = Upgrade.transform_component_blocks(input)

      assert result =~ "# Table"
      assert result =~ "# Filters"

      assert result =~ ~s(set :container_class, "table-container")
      assert result =~ ~s(set :row_class, "table-row")
      assert result =~ ~s(set :filter_container_class, "filter-container")

      refute result =~ "component Cinder.Components.Table do"
      refute result =~ "component Cinder.Components.Filters do"
    end

    test "preserves extends declaration" do
      input = """
      defmodule MyApp.Theme do
        use Cinder.Theme
        extends :modern

        component Cinder.Components.Table do
          set :container_class, "custom"
        end
      end
      """

      result = Upgrade.transform_component_blocks(input)

      assert result =~ "extends :modern"
      assert result =~ "# Table"
      assert result =~ ~s(set :container_class, "custom")
    end

    test "handles multiline set values" do
      input = """
      defmodule MyApp.Theme do
        use Cinder.Theme

        component Cinder.Components.Table do
          set :container_class,
              "very-long-class-name that-spans multiple-lines"
        end
      end
      """

      result = Upgrade.transform_component_blocks(input)

      assert result =~ "# Table"
      assert result =~ ~s(set :container_class)
      assert result =~ "very-long-class-name"
      refute result =~ "component Cinder.Components.Table do"
    end

    test "handles component with comments inside" do
      input = """
      defmodule MyApp.Theme do
        use Cinder.Theme

        component Cinder.Components.Filters do
          # Boolean filter
          set :filter_boolean_container_class, "flex space-x-6"
          set :filter_boolean_option_class, "flex items-center"

          # Checkbox filter
          set :filter_checkbox_container_class, "flex items-center"
        end
      end
      """

      result = Upgrade.transform_component_blocks(input)

      assert result =~ "# Filters"
      assert result =~ ~s(set :filter_boolean_container_class)
      assert result =~ ~s(set :filter_checkbox_container_class)
      refute result =~ "component Cinder.Components.Filters do"
    end

    test "returns unchanged if no component blocks" do
      input = """
      defmodule MyApp.Theme do
        use Cinder.Theme
        extends :modern

        set :container_class, "already-flat"
        set :row_class, "already-flat-row"
      end
      """

      result = Upgrade.transform_component_blocks(input)
      assert result == input
    end

    test "handles empty component block" do
      input = """
      defmodule MyApp.Theme do
        use Cinder.Theme

        component Cinder.Components.Table do
        end
      end
      """

      result = Upgrade.transform_component_blocks(input)

      assert result =~ "# Table"
      refute result =~ "component Cinder.Components.Table do"
    end
  end

  describe "module_to_comment/1" do
    test "extracts last part of alias" do
      ast = {:__aliases__, [], [:Cinder, :Components, :Table]}
      assert Upgrade.module_to_comment(ast) == "Table"
    end

    test "handles single alias" do
      ast = {:__aliases__, [], [:MyComponent]}
      assert Upgrade.module_to_comment(ast) == "MyComponent"
    end

    test "handles atom module" do
      assert Upgrade.module_to_comment(Cinder.Components.Filters) == "Filters"
    end

    test "returns Component for unknown" do
      assert Upgrade.module_to_comment("not an ast") == "Component"
    end
  end

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
        |> Upgrade.rename_boolean_theme_keys(%{})

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
        |> Upgrade.rename_boolean_theme_keys(%{})

      assert result.warnings == []
      assert result.issues == []
    end
  end
end
