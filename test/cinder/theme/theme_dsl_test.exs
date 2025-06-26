defmodule Cinder.ThemeDslTest do
  use ExUnit.Case, async: true

  alias Cinder.Theme
  alias Cinder.Theme

  # Test theme modules for testing
  defmodule SimpleTestTheme do
    use Cinder.Theme

    component Cinder.Components.Table do
      set(:container_class, "custom-table-container")
      set(:row_class, "custom-row")
    end

    component Cinder.Components.Filters do
      set(:filter_container_class, "custom-filter-container")
      set(:filter_text_input_class, "custom-text-input")
    end
  end

  defmodule InheritanceTestTheme do
    use Cinder.Theme
    extends(:modern)

    component Cinder.Components.Table do
      set(:container_class, "inherited-table-container")
    end
  end

  defmodule InvalidComponentTheme do
    use Cinder.Theme

    component InvalidComponent do
      set(:some_class, "some-value")
    end
  end

  defmodule InvalidPropertyTheme do
    use Cinder.Theme

    component Cinder.Components.Table do
      set(:invalid_property, "some-value")
    end
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

  describe "component theme properties" do
    test "table component has expected properties" do
      properties = Cinder.Components.Table.theme_properties()

      assert :container_class in properties
      assert :table_class in properties
      assert :row_class in properties
      assert :th_class in properties
      assert :td_class in properties
    end

    test "filters component has expected properties" do
      properties = Cinder.Components.Filters.theme_properties()

      assert :filter_container_class in properties
      assert :filter_text_input_class in properties
      assert :filter_boolean_container_class in properties
      assert :filter_multiselect_dropdown_class in properties
    end

    test "component validation works" do
      assert Cinder.Components.Table.valid_property?(:container_class) == true
      assert Cinder.Components.Table.valid_property?(:invalid_property) == false
      assert Cinder.Components.Table.valid_property?("string_key") == false
    end
  end

  describe "theme property completeness" do
    test "complete_default includes all component defaults" do
      complete_theme = Theme.complete_default()

      # Should include properties from all components
      # Table
      assert Map.has_key?(complete_theme, :container_class)
      # Filters
      assert Map.has_key?(complete_theme, :filter_container_class)
      # Pagination
      assert Map.has_key?(complete_theme, :pagination_wrapper_class)
      # Sorting
      assert Map.has_key?(complete_theme, :sort_indicator_class)
      # Loading
      assert Map.has_key?(complete_theme, :loading_overlay_class)
    end

    test "all_theme_properties returns comprehensive list" do
      all_properties = Theme.all_theme_properties()

      assert is_list(all_properties)
      assert :container_class in all_properties
      assert :filter_text_input_class in all_properties
      assert :pagination_button_class in all_properties
      assert :sort_asc_icon_class in all_properties
      assert :loading_spinner_class in all_properties

      # Should be sorted and unique
      assert all_properties == Enum.sort(all_properties)
      assert all_properties == Enum.uniq(all_properties)
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
