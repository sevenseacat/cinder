defmodule Cinder.ThemeTest do
  use ExUnit.Case, async: true

  alias Cinder.Theme

  describe "default/0" do
    test "returns default theme configuration" do
      theme = Theme.default()

      assert is_map(theme)
      assert theme.container_class == ""
      assert theme.table_class == "w-full border-collapse"
      assert theme.th_class == "text-left whitespace-nowrap"

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
        # Radio group filter styling
        :filter_radio_group_container_class,
        :filter_radio_group_option_class,
        :filter_radio_group_radio_class,
        :filter_radio_group_label_class,
        # Checkbox filter styling
        :filter_checkbox_container_class,
        :filter_checkbox_input_class,
        :filter_checkbox_label_class,
        # Multi-select filter styling (dropdown interface)
        :filter_multiselect_container_class,
        :filter_multiselect_dropdown_class,
        :filter_multiselect_option_class,
        :filter_multiselect_checkbox_class,
        :filter_multiselect_label_class,
        :filter_multiselect_empty_class,
        # Multi-checkboxes filter styling
        :filter_multicheckboxes_container_class,
        :filter_multicheckboxes_option_class,
        :filter_multicheckboxes_checkbox_class,
        :filter_multicheckboxes_label_class,
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

  describe "merge/1" do
    test "handles nil input" do
      merged = Theme.merge(nil)
      default = Theme.default()

      # Should be identical since both have data attributes now
      assert merged == default
    end

    test "handles string preset names" do
      default_merged = Theme.merge("default")
      default_plain = Theme.default()

      # Should be identical since both have data attributes now
      assert default_merged == default_plain

      # Just test that string presets work
      modern_theme = Theme.merge("modern")
      assert is_map(modern_theme)
    end

    test "handles theme modules" do
      # Test with a built-in theme module
      modern_theme1 = Theme.merge("modern")
      modern_theme2 = Theme.merge(Cinder.Themes.Modern)

      assert modern_theme1 == modern_theme2
    end

    test "raises error for unknown preset name" do
      assert_raise ArgumentError, ~r/Unknown theme preset: unknown/, fn ->
        Theme.merge("unknown")
      end
    end

    test "raises error for invalid input type" do
      assert_raise ArgumentError, ~r/Theme must be a map, string, or theme module/, fn ->
        Theme.merge(123)
      end

      assert_raise ArgumentError, ~r/Theme must be a map, string, or theme module/, fn ->
        Theme.merge([:not, :a, :map])
      end
    end
  end

  describe "get_default_theme/0" do
    test "returns 'default' when no configuration is set" do
      # Ensure no config is set
      Application.delete_env(:cinder, :default_theme)

      assert Theme.get_default_theme() == "default"
    end

    test "returns configured theme when set" do
      Application.put_env(:cinder, :default_theme, "modern")

      assert Theme.get_default_theme() == "modern"

      # Cleanup
      Application.delete_env(:cinder, :default_theme)
    end

    test "returns configured theme module when set" do
      Application.put_env(:cinder, :default_theme, Cinder.Themes.Dark)

      assert Theme.get_default_theme() == Cinder.Themes.Dark

      # Cleanup
      Application.delete_env(:cinder, :default_theme)
    end

    test "handles various theme configurations" do
      theme_configs = [
        "modern",
        "dark",
        "retro",
        Cinder.Themes.Modern,
        Cinder.Themes.Dark
      ]

      for config <- theme_configs do
        Application.put_env(:cinder, :default_theme, config)
        assert Theme.get_default_theme() == config
      end

      # Cleanup
      Application.delete_env(:cinder, :default_theme)
    end
  end

  describe "presets/0" do
    test "returns list of available presets" do
      presets = Theme.presets()

      assert is_list(presets)
      assert "default" in presets
      assert "modern" in presets
      assert "retro" in presets
      assert "futuristic" in presets
      assert "dark" in presets
      assert "daisy_ui" in presets
      assert "flowbite" in presets

      assert "compact" in presets
      assert length(presets) == 8
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
      modern_keys = Theme.merge("modern") |> Map.keys() |> Enum.sort()
      retro_keys = Theme.merge("retro") |> Map.keys() |> Enum.sort()

      # All themes should have the same keys
      assert default_keys == modern_keys
      assert default_keys == retro_keys
    end

    test "all theme class values are strings and data values are maps" do
      themes = [Theme.default(), Theme.merge("modern"), Theme.merge("retro")]

      for theme <- themes do
        for {key, value} <- theme do
          key_str = to_string(key)

          cond do
            String.ends_with?(key_str, "_class") ->
              assert is_binary(value),
                     "Theme class key #{key} should be a string, got: #{inspect(value)}"

            String.ends_with?(key_str, "_name") ->
              assert is_binary(value),
                     "Theme icon name key #{key} should be a string, got: #{inspect(value)}"

            true ->
              # For any other keys (like pagination_wrapper_class that might not end in _class)
              assert is_binary(value),
                     "Theme key #{key} should be a string, got: #{inspect(value)}"
          end
        end
      end
    end
  end

  describe "integration with component" do
    test "theme can be used in component assigns" do
      # Simulate how the component would use the theme
      theme = Theme.merge("modern")

      # Should be able to access all required theme properties
      assert is_binary(theme.container_class)
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
      assert String.contains?(modern_theme.container_class, "shadow-lg")
    end

    test "component assigns defaults work with new theme module" do
      # Test that the component's assign_defaults function works with our theme module
      # This simulates what happens in the actual component
      resolved_theme = Theme.merge("modern")

      # Verify the merge worked correctly
      assert is_binary(resolved_theme.container_class)
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

        # Class values should be strings
        for {key, value} <- theme do
          key_str = to_string(key)

          cond do
            String.ends_with?(key_str, "_class") ->
              assert is_binary(value),
                     "Theme class key #{key} should be a string, got: #{inspect(value)}"

            String.ends_with?(key_str, "_name") ->
              assert is_binary(value),
                     "Theme icon name key #{key} should be a string, got: #{inspect(value)}"

            true ->
              # For any other keys
              assert is_binary(value),
                     "Theme key #{key} should be a string, got: #{inspect(value)}"
          end
        end
      end
    end
  end
end
