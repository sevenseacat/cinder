defmodule Cinder.ThemeDslTest do
  use ExUnit.Case, async: true

  alias Cinder.Theme

  # Test theme modules for testing
  defmodule SimpleTestTheme do
    use Cinder.Theme

    # Table
    set :container_class, "custom-table-container"
    set :row_class, "custom-row"

    # Filters
    set :filter_container_class, "custom-filter-container"
    set :filter_text_input_class, "custom-text-input"
  end

  defmodule InheritanceTestTheme do
    use Cinder.Theme
    extends(:modern)

    # Table
    set :container_class, "inherited-table-container"
  end

  defmodule InvalidComponentTheme do
    use Cinder.Theme

    set :some_class, "some-value"
  end

  defmodule InvalidPropertyTheme do
    use Cinder.Theme

    set :invalid_property, "some-value"
  end

  defmodule BaseCustomTheme do
    use Cinder.Theme

    # Table
    set :container_class, "base-custom-container"
    set :row_class, "base-custom-row"

    # Filters
    set :filter_container_class, "base-custom-filter-container"
  end

  defmodule ExtendingCustomTheme do
    use Cinder.Theme
    extends(BaseCustomTheme)

    # Table
    set :container_class, "extending-custom-container"
  end

  describe "DSL theme resolution" do
    test "resolves simple theme with overrides" do
      theme = SimpleTestTheme.resolve_theme()

      assert is_map(theme)
      assert theme.container_class == "custom-table-container"
      assert theme.row_class == "custom-row"
      assert theme.filter_container_class == "custom-filter-container"
      assert theme.filter_text_input_class == "custom-text-input"

      # Should still have default values for non-overridden properties
      assert String.contains?(theme.table_class, "w-full border-collapse")
      assert is_binary(theme.th_class)
    end

    test "can be used with Theme.merge/1" do
      theme = Theme.merge(SimpleTestTheme)

      assert is_map(theme)
      assert theme.container_class == "custom-table-container"
      assert theme.row_class == "custom-row"
    end

    test "inheritance works with built-in themes" do
      theme = InheritanceTestTheme.resolve_theme()

      # Should have the inherited container class
      assert theme.container_class == "inherited-table-container"

      # Should inherit other modern theme properties
      assert String.contains?(theme.th_class, "font-semibold")
      assert String.contains?(theme.pagination_button_class, "transition-all")
    end

    test "inheritance works with custom themes" do
      theme = ExtendingCustomTheme.resolve_theme()

      # Should override the base custom theme's container class
      assert theme.container_class == "extending-custom-container"

      # Should inherit other properties from base custom theme
      assert theme.row_class == "base-custom-row"
      assert theme.filter_container_class == "base-custom-filter-container"

      # Should still have default values for non-overridden properties
      assert String.contains?(theme.table_class, "w-full border-collapse")
    end

    test "raises helpful error when extending unavailable custom theme" do
      assert_raise ArgumentError, ~r/Module .*NonExistentCustomTheme not found/, fn ->
        defmodule InvalidExtendingTheme do
          use Cinder.Theme
          extends(NonExistentCustomTheme)

          set :container_class, "invalid-extending-container"
        end
      end
    end

    test "raises helpful error when extending module that doesn't implement theme behavior" do
      assert_raise ArgumentError, ~r/does not implement resolve_theme\/0/, fn ->
        defmodule NotAThemeModule do
          def some_function, do: :ok
        end

        defmodule ThemeExtendingNonTheme do
          use Cinder.Theme
          extends(NotAThemeModule)

          set :container_class, "invalid-extending-container"
        end
      end
    end

    test "maintains all required theme keys" do
      theme = SimpleTestTheme.resolve_theme()
      default_theme = Theme.default()

      # Should have all the same keys as default theme
      default_keys = Map.keys(default_theme) |> Enum.sort()
      theme_keys = Map.keys(theme) |> Enum.sort()

      assert default_keys == theme_keys
    end
  end

  describe "DSL compilation" do
    test "generates correct theme configuration function" do
      # Test that the theme module has the expected function
      assert function_exported?(SimpleTestTheme, :__theme_config, 0)

      theme = SimpleTestTheme.__theme_config()
      assert is_map(theme)
      assert theme.container_class == "custom-table-container"
    end

    test "handles base theme inheritance correctly" do
      theme = InheritanceTestTheme.resolve_theme()

      # Should have the inherited container class
      assert theme.container_class == "inherited-table-container"

      # Should inherit other modern theme properties
      assert String.contains?(theme.th_class, "font-semibold")
    end

    test "handles themes without base theme" do
      theme = SimpleTestTheme.resolve_theme()

      # Should start with default theme as base
      assert String.contains?(theme.table_class, "w-full border-collapse")
      # But should override specific properties
      assert theme.container_class == "custom-table-container"
    end
  end

  describe "theme validation" do
    test "validates valid theme modules" do
      assert Theme.validate(SimpleTestTheme) == :ok
    end

    test "validates theme modules that compile successfully" do
      assert Theme.validate(InheritanceTestTheme) == :ok
    end

    test "validates non-theme modules" do
      {:error, reason} = Theme.validate(String)
      assert String.contains?(reason, "does not implement resolve_theme/0")
    end

    test "handles validation errors gracefully" do
      # Test with a module that doesn't exist
      {:error, reason} = Theme.validate(NonExistentModule)
      assert String.contains?(reason, "does not implement resolve_theme/0")
    end
  end

  describe "theme property validation" do
    test "valid_property? accepts known properties" do
      assert Theme.valid_property?(:container_class) == true
      assert Theme.valid_property?(:filter_text_input_class) == true
    end

    test "valid_property? rejects unknown properties" do
      assert Theme.valid_property?(:invalid_property) == false
      assert Theme.valid_property?("string_key") == false
      assert Theme.valid_property?(123) == false
    end
  end

  describe "backwards compatibility" do
    test "string presets still work" do
      modern_theme = Theme.merge("modern")
      assert String.contains?(modern_theme.container_class, "shadow-lg")

      retro_theme = Theme.merge("retro")
      assert String.contains?(retro_theme.container_class, "bg-gray-900")
    end

    test "validation works for all theme types" do
      assert Theme.validate("modern") == :ok
      assert Theme.validate(SimpleTestTheme) == :ok

      {:error, _} = Theme.validate("invalid_preset")
      {:error, _} = Theme.validate(123)
    end
  end

  describe "theme application" do
    test "DSL theme overrides work correctly" do
      # Start with default
      default_theme = Theme.default()

      # Apply DSL theme
      dsl_theme = Theme.merge(SimpleTestTheme)

      # Should override specific values
      assert dsl_theme.container_class != default_theme.container_class
      assert dsl_theme.container_class == "custom-table-container"

      # Should preserve non-overridden values
      assert dsl_theme.table_class == default_theme.table_class
      assert dsl_theme.th_class == default_theme.th_class
    end

    test "inheritance preserves overrides" do
      base_theme = Theme.merge("modern")
      inherited_theme = Theme.merge(InheritanceTestTheme)

      # Should override from base
      assert inherited_theme.container_class != base_theme.container_class
      assert inherited_theme.container_class == "inherited-table-container"

      # Should preserve base theme for non-overridden
      assert inherited_theme.th_class == base_theme.th_class
      assert inherited_theme.pagination_button_class == base_theme.pagination_button_class
    end
  end

  describe "error handling" do
    test "handles malformed theme modules gracefully" do
      assert_raise ArgumentError, ~r/does not implement resolve_theme\/0/, fn ->
        Theme.merge(NonExistentTheme)
      end
    end

    test "provides helpful error for invalid theme resolution" do
      # Test with a module that exists but doesn't have the DSL
      defmodule BadTheme do
        def some_function, do: :ok
      end

      {:error, reason} = Theme.validate(BadTheme)
      assert String.contains?(reason, "does not implement resolve_theme/0")
    end
  end
end
