defmodule Cinder.ThemeTest do
  use ExUnit.Case, async: true

  alias Cinder.Theme

  describe "default/0" do
    test "returns default theme configuration" do
      theme = Theme.default()

      assert is_map(theme)
      assert theme.container_class == "cinder-table-container"
      assert theme.table_class == "cinder-table w-full border-collapse"
      assert theme.th_class == "cinder-table-th px-4 py-2 text-left font-medium border-b"

      # Verify all required theme keys are present
      required_keys = [
        :container_class,
        :controls_class,
        :table_wrapper_class,
        :table_class,
        :thead_class,
        :tbody_class,
        :header_row_class,
        :row_class,
        :th_class,
        :td_class,
        :sort_indicator_class,
        :loading_class,
        :empty_class,
        :pagination_wrapper_class,
        :pagination_container_class,
        :pagination_button_class,
        :pagination_info_class,
        :pagination_count_class,
        :sort_arrow_wrapper_class,
        :sort_asc_icon_name,
        :sort_asc_icon_class,
        :sort_desc_icon_name,
        :sort_desc_icon_class,
        :sort_none_icon_name,
        :sort_none_icon_class,
        :filter_container_class,
        :filter_header_class,
        :filter_title_class,
        :filter_count_class,
        :filter_clear_all_class,
        :filter_inputs_class,
        :filter_input_wrapper_class,
        :filter_label_class,
        :filter_placeholder_class,
        :filter_text_input_class,
        :filter_date_input_class,
        :filter_number_input_class,
        :filter_select_input_class,
        :filter_clear_button_class,
        # Boolean filter styling
        :filter_boolean_container_class,
        :filter_boolean_option_class,
        :filter_boolean_radio_class,
        :filter_boolean_label_class,
        # Multi-select filter styling
        :filter_multiselect_container_class,
        :filter_multiselect_option_class,
        :filter_multiselect_checkbox_class,
        :filter_multiselect_label_class,
        # Range filter styling
        :filter_range_container_class,
        :filter_range_input_group_class,
        # Loading indicator styling
        :loading_overlay_class,
        :loading_container_class,
        :loading_spinner_class,
        :loading_spinner_circle_class,
        :loading_spinner_path_class,
        # Error message styling
        :error_container_class,
        :error_message_class
      ]

      for key <- required_keys do
        assert Map.has_key?(theme, key), "Missing theme key: #{key}"

        assert is_binary(theme[key]),
               "Theme key #{key} should be a string, got: #{inspect(theme[key])}"
      end
    end

    test "returns consistent theme across calls" do
      theme1 = Theme.default()
      theme2 = Theme.default()

      assert theme1 == theme2
    end
  end

  describe "modern/0" do
    test "returns modern theme based on default" do
      modern_theme = Theme.modern()
      default_theme = Theme.default()

      # Should have all the same keys as default
      assert Map.keys(modern_theme) == Map.keys(default_theme)

      # Should override specific styling
      assert modern_theme.container_class ==
               "cinder-table-container bg-white shadow-sm rounded-lg"

      assert modern_theme.th_class ==
               "cinder-table-th px-6 py-4 text-left font-semibold text-gray-900 bg-gray-50 border-b border-gray-200"

      assert modern_theme.td_class == "cinder-table-td px-6 py-4 text-gray-900"

      # Should keep default values for non-overridden keys
      assert modern_theme.sort_asc_icon_name == default_theme.sort_asc_icon_name
      assert modern_theme.loading_class == default_theme.loading_class
    end
  end

  describe "minimal/0" do
    test "returns minimal theme based on default" do
      minimal_theme = Theme.minimal()
      default_theme = Theme.default()

      # Should have all the same keys as default
      assert Map.keys(minimal_theme) == Map.keys(default_theme)

      # Should override specific styling with minimal classes
      assert minimal_theme.container_class == "cinder-table-container"
      assert minimal_theme.th_class == "cinder-table-th px-2 py-1 text-left font-medium"
      assert minimal_theme.td_class == "cinder-table-td px-2 py-1"
      assert minimal_theme.controls_class == "cinder-table-controls mb-2"

      # Should keep default values for non-overridden keys
      assert minimal_theme.sort_asc_icon_name == default_theme.sort_asc_icon_name
      assert minimal_theme.loading_class == default_theme.loading_class
    end
  end

  describe "merge/1" do
    test "merges custom map with default theme" do
      custom_theme = %{
        container_class: "my-custom-container",
        table_class: "my-custom-table"
      }

      merged = Theme.merge(custom_theme)
      default = Theme.default()

      # Should override specified keys
      assert merged.container_class == "my-custom-container"
      assert merged.table_class == "my-custom-table"

      # Should keep default values for non-overridden keys
      assert merged.th_class == default.th_class
      assert merged.td_class == default.td_class
      assert merged.sort_asc_icon_name == default.sort_asc_icon_name
    end

    test "handles empty map" do
      merged = Theme.merge(%{})
      default = Theme.default()

      assert merged == default
    end

    test "handles nil input" do
      merged = Theme.merge(nil)
      default = Theme.default()

      assert merged == default
    end

    test "handles string preset names" do
      assert Theme.merge("default") == Theme.default()
      assert Theme.merge("modern") == Theme.modern()
      assert Theme.merge("minimal") == Theme.minimal()
    end

    test "raises error for unknown preset name" do
      assert_raise ArgumentError, ~r/Unknown theme preset: unknown/, fn ->
        Theme.merge("unknown")
      end
    end

    test "raises error for invalid input type" do
      assert_raise ArgumentError, ~r/Theme must be a map or string/, fn ->
        Theme.merge(123)
      end

      assert_raise ArgumentError, ~r/Theme must be a map or string/, fn ->
        Theme.merge([:not, :a, :map])
      end
    end
  end

  describe "presets/0" do
    test "returns list of available presets" do
      presets = Theme.presets()

      assert is_list(presets)
      assert "default" in presets
      assert "modern" in presets
      assert "minimal" in presets
      assert length(presets) == 3
    end

    test "all presets can be loaded" do
      for preset <- Theme.presets() do
        theme = Theme.merge(preset)
        assert is_map(theme)
        assert Map.has_key?(theme, :container_class)
      end
    end
  end

  describe "theme consistency" do
    test "all themes have same structure" do
      default_keys = Theme.default() |> Map.keys() |> Enum.sort()
      modern_keys = Theme.modern() |> Map.keys() |> Enum.sort()
      minimal_keys = Theme.minimal() |> Map.keys() |> Enum.sort()

      assert default_keys == modern_keys
      assert default_keys == minimal_keys
    end

    test "all theme values are strings" do
      themes = [Theme.default(), Theme.modern(), Theme.minimal()]

      for theme <- themes do
        for {key, value} <- theme do
          assert is_binary(value), "Theme key #{key} should be a string, got: #{inspect(value)}"
        end
      end
    end
  end

  describe "integration with component" do
    test "theme can be used in component assigns" do
      # Simulate how the component would use the theme
      theme = Theme.merge(%{container_class: "custom-container"})

      # Should be able to access all required theme properties
      assert theme.container_class == "custom-container"
      assert is_binary(theme.table_class)
      assert is_binary(theme.th_class)
      assert is_binary(theme.pagination_button_class)
      assert is_binary(theme.filter_container_class)
    end

    test "theme works with string preset in component context" do
      # Simulate passing preset name as theme
      modern_theme = Theme.merge("modern")

      # Should resolve to full theme map
      assert is_map(modern_theme)
      assert String.contains?(modern_theme.container_class, "shadow-sm")
    end

    test "component assigns defaults work with new theme module" do
      # Test that the component's assign_defaults function works with our theme module
      # This simulates what happens in the actual component
      theme_input = %{container_class: "my-custom-container"}
      resolved_theme = Theme.merge(theme_input)

      # Verify the merge worked correctly
      assert resolved_theme.container_class == "my-custom-container"
      # Should still have all default theme keys
      assert Map.has_key?(resolved_theme, :table_class)
      assert Map.has_key?(resolved_theme, :th_class)
      assert Map.has_key?(resolved_theme, :pagination_button_class)
    end

    test "theme presets work with component integration" do
      # Test each preset can be used by component
      for preset <- Theme.presets() do
        theme = Theme.merge(preset)

        # Should be a complete theme map
        assert is_map(theme)
        assert Map.has_key?(theme, :container_class)
        assert Map.has_key?(theme, :table_class)
        assert Map.has_key?(theme, :th_class)

        # All values should be strings (CSS classes)
        for {_key, value} <- theme do
          assert is_binary(value)
        end
      end
    end
  end
end
