defmodule Cinder.ThemeVerificationTest do
  use ExUnit.Case, async: true

  @themes [
    Cinder.Themes.Modern,
    Cinder.Themes.Compact,
    Cinder.Themes.DaisyUI,
    Cinder.Themes.Dark,
    Cinder.Themes.Flowbite,
    Cinder.Themes.Futuristic,
    Cinder.Themes.Retro
  ]

  @required_multiselect_properties [
    :filter_multiselect_container_class,
    :filter_multiselect_dropdown_class,
    :filter_multiselect_option_class,
    :filter_multiselect_checkbox_class,
    :filter_multiselect_label_class,
    :filter_multiselect_empty_class
  ]

  @required_boolean_properties [
    :filter_boolean_container_class,
    :filter_boolean_option_class,
    :filter_boolean_radio_class,
    :filter_boolean_label_class
  ]

  @required_pagination_properties [
    :pagination_wrapper_class,
    :pagination_container_class,
    :pagination_button_class,
    :pagination_info_class,
    :pagination_count_class,
    :pagination_nav_class,
    :pagination_current_class
  ]

  describe "theme multi-select properties" do
    for theme_module <- @themes do
      test "#{theme_module} has all required multi-select dropdown properties" do
        theme = unquote(theme_module).resolve_theme()

        for property <- @required_multiselect_properties do
          assert Map.has_key?(theme, property),
                 "#{unquote(theme_module)} missing multi-select property: #{property}"

          assert is_binary(theme[property]),
                 "#{unquote(theme_module)} property #{property} should be string, got: #{inspect(theme[property])}"
        end
      end
    end
  end

  describe "theme boolean filter properties" do
    for theme_module <- @themes do
      test "#{theme_module} has all required boolean filter properties" do
        theme = unquote(theme_module).resolve_theme()

        for property <- @required_boolean_properties do
          assert Map.has_key?(theme, property),
                 "#{unquote(theme_module)} missing boolean filter property: #{property}"

          assert is_binary(theme[property]),
                 "#{unquote(theme_module)} property #{property} should be string, got: #{inspect(theme[property])}"
        end
      end
    end
  end

  describe "theme pagination properties" do
    for theme_module <- @themes do
      test "#{theme_module} has all required pagination properties" do
        theme = unquote(theme_module).resolve_theme()

        for property <- @required_pagination_properties do
          assert Map.has_key?(theme, property),
                 "#{unquote(theme_module)} missing pagination property: #{property}"

          assert is_binary(theme[property]),
                 "#{unquote(theme_module)} property #{property} should be string, got: #{inspect(theme[property])}"
        end
      end
    end
  end

  describe "multi-select dropdown styling" do
    for theme_module <- @themes do
      test "#{theme_module} multi-select dropdown has proper positioning classes" do
        theme = unquote(theme_module).resolve_theme()

        # Container should be relative for dropdown positioning
        container_class = theme[:filter_multiselect_container_class]

        assert String.contains?(container_class, "relative"),
               "#{unquote(theme_module)} multi-select container should include 'relative' positioning"

        # Dropdown should be absolutely positioned
        dropdown_class = theme[:filter_multiselect_dropdown_class]

        assert String.contains?(dropdown_class, "absolute"),
               "#{unquote(theme_module)} multi-select dropdown should include 'absolute' positioning"

        # Dropdown should have z-index for layering
        assert String.contains?(dropdown_class, "z-"),
               "#{unquote(theme_module)} multi-select dropdown should include z-index class"

        # Dropdown should have max height for scrolling
        assert String.contains?(dropdown_class, "max-h-") or
                 String.contains?(dropdown_class, "max-height"),
               "#{unquote(theme_module)} multi-select dropdown should include max-height constraint"
      end
    end
  end

  describe "boolean filter height consistency" do
    for theme_module <- @themes do
      test "#{theme_module} boolean filter has consistent height with other inputs" do
        theme = unquote(theme_module).resolve_theme()

        boolean_container = theme[:filter_boolean_container_class]

        # Should have explicit height for consistency (h-10, h-12, h-[42px], etc.)
        assert Regex.match?(~r/\bh-(\d+|\[)/, boolean_container),
               "#{unquote(theme_module)} boolean filter container should have explicit height for alignment"

        # Should include items-center for vertical alignment
        assert String.contains?(boolean_container, "items-center"),
               "#{unquote(theme_module)} boolean filter container should center items vertically"
      end
    end
  end

  describe "pagination wrapper styling" do
    for theme_module <- @themes do
      test "#{theme_module} pagination wrapper is minimal and clean" do
        theme = unquote(theme_module).resolve_theme()

        pagination_wrapper = theme[:pagination_wrapper_class]

        # Should not have border classes (pagination shows conditionally now)
        refute String.contains?(pagination_wrapper, "border-2") or
                 String.contains?(pagination_wrapper, "border "),
               "#{unquote(theme_module)} pagination wrapper should not have borders (handled by conditional rendering)"

        # Should not have heavy background styling
        refute String.contains?(pagination_wrapper, "bg-gradient-to-"),
               "#{unquote(theme_module)} pagination wrapper should have minimal background styling"

        # Should have padding for spacing
        assert String.contains?(pagination_wrapper, "p-") or
                 String.contains?(pagination_wrapper, "padding"),
               "#{unquote(theme_module)} pagination wrapper should include padding for proper spacing"
      end
    end
  end

  describe "theme consistency verification" do
    test "all themes define the same set of filter properties" do
      theme_properties =
        @themes
        |> Enum.map(fn theme_module ->
          theme = theme_module.resolve_theme()

          filter_properties =
            theme
            |> Enum.filter(fn {key, _} -> String.starts_with?(to_string(key), "filter_") end)
            |> Enum.map(fn {key, _} -> key end)
            |> Enum.sort()

          {theme_module, filter_properties}
        end)

      # Get the first theme's properties as reference
      [{reference_theme, reference_properties} | other_themes] = theme_properties

      # Verify all other themes have the same filter properties
      for {theme_module, properties} <- other_themes do
        assert properties == reference_properties,
               """
               #{theme_module} has different filter properties than #{reference_theme}

               Missing in #{theme_module}: #{inspect(reference_properties -- properties)}
               Extra in #{theme_module}: #{inspect(properties -- reference_properties)}
               """
      end
    end
  end
end
