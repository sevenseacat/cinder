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

  describe "checkbox consistency" do
    @checkbox_properties [
      :filter_checkbox_input_class,
      :filter_multicheckboxes_checkbox_class,
      :filter_multiselect_checkbox_class,
      :selection_checkbox_class
    ]

    @checkbox_label_properties [
      :filter_checkbox_label_class,
      :filter_multicheckboxes_label_class
    ]

    for theme_module <- @themes do
      test "#{theme_module} styles every checkbox the same way" do
        theme = unquote(theme_module).resolve_theme()

        for properties <- [@checkbox_properties, @checkbox_label_properties] do
          styles = Map.new(properties, &{&1, without_spacing(theme[&1])})

          assert styles |> Map.values() |> Enum.uniq() |> length() == 1,
                 "#{unquote(theme_module)} checkbox styles differ: #{inspect(styles, pretty: true)}"
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

  describe "radio group filter height consistency" do
    for theme_module <- @themes do
      test "#{theme_module} radio group filter has consistent height with other inputs" do
        theme = unquote(theme_module).resolve_theme()

        radio_group_container = theme[:filter_radio_group_container_class]

        # Should have explicit height for consistency (h-10, h-12, h-[42px], etc.)
        assert Regex.match?(~r/\bh-(\d+|\[)/, radio_group_container),
               "#{unquote(theme_module)} radio group filter container should have explicit height for alignment"

        # Should include items-center for vertical alignment
        assert String.contains?(radio_group_container, "items-center"),
               "#{unquote(theme_module)} radio group filter container should center items vertically"
      end
    end
  end

  describe "table wrapper styling" do
    # Without overflow, striped or hovered rows paint past a rounded wrapper's
    # corners, and wide tables spill out of it.
    for theme_module <- @themes do
      test "#{theme_module} table wrapper clips and scrolls its table" do
        theme = unquote(theme_module).resolve_theme()

        assert theme[:table_wrapper_class] =~ ~r/\boverflow-x-auto\b/
      end

      test "#{theme_module} page size dropdown clips its options to its corners" do
        theme = unquote(theme_module).resolve_theme()

        assert theme[:page_size_dropdown_container_class] =~ ~r/\boverflow-(hidden|auto)\b/
      end
    end

    # The selected option's text colour is meant for its own background, and the
    # hover background replaces that
    test "DaisyUI page size options reset their text colour on hover" do
      theme = Cinder.Themes.DaisyUI.resolve_theme()

      assert theme[:page_size_option_class] =~ ~r/\bhover:text-/
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
                 String.contains?(pagination_wrapper, "px-") or
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

  # Spacing depends on how each checkbox's label is laid out, so it may differ
  defp without_spacing(classes) do
    classes
    |> String.split()
    |> Enum.reject(&String.match?(&1, ~r/^-?[mp][trblxy]?-/))
    |> Enum.sort()
  end
end
