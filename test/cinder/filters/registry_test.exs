defmodule Cinder.Filters.RegistryTest do
  use ExUnit.Case, async: true
  import ExUnit.CaptureLog

  alias Cinder.Filters.Registry

  # Test module that implements the Cinder.Filter behavior
  defmodule TestSliderFilter do
    use Cinder.Filter

    @impl true
    def render(_column, _current_value, _theme, _assigns) do
      assigns = %{}

      ~H"""
      <input type="range" />
      """
    end

    @impl true
    def process(raw_value, _column) do
      case Integer.parse(raw_value) do
        {value, ""} -> %{type: :slider, value: value, operator: :equals}
        _ -> nil
      end
    end

    @impl true
    def validate(%{type: :slider, value: value}) when is_integer(value), do: true
    def validate(_), do: false

    @impl true
    def default_options, do: [min: 0, max: 100, step: 1]

    @impl true
    def build_query(query, field, filter_value) do
      %{value: value} = filter_value
      field_atom = String.to_atom(field)
      Ash.Query.filter(query, ^ref(field_atom) == ^value)
    end

    @impl true
    def empty?(nil), do: true
    def empty?(""), do: true
    def empty?(_), do: false
  end

  # Test module that does NOT implement the behavior correctly
  defmodule IncompleteFilter do
    @behaviour Cinder.Filter

    @impl true
    def render(_column, _current_value, _theme, _assigns), do: nil

    # Missing other required callbacks
  end

  # Test module that doesn't implement the behavior at all
  defmodule NonBehaviorModule do
    def some_function, do: :ok
  end

  setup do
    # Clear any existing custom filters before each test
    Application.put_env(:cinder, :custom_filters, %{})
    :ok
  end

  describe "built-in filter management" do
    test "all_filters/0 returns built-in filter types" do
      filters = Registry.all_filters()

      assert is_map(filters)
      assert Map.has_key?(filters, :text)
      assert Map.has_key?(filters, :select)
      assert Map.has_key?(filters, :multi_select)
      assert Map.has_key?(filters, :date_range)
      assert Map.has_key?(filters, :number_range)
      assert Map.has_key?(filters, :boolean)

      assert filters[:text] == Cinder.Filters.Text
      assert filters[:select] == Cinder.Filters.Select
    end

    test "get_filter/1 returns correct module for built-in types" do
      assert Registry.get_filter(:text) == Cinder.Filters.Text
      assert Registry.get_filter(:select) == Cinder.Filters.Select
      assert Registry.get_filter(:unknown) == nil
    end

    test "registered?/1 correctly identifies built-in types" do
      assert Registry.registered?(:text) == true
      assert Registry.registered?(:select) == true
      assert Registry.registered?(:unknown) == false
    end

    test "filter_types/0 returns list of built-in filter type atoms" do
      types = Registry.filter_types()

      assert is_list(types)
      assert :text in types
      assert :select in types
      assert :multi_select in types
      assert :date_range in types
      assert :number_range in types
      assert :boolean in types
    end

    test "default_options/2 returns correct options for built-in filters" do
      text_options = Registry.default_options(:text)
      assert is_list(text_options)

      select_options = Registry.default_options(:select)
      assert is_list(select_options)

      unknown_options = Registry.default_options(:unknown)
      assert unknown_options == []
    end
  end

  describe "custom filter registration" do
    test "register_filter/2 successfully registers valid custom filter" do
      assert Registry.register_filter(:slider, TestSliderFilter) == :ok

      # Verify registration
      assert Registry.get_filter(:slider) == TestSliderFilter
      assert Registry.registered?(:slider) == true
      assert Registry.custom_filter?(:slider) == true
    end

    test "register_filter/2 prevents overriding built-in filter types" do
      result = Registry.register_filter(:text, TestSliderFilter)

      assert {:error, message} = result
      assert message == "Cannot override built-in filter type :text"

      # Verify built-in filter is unchanged
      assert Registry.get_filter(:text) == Cinder.Filters.Text
    end

    test "register_filter/2 validates module exists" do
      result = Registry.register_filter(:nonexistent, NonExistentModule)

      assert {:error, message} = result
      assert message == "Module NonExistentModule does not exist"
    end

    test "register_filter/2 validates module implements behavior" do
      result = Registry.register_filter(:invalid, NonBehaviorModule)

      assert {:error, message} = result

      assert message ==
               "Module Cinder.Filters.RegistryTest.NonBehaviorModule does not implement Cinder.Filter behavior"
    end

    test "register_filter/2 allows re-registration of same custom filter" do
      assert Registry.register_filter(:slider, TestSliderFilter) == :ok
      assert Registry.register_filter(:slider, TestSliderFilter) == :ok

      assert Registry.get_filter(:slider) == TestSliderFilter
    end
  end

  describe "custom filter unregistration" do
    test "unregister_filter/1 successfully removes custom filter" do
      # First register a filter
      Registry.register_filter(:slider, TestSliderFilter)
      assert Registry.registered?(:slider) == true

      # Then unregister it
      assert Registry.unregister_filter(:slider) == :ok
      assert Registry.registered?(:slider) == false
      assert Registry.get_filter(:slider) == nil
    end

    test "unregister_filter/1 prevents unregistering built-in filters" do
      result = Registry.unregister_filter(:text)

      assert {:error, message} = result
      assert message == "Cannot unregister built-in filter type :text"

      # Verify built-in filter is still available
      assert Registry.get_filter(:text) == Cinder.Filters.Text
    end

    test "unregister_filter/1 handles non-existent custom filters gracefully" do
      assert Registry.unregister_filter(:nonexistent) == :ok
    end
  end

  describe "custom filter introspection" do
    test "list_custom_filters/0 returns empty map when no custom filters" do
      assert Registry.list_custom_filters() == %{}
    end

    test "list_custom_filters/0 returns registered custom filters" do
      Registry.register_filter(:slider, TestSliderFilter)
      Registry.register_filter(:color_picker, TestSliderFilter)

      custom_filters = Registry.list_custom_filters()

      assert map_size(custom_filters) == 2
      assert custom_filters[:slider] == TestSliderFilter
      assert custom_filters[:color_picker] == TestSliderFilter
    end

    test "custom_filter?/1 correctly identifies custom filters" do
      assert Registry.custom_filter?(:slider) == false

      Registry.register_filter(:slider, TestSliderFilter)
      assert Registry.custom_filter?(:slider) == true

      assert Registry.custom_filter?(:text) == false
    end
  end

  describe "combined filter management" do
    test "all_filters_with_custom/0 merges built-in and custom filters" do
      Registry.register_filter(:slider, TestSliderFilter)
      Registry.register_filter(:color_picker, TestSliderFilter)

      all_filters = Registry.all_filters_with_custom()

      # Should include built-in filters
      assert all_filters[:text] == Cinder.Filters.Text
      assert all_filters[:select] == Cinder.Filters.Select

      # Should include custom filters
      assert all_filters[:slider] == TestSliderFilter
      assert all_filters[:color_picker] == TestSliderFilter
    end

    test "get_filter/1 works with custom filters after registration" do
      assert Registry.get_filter(:slider) == nil

      Registry.register_filter(:slider, TestSliderFilter)
      assert Registry.get_filter(:slider) == TestSliderFilter

      Registry.unregister_filter(:slider)
      assert Registry.get_filter(:slider) == nil
    end

    test "default_options/2 works with custom filters" do
      Registry.register_filter(:slider, TestSliderFilter)

      options = Registry.default_options(:slider)
      assert options == [min: 0, max: 100, step: 1]
    end
  end

  describe "custom filter validation" do
    test "validate_custom_filters/0 returns :ok when all filters are valid" do
      Registry.register_filter(:slider, TestSliderFilter)

      assert Registry.validate_custom_filters() == :ok
    end

    test "validate_custom_filters/0 returns :ok when no custom filters" do
      assert Registry.validate_custom_filters() == :ok
    end

    test "validate_custom_filters/0 detects non-existent modules" do
      # Manually add invalid filter to avoid registration validation
      Application.put_env(:cinder, :custom_filters, %{broken: NonExistentModule})

      result = Registry.validate_custom_filters()

      assert {:error, [error]} = result
      assert error =~ "Custom filter :broken - Module NonExistentModule does not exist"
    end

    test "validate_custom_filters/0 detects modules without behavior" do
      # Manually add module that doesn't implement behavior
      Application.put_env(:cinder, :custom_filters, %{invalid: NonBehaviorModule})

      result = Registry.validate_custom_filters()

      assert {:error, [error]} = result
      assert error =~ "does not implement Cinder.Filter behavior"
    end

    test "validate_custom_filters/0 detects modules with missing callbacks" do
      # Manually add module with incomplete implementation
      Application.put_env(:cinder, :custom_filters, %{incomplete: IncompleteFilter})

      {result, _logs} =
        ExUnit.CaptureLog.with_log(fn ->
          Registry.validate_custom_filters()
        end)

      assert {:error, [error]} = result
      assert error =~ "is missing callbacks"
      assert error =~ "process/2"
      assert error =~ "validate/1"
    end

    test "validate_custom_filters/0 reports multiple validation errors" do
      Application.put_env(:cinder, :custom_filters, %{
        broken: NonExistentModule,
        invalid: NonBehaviorModule,
        incomplete: IncompleteFilter
      })

      {result, _logs} =
        ExUnit.CaptureLog.with_log(fn ->
          Registry.validate_custom_filters()
        end)

      assert {:error, errors} = result
      assert length(errors) == 3
      assert Enum.any?(errors, &(&1 =~ "NonExistentModule does not exist"))
      assert Enum.any?(errors, &(&1 =~ "NonBehaviorModule does not implement"))
      assert Enum.any?(errors, &(&1 =~ "IncompleteFilter is missing callbacks"))
    end
  end

  describe "filter type inference with custom filters" do
    test "infer_filter_type/2 still works for built-in types" do
      # Test with string attribute
      string_attr = %{type: Ash.Type.String}
      assert Registry.infer_filter_type(string_attr) == :text

      # Test with boolean attribute
      boolean_attr = %{type: Ash.Type.Boolean}
      assert Registry.infer_filter_type(boolean_attr) == :boolean

      # Test with integer attribute
      integer_attr = %{type: Ash.Type.Integer}
      assert Registry.infer_filter_type(integer_attr) == :number_range
    end

    test "infer_filter_type/2 falls back to text for unknown types" do
      unknown_attr = %{type: :some_unknown_type}
      assert Registry.infer_filter_type(unknown_attr) == :text
    end
  end

  describe "error handling and edge cases" do
    test "registration handles atom and string filter type names" do
      assert Registry.register_filter(:slider, TestSliderFilter) == :ok
      assert Registry.get_filter(:slider) == TestSliderFilter
    end

    test "unregistration maintains application environment consistency" do
      Registry.register_filter(:filter1, TestSliderFilter)
      Registry.register_filter(:filter2, TestSliderFilter)

      assert map_size(Registry.list_custom_filters()) == 2

      Registry.unregister_filter(:filter1)
      custom_filters = Registry.list_custom_filters()

      assert map_size(custom_filters) == 1
      assert custom_filters[:filter2] == TestSliderFilter
      assert not Map.has_key?(custom_filters, :filter1)
    end

    test "multiple registrations and unregistrations work correctly" do
      # Register multiple filters
      Registry.register_filter(:slider, TestSliderFilter)
      Registry.register_filter(:color_picker, TestSliderFilter)

      assert Registry.custom_filter?(:slider) == true
      assert Registry.custom_filter?(:color_picker) == true

      # Unregister one
      Registry.unregister_filter(:slider)

      assert Registry.custom_filter?(:slider) == false
      assert Registry.custom_filter?(:color_picker) == true

      # Register again
      Registry.register_filter(:slider, TestSliderFilter)

      assert Registry.custom_filter?(:slider) == true
      assert Registry.custom_filter?(:color_picker) == true
    end
  end
end
