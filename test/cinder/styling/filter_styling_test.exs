defmodule Cinder.FilterStylingTest do
  use ExUnit.Case, async: true

  describe "Number Input Spinner Removal" do
    test "number input class includes spinner removal CSS for all themes" do
      themes = [
        "default",
        "modern",
        "dark",
        "compact",
        "daisy_ui",
        "flowbite",
        "futuristic",
        "retro"
      ]

      for theme_name <- themes do
        theme = Cinder.Theme.merge(theme_name)

        # Each theme should include spinner removal CSS
        assert theme.filter_number_input_class =~
                 "[&::-webkit-outer-spin-button]:appearance-none",
               "Theme #{theme_name} missing webkit outer spinner removal"

        assert theme.filter_number_input_class =~
                 "[&::-webkit-inner-spin-button]:appearance-none",
               "Theme #{theme_name} missing webkit inner spinner removal"

        assert theme.filter_number_input_class =~ "[-moz-appearance:textfield]",
               "Theme #{theme_name} missing firefox spinner removal"
      end
    end

    test "NumberRange filter renders with spinner removal CSS" do
      alias Cinder.Filters.NumberRange

      column = %{field: "value", filter_type: :number_range}
      current_value = %{min: "10", max: "100"}
      theme = Cinder.Theme.merge("modern")
      assigns = %{}

      html = NumberRange.render(column, current_value, theme, assigns)
      html_string = html |> Phoenix.HTML.Safe.to_iodata() |> IO.iodata_to_binary()

      # Should contain the spinner removal CSS classes
      assert html_string =~ "[&amp;::-webkit-outer-spin-button]:appearance-none"
      assert html_string =~ "[&amp;::-webkit-inner-spin-button]:appearance-none"
      assert html_string =~ "[-moz-appearance:textfield]"
    end
  end

  describe "Range Filter Separator Styling" do
    test "NumberRange filter renders styled separator" do
      alias Cinder.Filters.NumberRange

      column = %{field: "value", filter_type: :number_range}
      current_value = %{min: "10", max: "100"}
      theme = Cinder.Theme.merge("modern")
      assigns = %{}

      html = NumberRange.render(column, current_value, theme, assigns)
      html_string = html |> Phoenix.HTML.Safe.to_iodata() |> IO.iodata_to_binary()

      # Should contain a styled div with "to" text
      assert html_string =~
               ~r/<div[^>]*class="[^"]*flex[^"]*items-center[^"]*"[^>]*>\s*to\s*<\/div>/

      # Should use the theme's separator class
      assert html_string =~ "flex items-center px-2 text-sm font-medium text-gray-500"
    end

    test "DateRange filter renders styled separator" do
      alias Cinder.Filters.DateRange

      column = %{field: "created_at", filter_type: :date_range}
      current_value = %{from: "2024-01-01", to: "2024-12-31"}
      theme = Cinder.Theme.merge("modern")
      assigns = %{}

      html = DateRange.render(column, current_value, theme, assigns)
      html_string = html |> Phoenix.HTML.Safe.to_iodata() |> IO.iodata_to_binary()

      # Should contain a styled div with "to" text
      assert html_string =~
               ~r/<div[^>]*class="[^"]*flex[^"]*items-center[^"]*"[^>]*>\s*to\s*<\/div>/

      # Should use the theme's separator class
      assert html_string =~ "flex items-center px-2 text-sm font-medium text-gray-500"
    end

    test "different themes apply different separator styling" do
      alias Cinder.Filters.NumberRange

      column = %{field: "value", filter_type: :number_range}
      current_value = %{min: "10", max: "100"}
      assigns = %{}

      # Test modern theme (gray)
      modern_theme = Cinder.Theme.merge("modern")
      modern_html = NumberRange.render(column, current_value, modern_theme, assigns)
      modern_html_string = modern_html |> Phoenix.HTML.Safe.to_iodata() |> IO.iodata_to_binary()
      assert modern_html_string =~ "text-gray-500"

      # Test dark theme (gray-400)
      dark_theme = Cinder.Theme.merge("dark")
      dark_html = NumberRange.render(column, current_value, dark_theme, assigns)
      dark_html_string = dark_html |> Phoenix.HTML.Safe.to_iodata() |> IO.iodata_to_binary()
      assert dark_html_string =~ "text-gray-400"

      # Test retro theme (cyan)
      retro_theme = Cinder.Theme.merge("retro")
      retro_html = NumberRange.render(column, current_value, retro_theme, assigns)
      retro_html_string = retro_html |> Phoenix.HTML.Safe.to_iodata() |> IO.iodata_to_binary()
      assert retro_html_string =~ "text-cyan-300"
    end
  end

  describe "CSS Class Structure" do
    test "separator classes have consistent structure across themes" do
      themes = [
        "default",
        "modern",
        "dark",
        "compact",
        "daisy_ui",
        "flowbite",
        "futuristic",
        "retro"
      ]

      for theme_name <- themes do
        theme = Cinder.Theme.merge(theme_name)
        separator_class = theme.filter_range_separator_class

        # All should have flex for proper container behavior
        assert separator_class =~ "flex",
               "#{theme_name} separator missing flex"

        # All should have items-center for vertical alignment
        assert separator_class =~ "items-center",
               "#{theme_name} separator missing items-center"

        # All should have some horizontal padding
        assert separator_class =~ ~r/px-\d+/,
               "#{theme_name} separator missing horizontal padding"

        # All should have text sizing
        assert separator_class =~ ~r/text-(xs|sm|base)/,
               "#{theme_name} separator missing text size"
      end
    end
  end
end
