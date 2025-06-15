defmodule Cinder.SortIconAlignmentTest do
  use ExUnit.Case, async: true

  describe "Sort Icon Alignment" do
    test "all themes use consistent sort icon alignment classes" do
      themes = [
        "default",
        "modern",
        "dark",
        "compact",
        "daisy_ui",
        "flowbite",
        "futuristic",
        "pastel",
        "retro"
      ]

      for theme_name <- themes do
        theme = Cinder.Theme.merge(theme_name)

        # All themes should have proper alignment classes
        assert theme.sort_indicator_class =~ "inline-flex",
               "#{theme_name} sort_indicator_class missing inline-flex"

        assert theme.sort_indicator_class =~ "items-center",
               "#{theme_name} sort_indicator_class missing items-center"

        assert theme.sort_indicator_class =~ "align-baseline",
               "#{theme_name} sort_indicator_class missing align-baseline for proper text alignment"

        # Arrow wrapper should be simple flex container
        assert theme.sort_arrow_wrapper_class =~ "inline-flex",
               "#{theme_name} sort_arrow_wrapper_class missing inline-flex"

        assert theme.sort_arrow_wrapper_class =~ "items-center",
               "#{theme_name} sort_arrow_wrapper_class missing items-center"

        # Icons should be consistently sized (w-3 h-3 for better proportion)
        assert theme.sort_asc_icon_class =~ "w-3",
               "#{theme_name} sort_asc_icon_class should use w-3 for consistent sizing"

        assert theme.sort_asc_icon_class =~ "h-3",
               "#{theme_name} sort_asc_icon_class should use h-3 for consistent sizing"

        assert theme.sort_desc_icon_class =~ "w-3",
               "#{theme_name} sort_desc_icon_class should use w-3 for consistent sizing"

        assert theme.sort_desc_icon_class =~ "h-3",
               "#{theme_name} sort_desc_icon_class should use h-3 for consistent sizing"

        assert theme.sort_none_icon_class =~ "w-3",
               "#{theme_name} sort_none_icon_class should use w-3 for consistent sizing"

        assert theme.sort_none_icon_class =~ "h-3",
               "#{theme_name} sort_none_icon_class should use h-3 for consistent sizing"
      end
    end

    test "sort indicator spacing is consistent across themes" do
      themes = [
        "default",
        "modern",
        "dark",
        "compact",
        "daisy_ui",
        "flowbite",
        "futuristic",
        "pastel",
        "retro"
      ]

      for theme_name <- themes do
        theme = Cinder.Theme.merge(theme_name)

        # All themes should use ml-1 for consistent left margin
        assert theme.sort_indicator_class =~ "ml-1",
               "#{theme_name} sort_indicator_class should use ml-1 for consistent spacing"

        # Arrow wrapper should not add extra margin (handled by indicator)
        refute theme.sort_arrow_wrapper_class =~ "ml-",
               "#{theme_name} sort_arrow_wrapper_class should not add margin"
      end
    end

    test "sort icons maintain theme-specific colors" do
      # Test that each theme has appropriate colors while maintaining alignment

      # Modern theme - blue
      modern = Cinder.Theme.merge("modern")
      assert modern.sort_asc_icon_class =~ "text-blue-600"
      assert modern.sort_desc_icon_class =~ "text-blue-600"

      # Dark theme - purple
      dark = Cinder.Theme.merge("dark")
      assert dark.sort_asc_icon_class =~ "text-purple-400"
      assert dark.sort_desc_icon_class =~ "text-purple-400"

      # Pastel theme - purple/pink
      pastel = Cinder.Theme.merge("pastel")
      assert pastel.sort_asc_icon_class =~ "text-purple-500"
      assert pastel.sort_desc_icon_class =~ "text-pink-500"

      # Retro theme - cyan/magenta
      retro = Cinder.Theme.merge("retro")
      assert retro.sort_asc_icon_class =~ "text-cyan-400"
      assert retro.sort_desc_icon_class =~ "text-magenta-400"

      # Futuristic theme - green/blue with effects
      futuristic = Cinder.Theme.merge("futuristic")
      assert futuristic.sort_asc_icon_class =~ "text-green-400"
      assert futuristic.sort_asc_icon_class =~ "drop-shadow"
      assert futuristic.sort_desc_icon_class =~ "text-blue-400"
      assert futuristic.sort_desc_icon_class =~ "drop-shadow"
    end

    test "default theme provides basic alignment" do
      default_theme = Cinder.Components.Sorting.default_theme()

      # Should have all necessary alignment classes
      assert default_theme.sort_indicator_class == "ml-1 inline-flex items-center align-baseline"
      assert default_theme.sort_arrow_wrapper_class == "inline-flex items-center"

      # Should have consistent icon sizing
      assert default_theme.sort_asc_icon_class == "w-3 h-3"
      assert default_theme.sort_desc_icon_class == "w-3 h-3"
      assert default_theme.sort_none_icon_class == "w-3 h-3 opacity-50"
    end

    test "no themes reference vintage theme" do
      # Ensure vintage theme is completely removed
      themes = Cinder.Theme.presets()
      refute "vintage" in themes, "Vintage theme should be completely removed"

      # Test that we can't merge vintage theme
      assert_raise ArgumentError, ~r/Unknown theme preset: vintage/, fn ->
        Cinder.Theme.merge("vintage")
      end
    end

    test "sort icons render with improved alignment" do
      # Test the sort_arrow component structure
      theme = Cinder.Theme.merge("modern")

      # We can't easily test the actual rendering without a full LiveView setup,
      # but we can verify the theme properties that will be used
      assert theme.sort_indicator_class =~ "align-baseline"
      assert theme.sort_arrow_wrapper_class == "inline-flex items-center"

      # Icons should be smaller and better proportioned
      assert theme.sort_asc_icon_class =~ "w-3 h-3"
      assert theme.sort_desc_icon_class =~ "w-3 h-3"
      assert theme.sort_none_icon_class =~ "w-3 h-3"
    end
  end

  describe "Theme Consistency" do
    test "all sorting components follow same structural pattern" do
      themes = [
        "modern",
        "dark",
        "compact",
        "daisy_ui",
        "flowbite",
        "futuristic",
        "pastel",
        "retro"
      ]

      for theme_name <- themes do
        theme = Cinder.Theme.merge(theme_name)

        # Structural consistency checks
        assert String.contains?(
                 theme.sort_indicator_class,
                 "inline-flex items-center align-baseline"
               ),
               "#{theme_name} should follow standard alignment pattern"

        assert theme.sort_arrow_wrapper_class == "inline-flex items-center",
               "#{theme_name} should use standard arrow wrapper"

        # Size consistency
        icon_classes = [
          theme.sort_asc_icon_class,
          theme.sort_desc_icon_class,
          theme.sort_none_icon_class
        ]

        for icon_class <- icon_classes do
          assert String.contains?(icon_class, "w-3 h-3"),
                 "#{theme_name} icons should use consistent w-3 h-3 sizing"
        end
      end
    end

    test "compact theme uses appropriate sizing" do
      # Compact theme should still maintain readability while being smaller
      compact = Cinder.Theme.merge("compact")

      # Should use same icon size as other themes for consistency
      assert compact.sort_asc_icon_class =~ "w-3 h-3"
      assert compact.sort_desc_icon_class =~ "w-3 h-3"
      assert compact.sort_none_icon_class =~ "w-3 h-3"

      # Should have same alignment improvements
      assert compact.sort_indicator_class =~ "align-baseline"
    end
  end
end
