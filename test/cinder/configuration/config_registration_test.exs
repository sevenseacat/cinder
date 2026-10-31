defmodule Cinder.ConfigRegistrationTest do
  use ExUnit.Case, async: false
  import Cinder.TestHelpers, only: [put_app_env: 2]

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
    # Start every test with no custom filters registered
    put_app_env(:filters, [])
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
  end

  describe "__using__ macro functionality" do
  end

  describe "edge cases and error handling" do
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
  end
end
