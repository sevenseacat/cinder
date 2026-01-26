defmodule Mix.Tasks.Cinder.Migrate.ThemeTest do
  use ExUnit.Case, async: true

  alias Mix.Tasks.Cinder.Migrate.Theme

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

      result = Theme.transform_component_blocks(input)

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

      result = Theme.transform_component_blocks(input)

      # Should have both Table and Filters comments
      assert result =~ "# Table"
      assert result =~ "# Filters"

      # Should have all the set calls
      assert result =~ ~s(set :container_class, "table-container")
      assert result =~ ~s(set :row_class, "table-row")
      assert result =~ ~s(set :filter_container_class, "filter-container")

      # Should NOT have component blocks
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

      result = Theme.transform_component_blocks(input)

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

      result = Theme.transform_component_blocks(input)

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

      result = Theme.transform_component_blocks(input)

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

      result = Theme.transform_component_blocks(input)
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

      result = Theme.transform_component_blocks(input)

      assert result =~ "# Table"
      refute result =~ "component Cinder.Components.Table do"
    end
  end

  describe "module_to_comment/1" do
    test "extracts last part of alias" do
      ast = {:__aliases__, [], [:Cinder, :Components, :Table]}
      assert Theme.module_to_comment(ast) == "Table"
    end

    test "handles single alias" do
      ast = {:__aliases__, [], [:MyComponent]}
      assert Theme.module_to_comment(ast) == "MyComponent"
    end

    test "handles atom module" do
      assert Theme.module_to_comment(Cinder.Components.Filters) == "Filters"
    end

    test "returns Component for unknown" do
      assert Theme.module_to_comment("not an ast") == "Component"
    end
  end
end
