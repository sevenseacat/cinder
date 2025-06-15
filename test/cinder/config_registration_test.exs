defmodule Cinder.ConfigRegistrationTest do
  use ExUnit.Case, async: false

  alias Cinder.Filters.Registry

  # Test filter using the __using__ macro
  defmodule TestSliderFilter do
    use Cinder.Filter

    @impl true
    def render(column, current_value, theme, _assigns) do
      assigns = %{
        column: column,
        current_value: current_value || 0,
        theme: theme
      }

      ~H"""
      <input
        type="range"
        name={"filters[#{@column.field}]"}
        value={@current_value}
        class="slider"
      />
      """
    end

    @impl true
    def process(raw_value, _column) when is_binary(raw_value) do
      case Integer.parse(raw_value) do
        {value, ""} -> %{type: :slider, value: value, operator: :equals}
        _ -> nil
      end
    end

    def process(_raw_value, _column), do: nil

    @impl true
    def validate(%{type: :slider, value: value}) when is_integer(value), do: true
    def validate(_), do: false

    @impl true
    def default_options, do: [min: 0, max: 100, step: 1]

    @impl true
    def build_query(query, field, filter_value) do
      %{value: value, operator: operator} = filter_value
      field_atom = String.to_atom(field)

      case operator do
        :equals ->
          Ash.Query.filter(query, ^ref(field_atom) == ^value)

        _ ->
          query
      end
    end

    @impl true
    def empty?(nil), do: true
    def empty?(""), do: true
    def empty?(_), do: false
  end

  # Test filter with different options
  defmodule TestAnotherFilter do
    use Cinder.Filter

    @impl true
    def render(column, current_value, theme, _assigns) do
      assigns = %{
        column: column,
        current_value: current_value || 0,
        theme: theme
      }

      ~H"""
      <input type="range" name={"filters[#{@column.field}]"} value={@current_value} />
      """
    end

    @impl true
    def process(raw_value, _column) when is_binary(raw_value) do
      case Integer.parse(raw_value) do
        {value, ""} -> %{type: :another_slider, value: value, operator: :equals}
        _ -> nil
      end
    end

    def process(_raw_value, _column), do: nil

    @impl true
    def validate(%{type: :another_slider, value: value}) when is_integer(value), do: true
    def validate(_), do: false

    @impl true
    def default_options, do: [min: 0, max: 200, step: 2]

    @impl true
    def build_query(query, field, filter_value) do
      %{value: value, operator: operator} = filter_value
      field_atom = String.to_atom(field)

      case operator do
        :equals ->
          Ash.Query.filter(query, ^ref(field_atom) == ^value)

        _ ->
          query
      end
    end

    @impl true
    def empty?(nil), do: true
    def empty?(""), do: true
    def empty?(_), do: false
  end

  # Invalid filter for testing error handling
  defmodule InvalidFilter do
    # This module doesn't implement the behavior properly
    def some_function, do: :ok
  end

  setup do
    # Clear any existing configuration
    original_config = Application.get_env(:cinder, :filters, [])

    Application.put_env(:cinder, :filters, [])

    on_exit(fn ->
      Application.put_env(:cinder, :filters, original_config)
    end)

    :ok
  end

  describe "configuration-based registration" do
    test "registers filters from configuration" do
      # Set up configuration
      Application.put_env(:cinder, :filters,
        slider: TestSliderFilter,
        another_slider: TestAnotherFilter
      )

      assert Registry.register_config_filters() == :ok

      # Verify filters are registered
      assert Registry.get_filter(:slider) == TestSliderFilter
      assert Registry.get_filter(:another_slider) == TestAnotherFilter
      assert Registry.custom_filter?(:slider) == true
      assert Registry.custom_filter?(:another_slider) == true
    end

    test "handles invalid modules in configuration gracefully" do
      # Set up configuration with invalid module
      Application.put_env(:cinder, :filters,
        slider: TestSliderFilter,
        invalid: InvalidFilter
      )

      result = Registry.register_config_filters()

      assert {:error, errors} = result
      assert length(errors) == 1

      # Should have error for module without behavior
      assert Enum.any?(errors, &String.contains?(&1, "invalid:"))

      assert Enum.any?(
               errors,
               &String.contains?(&1, "does not implement Cinder.Filter behavior")
             )

      # Valid filter should still be registered
      assert Registry.get_filter(:slider) == TestSliderFilter
      assert Registry.custom_filter?(:slider) == true
    end

    test "list_custom_filters includes configuration filters" do
      Application.put_env(:cinder, :filters, slider: TestSliderFilter)

      custom_filters = Registry.list_custom_filters()

      assert custom_filters[:slider] == TestSliderFilter
      assert map_size(custom_filters) == 1
    end

    test "config filters are available after registration" do
      # Set up config filter
      Application.put_env(:cinder, :filters, slider: TestSliderFilter)

      Registry.register_config_filters()

      # Config filter should be available
      assert Registry.get_filter(:slider) == TestSliderFilter
      assert Registry.custom_filter?(:slider) == true
    end

    test "config filters work with all registry functions" do
      Application.put_env(:cinder, :filters, slider: TestSliderFilter)

      # Test all registry functions work with config filters
      assert Registry.get_filter(:slider) == TestSliderFilter
      assert Registry.registered?(:slider) == true
      assert Registry.custom_filter?(:slider) == true

      options = Registry.default_options(:slider)
      assert options == [min: 0, max: 100, step: 1]

      all_filters = Registry.all_filters_with_custom()
      assert all_filters[:slider] == TestSliderFilter
      # Built-in still there
      assert all_filters[:text] == Cinder.Filters.Text
    end
  end

  describe "__using__ macro functionality" do
    test "provides necessary imports and behavior" do
      # Test that the module compiles and has the right behavior
      assert function_exported?(TestSliderFilter, :render, 4)
      assert function_exported?(TestSliderFilter, :process, 2)
      assert function_exported?(TestSliderFilter, :validate, 1)
      assert function_exported?(TestSliderFilter, :default_options, 0)
      assert function_exported?(TestSliderFilter, :empty?, 1)

      # Test that Phoenix.Component functions are available (from use Phoenix.Component)
      # and Cinder.Filter functions are imported
      # These would be compile-time errors if not available
      assert TestSliderFilter.default_options() == [min: 0, max: 100, step: 1]
    end

    test "basic usage pattern without configuration options" do
      # Test that using Cinder.Filter without any options works correctly
      defmodule BasicFilter do
        use Cinder.Filter

        @impl true
        def render(_column, _current_value, _theme, assigns) do
          ~H"<div>basic</div>"
        end

        @impl true
        def process(raw_value, _column), do: raw_value

        @impl true
        def validate(_value), do: true

        @impl true
        def default_options, do: []

        @impl true
        def empty?(value), do: is_nil(value) or value == ""

        @impl true
        def build_query(query, _field, _value), do: query
      end

      # Should compile without errors and have all required functions
      assert function_exported?(BasicFilter, :render, 4)
      assert function_exported?(BasicFilter, :process, 2)
      assert function_exported?(BasicFilter, :validate, 1)
      assert function_exported?(BasicFilter, :default_options, 0)
      assert function_exported?(BasicFilter, :empty?, 1)
      assert function_exported?(BasicFilter, :build_query, 3)
    end

    test "filter with __using__ macro works correctly" do
      # Register and test the filter
      Registry.register_filter(:test_slider, TestSliderFilter)

      # Test rendering
      column = %{field: "price", label: "Price"}
      theme = %{}
      assigns = %{}

      rendered = TestSliderFilter.render(column, 50, theme, assigns)
      html_string = rendered |> Phoenix.HTML.Safe.to_iodata() |> IO.iodata_to_binary()

      assert html_string =~ "type=\"range\""
      assert html_string =~ "value=\"50\""
      assert html_string =~ "filters[price]"

      # Test processing
      result = TestSliderFilter.process("75", column)
      assert result == %{type: :slider, value: 75, operator: :equals}

      # Test validation
      assert TestSliderFilter.validate(%{type: :slider, value: 50}) == true
      assert TestSliderFilter.validate(%{type: :other, value: 50}) == false

      # Test empty check
      assert TestSliderFilter.empty?(nil) == true
      assert TestSliderFilter.empty?("") == true
      assert TestSliderFilter.empty?(50) == false
    end

    test "multiple filters work with __using__ macro" do
      # Test that multiple filters can be registered via config
      Application.put_env(:cinder, :filters, another_slider: TestAnotherFilter)

      # The module should register when configured
      Registry.register_config_filters()

      assert Registry.get_filter(:another_slider) == TestAnotherFilter
      assert Registry.custom_filter?(:another_slider) == true

      # Test that it has different default options
      options = Registry.default_options(:another_slider)
      assert options == [min: 0, max: 200, step: 2]
    end
  end

  describe "Cinder.setup/0 integration" do
    test "Cinder.setup registers config filters and validates" do
      Application.put_env(:cinder, :filters, slider: TestSliderFilter)

      # setup should return :ok and register filters
      assert Cinder.setup() == :ok

      # Verify filter was registered
      assert Registry.get_filter(:slider) == TestSliderFilter
      assert Registry.custom_filter?(:slider) == true
    end

    test "Cinder.setup handles registration errors gracefully" do
      import ExUnit.CaptureLog

      Application.put_env(:cinder, :filters,
        slider: TestSliderFilter,
        broken: NonExistentModule
      )

      log_output =
        capture_log(fn ->
          result = Cinder.setup()
          # Should still return :ok
          assert result == :ok
        end)

      # Should log warning about failed registration
      assert log_output =~ "Some custom filters failed to register"
      assert log_output =~ "broken:"

      # Valid filter should still work
      assert Registry.get_filter(:slider) == TestSliderFilter
    end

    test "Cinder.setup logs successful registrations" do
      import ExUnit.CaptureLog

      Application.put_env(:cinder, :filters,
        slider: TestSliderFilter,
        another_slider: TestAnotherFilter
      )

      log_output =
        capture_log(fn ->
          assert Cinder.setup() == :ok
        end)

      # Should log successful registration
      assert log_output =~ "Registered 2 custom filters"
      assert log_output =~ "slider"
      assert log_output =~ "another_slider"
    end

    test "Cinder.setup with no configured filters" do
      import ExUnit.CaptureLog

      # No filters configured
      Application.put_env(:cinder, :filters, [])

      log_output =
        capture_log(fn ->
          assert Cinder.setup() == :ok
        end)

      # Should not log registration message when no filters
      refute log_output =~ "Registered"
    end
  end

  describe "edge cases and error handling" do
    test "config registration provides filters through configuration" do
      # Set up config
      Application.put_env(:cinder, :filters, slider: TestSliderFilter)

      # Runtime registration only validates, doesn't store
      assert Registry.register_filter(:slider, TestSliderFilter) == :ok

      # Config registration makes filters available
      Registry.register_config_filters()

      # Config filter should be available
      assert Registry.get_filter(:slider) == TestSliderFilter
    end

    test "empty configuration handling" do
      Application.put_env(:cinder, :filters, [])

      assert Registry.register_config_filters() == :ok
      assert Registry.list_custom_filters() == %{}
    end

    test "configuration with nil values" do
      import ExUnit.CaptureLog

      Application.put_env(:cinder, :filters,
        slider: nil,
        valid: TestSliderFilter
      )

      _log_output =
        capture_log(fn ->
          result = Registry.register_config_filters()
          assert {:error, _} = result
        end)

      # Should handle nil gracefully
      assert Registry.get_filter(:valid) == TestSliderFilter
      assert Registry.get_filter(:slider) == nil
    end

    test "config filters work correctly" do
      # Config filters
      Application.put_env(:cinder, :filters, config_slider: TestSliderFilter)

      Registry.register_config_filters()

      # Should be available
      assert Registry.get_filter(:config_slider) == TestSliderFilter

      # Should be marked as custom
      assert Registry.custom_filter?(:config_slider) == true

      custom_filters = Registry.list_custom_filters()
      assert map_size(custom_filters) == 1
    end
  end
end
