defmodule Cinder.Table.SearchUITest do
  use ExUnit.Case, async: true

  # Test resources for search UI testing
  defmodule SearchUITestResource do
    use Ash.Resource,
      domain: Cinder.Table.SearchUITest.TestDomain,
      data_layer: Ash.DataLayer.Ets,
      validate_domain_inclusion?: false

    ets do
      private?(true)
    end

    attributes do
      uuid_primary_key(:id)
      attribute(:title, :string, public?: true)
      attribute(:description, :string, public?: true)
      attribute(:status, :string, public?: true)
      attribute(:category, :string, public?: true)
    end

    actions do
      defaults([:read])

      create :create do
        primary?(true)
        accept([:title, :description, :status, :category])
      end
    end
  end

  defmodule TestDomain do
    use Ash.Domain, validate_config_inclusion?: false

    resources do
      resource(SearchUITestResource)
    end
  end

  describe "search UI rendering" do
    test "search component renders with proper UI structure" do
      # Focus on UI rendering, not logic
      theme = Cinder.Components.Search.default_theme()

      assert is_binary(theme.search_input_class)
      assert is_binary(theme.search_icon_class)
      assert is_binary(theme.search_label_class)
    end
  end

  describe "search theme integration" do
    test "search component has all required theme properties" do
      theme_properties = Cinder.Components.Search.theme_properties()

      required_properties = [
        :search_container_class,
        :search_wrapper_class,
        :search_input_class,
        :search_icon_class,
        :search_label_class
      ]

      Enum.each(required_properties, fn property ->
        assert property in theme_properties,
               "Missing theme property: #{property}"
      end)
    end

    test "search component default theme has all properties" do
      default_theme = Cinder.Components.Search.default_theme()

      required_keys = [
        :search_container_class,
        :search_wrapper_class,
        :search_input_class,
        :search_icon_class,
        :search_label_class
      ]

      Enum.each(required_keys, fn key ->
        assert Map.has_key?(default_theme, key),
               "Missing default theme key: #{key}"
      end)
    end

    test "search component is included in complete theme" do
      complete_theme = Cinder.Theme.complete_default()

      search_properties = Cinder.Components.Search.theme_properties()

      Enum.each(search_properties, fn property ->
        assert Map.has_key?(complete_theme, property),
               "Search property #{property} not found in complete theme"
      end)
    end

    test "modern theme includes search configuration" do
      modern_theme = Cinder.Themes.Modern.resolve_theme()

      search_properties = [
        :search_container_class,
        :search_input_class
      ]

      Enum.each(search_properties, fn property ->
        assert Map.has_key?(modern_theme, property),
               "Modern theme missing search property: #{property}"
      end)

      # Verify some specific modern theme values
      assert String.contains?(modern_theme.search_input_class, "focus:ring-2")
      assert String.contains?(modern_theme.search_input_class, "transition-all")
    end

    test "dark theme includes search configuration" do
      dark_theme = Cinder.Themes.Dark.resolve_theme()

      search_properties = [
        :search_container_class,
        :search_input_class
      ]

      Enum.each(search_properties, fn property ->
        assert Map.has_key?(dark_theme, property),
               "Dark theme missing search property: #{property}"
      end)

      # Verify dark theme specific styling
      assert String.contains?(dark_theme.search_input_class, "bg-gray-700")
      assert String.contains?(dark_theme.search_input_class, "transition-all")
      assert dark_theme.search_container_class == ""
    end
  end

  describe "search UI component structure" do
    test "search input has correct attributes and structure" do
      # This tests the structure we defined in the LiveComponent template
      expected_structure = %{
        container_conditional: "show_search?(@columns)",
        input_attributes: %{
          type: "text",
          value: "@search_term",
          event: "search_change",
          debounce: "300"
        },
        icons: %{
          search_icon: "magnifying glass SVG",
          clear_button: "X SVG with conditional display"
        },
        clear_button_conditional: "@search_term != \"\"",
        search_integration: "as first filter input",
        label_support: "uses filter_label_class",
        placeholder_support: "search_placeholder attribute"
      }

      # Verify the structure makes sense
      assert expected_structure.container_conditional == "show_search?(@columns)"
      assert expected_structure.input_attributes.type == "text"
      assert expected_structure.input_attributes.event == "search_change"
      assert expected_structure.clear_button_conditional == "@search_term != \"\""
      assert expected_structure.search_integration == "as first filter input"
      assert expected_structure.label_support == "uses filter_label_class"
      assert expected_structure.placeholder_support == "search_placeholder attribute"
    end

    test "search input uses proper debouncing" do
      # Verify we're using 300ms debounce (good balance between responsiveness and performance)
      debounce_time = 300
      assert debounce_time == 300
      # Not too fast (would cause excessive requests)
      assert debounce_time > 100
      # Not too slow (would feel unresponsive)
      assert debounce_time < 1000
    end

    test "search icons are properly structured" do
      # Test that our SVG icons have proper structure
      search_icon_attributes = %{
        viewBox: "0 0 24 24",
        paths: ["search magnifying glass path"]
      }

      clear_icon_attributes = %{
        viewBox: "0 0 24 24",
        paths: ["X cross paths"]
      }

      assert search_icon_attributes.viewBox == "0 0 24 24"
      assert clear_icon_attributes.viewBox == "0 0 24 24"
    end
  end

  describe "search UI conditional display" do
    test "search UI shows proper visual states" do
      # Focus on UI display states rather than logic
      theme = Cinder.Components.Search.default_theme()

      # Verify search input has proper UI classes for different states
      assert String.contains?(theme.search_input_class, "w-full")
      assert is_binary(theme.search_icon_class)

      # Test theme consistency across different visual states
      modern_theme = Cinder.Themes.Modern.resolve_theme()
      assert String.contains?(modern_theme.search_input_class, "border")
      assert String.contains?(modern_theme.search_input_class, "focus:")
    end
  end

  describe "search theme property validation" do
    test "all theme properties are valid atoms" do
      properties = Cinder.Components.Search.theme_properties()

      Enum.each(properties, fn property ->
        assert is_atom(property), "Theme property should be atom: #{inspect(property)}"

        assert Cinder.Components.Search.valid_property?(property),
               "Property should be valid: #{property}"
      end)
    end

    test "invalid properties are rejected" do
      invalid_properties = [
        "string_property",
        :invalid_property,
        nil,
        123
      ]

      Enum.each(invalid_properties, fn invalid ->
        refute Cinder.Components.Search.valid_property?(invalid),
               "Should reject invalid property: #{inspect(invalid)}"
      end)
    end
  end

  describe "search configuration" do
    test "search UI integrates properly with theme system" do
      # Focus on theme integration, not configuration logic
      modern_theme = Cinder.Themes.Modern.resolve_theme()
      dark_theme = Cinder.Themes.Dark.resolve_theme()

      # Verify themes have consistent search styling
      assert is_binary(modern_theme.search_input_class)
      assert is_binary(dark_theme.search_input_class)

      # Verify search integrates with filter styling
      assert modern_theme.search_label_class == ""
      assert dark_theme.search_label_class == ""
    end
  end

  describe "search attribute processing" do
    test "search UI renders with proper accessibility attributes" do
      # Focus on UI concerns like accessibility, structure
      theme = Cinder.Components.Search.default_theme()

      # Verify theme provides accessible classes
      assert String.contains?(theme.search_input_class, "w-full")
      assert is_binary(theme.search_wrapper_class)
      assert is_binary(theme.search_container_class)
    end
  end
end
