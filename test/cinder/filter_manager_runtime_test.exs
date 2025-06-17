defmodule Cinder.FilterManagerRuntimeTest do
  use ExUnit.Case, async: false
  import ExUnit.CaptureLog
  import Phoenix.LiveViewTest

  alias Cinder.FilterManager
  alias Cinder.Filters.Registry

  # Test module that implements the Cinder.Filter behavior correctly
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
        min="0"
        max="100"
        class={Map.get(@theme, :filter_slider_input_class, "slider")}
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
    def empty?(0), do: true
    def empty?(_), do: false
  end

  # Test module that throws errors during processing
  defmodule BrokenFilter do
    @behaviour Cinder.Filter
    use Phoenix.Component
    require Ash.Query

    @impl true
    def render(_column, _current_value, _theme, _assigns) do
      assigns = %{}
      ~H"<div>broken</div>"
    end

    @impl true
    def process(_raw_value, _column) do
      raise "This filter is broken!"
    end

    @impl true
    def validate(_), do: true

    @impl true
    def default_options, do: []

    @impl true
    def empty?(_), do: false

    @impl true
    def build_query(_query, _field, _filter_value) do
      raise "This filter's build_query is broken too!"
    end
  end

  setup do
    # Clear any existing filters before each test
    Application.put_env(:cinder, :filters, [])
    :ok
  end

  describe "filter_input/1 with custom filters" do
    test "renders custom filter when module is available" do
      Application.put_env(:cinder, :filters, slider: TestSliderFilter)
      Registry.register_config_filters()

      column = %{
        field: "price",
        label: "Price",
        filter_type: :slider,
        filter_options: []
      }

      theme = Cinder.Theme.default()

      assigns = %{
        column: column,
        current_value: 50,
        theme: theme,
        target: nil,
        filter_values: %{}
      }

      html_string = render_component(&FilterManager.filter_input/1, assigns)

      assert html_string =~ "type=\"range\""
      assert html_string =~ "value=\"50\""
      assert html_string =~ "slider"
      assert html_string =~ "filters[price]"
    end

    test "falls back to text filter when custom filter module missing" do
      # Test the graceful fallback by checking the Registry directly
      # Manually add invalid module to simulate missing module at runtime
      Application.put_env(:cinder, :filters, missing: NonExistentModule)

      # Check that the filter is considered custom but module is not available
      assert Registry.custom_filter?(:missing) == true
      assert Registry.get_filter(:missing) == NonExistentModule

      column = %{
        field: "price",
        label: "Price",
        filter_type: :missing,
        filter_options: []
      }

      theme = Cinder.Theme.default()

      assigns = %{
        column: column,
        current_value: "test",
        theme: theme,
        target: nil,
        filter_values: %{}
      }

      log_output =
        capture_log(fn ->
          html_string = render_component(&FilterManager.filter_input/1, assigns)

          # Should render as text input instead
          assert html_string =~ "type=\"text\""
          assert html_string =~ "value=\"test\""
        end)

      assert log_output =~ "Error rendering custom filter :missing for column 'price'"
      assert log_output =~ "Falling back to text filter"
    end

    test "renders built-in filters normally" do
      column = %{
        field: "name",
        label: "Name",
        filter_type: :text,
        filter_options: []
      }

      theme = Cinder.Theme.default()

      assigns = %{
        column: column,
        current_value: "test",
        theme: theme,
        target: nil,
        filter_values: %{}
      }

      html_string = render_component(&FilterManager.filter_input/1, assigns)

      assert html_string =~ "type=\"text\""
      assert html_string =~ "value=\"test\""
      assert html_string =~ "type=\"text\""
    end
  end

  describe "process_filter_value/2 with custom filters" do
    test "processes custom filter values successfully" do
      Application.put_env(:cinder, :filters, slider: TestSliderFilter)
      Registry.register_config_filters()

      column = %{
        field: "price",
        filter_type: :slider,
        filter_options: []
      }

      result = FilterManager.process_filter_value("75", column)

      assert result == %{type: :slider, value: 75, operator: :equals}
    end

    test "handles custom filter processing errors gracefully" do
      Application.put_env(:cinder, :filters, broken: BrokenFilter)
      Registry.register_config_filters()

      column = %{
        field: "price",
        filter_type: :broken,
        filter_options: []
      }

      log_output =
        capture_log(fn ->
          result = FilterManager.process_filter_value("test", column)

          # Should fall back to text processing
          assert result == %{
                   type: :text,
                   value: "test",
                   operator: :contains,
                   case_sensitive: false
                 }
        end)

      assert log_output =~ "Error processing filter value for custom filter :broken"
      assert log_output =~ "Falling back to text processing"
    end

    test "falls back to text processing when custom filter module missing" do
      # Manually add invalid module to simulate missing module at runtime
      Application.put_env(:cinder, :filters, missing: NonExistentModule)

      column = %{
        field: "price",
        filter_type: :missing,
        filter_options: []
      }

      log_output =
        capture_log(fn ->
          result = FilterManager.process_filter_value("test", column)

          # Should fall back to text processing
          assert result == %{
                   type: :text,
                   value: "test",
                   operator: :contains,
                   case_sensitive: false
                 }
        end)

      assert log_output =~ "Error processing filter value for custom filter :missing"
      assert log_output =~ "Falling back to text processing"
    end

    test "processes built-in filters normally" do
      column = %{
        field: "name",
        filter_type: :text,
        filter_options: []
      }

      result = FilterManager.process_filter_value("test value", column)

      assert result == %{
               type: :text,
               value: "test value",
               operator: :contains,
               case_sensitive: false
             }
    end
  end

  describe "infer_filter_config/3 with custom filters" do
    test "allows explicit custom filter types when module exists" do
      Application.put_env(:cinder, :filters, slider: TestSliderFilter)
      Registry.register_config_filters()

      slot = %{
        filterable: true,
        filter_type: :slider,
        filter_options: [min: 10, max: 200]
      }

      config = FilterManager.infer_filter_config("price", nil, slot)

      assert config.filter_type == :slider
      # Note: filter_options are merged with defaults, so check that custom options are preserved
      assert Keyword.get(config.filter_options, :min) == 10
      assert Keyword.get(config.filter_options, :max) == 200
    end

    test "falls back to text filter when custom filter module missing" do
      # Manually add invalid module to simulate missing module at runtime
      Application.put_env(:cinder, :filters, missing: NonExistentModule)

      slot = %{
        filterable: true,
        filter_type: :missing,
        filter_options: []
      }

      log_output =
        capture_log(fn ->
          config = FilterManager.infer_filter_config("price", nil, slot)

          assert config.filter_type == :text
          assert is_list(config.filter_options)
        end)

      assert log_output =~ "Custom filter :missing is registered but module is not available"
      assert log_output =~ "for column 'price'. Falling back to text filter"
    end

    test "infers built-in filters normally" do
      slot = %{
        filterable: true,
        filter_options: []
      }

      # Mock Ash resource attribute
      resource = nil

      config = FilterManager.infer_filter_config("name", resource, slot)

      assert config.filter_type == :text
      assert is_list(config.filter_options)
    end
  end

  describe "validate_runtime_filters/0" do
    test "returns :ok when all custom filters are valid" do
      Application.put_env(:cinder, :filters, slider: TestSliderFilter)
      Registry.register_config_filters()

      assert FilterManager.validate_runtime_filters() == :ok
    end

    test "returns :ok when no custom filters are registered" do
      assert FilterManager.validate_runtime_filters() == :ok
    end

    test "logs warnings and returns error when custom filters are invalid" do
      # Manually add invalid filters to bypass registration validation
      Application.put_env(:cinder, :filters,
        broken: NonExistentModule,
        missing: AnotherMissingModule
      )

      log_output =
        capture_log(fn ->
          result = FilterManager.validate_runtime_filters()

          assert {:error, errors} = result
          assert length(errors) == 2
        end)

      assert log_output =~ "Custom filter validation failed during application startup"
      assert log_output =~ "NonExistentModule does not exist"
      assert log_output =~ "AnotherMissingModule does not exist"
    end

    test "continues execution even when validation fails" do
      # This test ensures that failed validation doesn't crash the application
      Application.put_env(:cinder, :filters, broken: NonExistentModule)

      log_output =
        capture_log(fn ->
          result = FilterManager.validate_runtime_filters()

          assert {:error, _errors} = result
        end)

      assert log_output =~ "Custom filter validation failed"

      # Application should still be able to continue
      assert Registry.registered?(:text) == true
    end
  end

  describe "integration with built-in filter system" do
    test "custom filters work alongside built-in filters" do
      Application.put_env(:cinder, :filters, slider: TestSliderFilter)
      Registry.register_config_filters()

      # Test both custom and built-in filters
      custom_column = %{
        field: "price",
        filter_type: :slider,
        filter_options: []
      }

      builtin_column = %{
        field: "name",
        filter_type: :text,
        filter_options: []
      }

      # Both should process correctly
      custom_result = FilterManager.process_filter_value("50", custom_column)
      builtin_result = FilterManager.process_filter_value("test", builtin_column)

      assert custom_result == %{type: :slider, value: 50, operator: :equals}

      assert builtin_result == %{
               type: :text,
               value: "test",
               operator: :contains,
               case_sensitive: false
             }
    end

    test "default_options works for both custom and built-in filters" do
      Application.put_env(:cinder, :filters, slider: TestSliderFilter)
      Registry.register_config_filters()

      # Custom filter options
      custom_options = Registry.default_options(:slider)
      assert custom_options == [min: 0, max: 100, step: 1]

      # Built-in filter options
      text_options = Registry.default_options(:text)
      assert Keyword.has_key?(text_options, :operator)
    end

    test "filter discovery works for both types" do
      Application.put_env(:cinder, :filters, slider: TestSliderFilter)
      Registry.register_config_filters()

      # Both should be discoverable
      assert Registry.get_filter(:slider) == TestSliderFilter
      assert Registry.get_filter(:text) == Cinder.Filters.Text

      # Registration status should be accurate
      assert Registry.registered?(:slider) == true
      assert Registry.registered?(:text) == true

      # Custom filter identification should work
      assert Registry.custom_filter?(:slider) == true
      assert Registry.custom_filter?(:text) == false
    end
  end
end
