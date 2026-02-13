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
        filter_values: %{},
        table_id: "test-table"
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
        filter_values: %{},
        table_id: "test-table"
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
        filter_values: %{},
        table_id: "test-table"
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

  describe "checkbox filter unchecking behavior" do
    test "checkbox filter is cleared when unchecked (not in form data)" do
      # Setup columns including a checkbox filter
      columns = [
        %{
          field: "published",
          filterable: true,
          filter_type: :checkbox,
          filter_options: [label: "Published only", value: true]
        },
        %{field: "title", filterable: true, filter_type: :text, filter_options: []}
      ]

      # Simulate form data when checkbox is checked
      checked_params = %{"published" => "true", "title" => "test"}
      checked_filters = FilterManager.params_to_filters(checked_params, columns)

      # Should include the checkbox filter
      assert Map.has_key?(checked_filters, "published")
      assert checked_filters["published"].value == true

      # Simulate form data when checkbox is unchecked (field missing from form)
      unchecked_params = %{"title" => "test"}
      unchecked_filters = FilterManager.params_to_filters(unchecked_params, columns)

      # Should NOT include the checkbox filter (it gets cleared)
      refute Map.has_key?(unchecked_filters, "published")
      # Other filters should still be present
      assert Map.has_key?(unchecked_filters, "title")
    end

    test "checkbox filter handles empty string values correctly" do
      columns = [
        %{
          field: "active",
          filterable: true,
          filter_type: :checkbox,
          filter_options: [label: "Active only", value: true]
        }
      ]

      # Empty string should result in no filter (same as unchecked)
      empty_params = %{"active" => ""}
      empty_filters = FilterManager.params_to_filters(empty_params, columns)

      refute Map.has_key?(empty_filters, "active")
    end
  end

  describe "enum option labeling for simple atom arrays" do
    # Real Ash.Type.Enum module with simple atom array values
    defmodule TestSimpleEnum do
      use Ash.Type.Enum, values: [:pending, :trading, :paused, "Test"]
    end

    # Real Ash.Type.Enum module with keyword array values (working case)
    defmodule TestKeywordEnum do
      use Ash.Type.Enum,
        values: [
          # "Pending Status" is actually the description, and won't be used
          pending: "Pending Status",
          trading: [label: "Currently Trading"],
          paused: [label: "Paused Status", description: "This is the paused status"]
        ]
    end

    test "enum_to_options correctly labels atoms from simple array" do
      # This reproduces the issue from GitHub issue #52
      # Call the private function through a mock attribute
      mock_attribute = %{
        type: TestSimpleEnum,
        constraints: []
      }

      result = FilterManager.extract_enum_options(mock_attribute)

      # These should be properly labeled, not showing raw atom values
      expected = [
        {"Pending", :pending},
        {"Trading", :trading},
        {"Paused", :paused},
        {"Test", "Test"}
      ]

      assert result == expected
    end

    test "enum_to_options correctly labels keyword enum values" do
      mock_attribute = %{
        type: TestKeywordEnum,
        constraints: []
      }

      result = FilterManager.extract_enum_options(mock_attribute)

      expected = [
        {"Pending", :pending},
        {"Currently Trading", :trading},
        {"Paused Status", :paused}
      ]

      assert result == expected
    end

    test "enum_to_options handles mixed atom and string values correctly" do
      # Test the exact case from the GitHub issue
      defmodule TestMixedEnum do
        use Ash.Type.Enum, values: [:pending, :trading, :paused, "Test"]
      end

      mock_attribute = %{
        type: TestMixedEnum,
        constraints: []
      }

      result = FilterManager.extract_enum_options(mock_attribute)

      # Atoms should be humanized, strings should be capitalized
      expected = [
        {"Pending", :pending},
        {"Trading", :trading},
        {"Paused", :paused},
        {"Test", "Test"}
      ]

      assert result == expected
    end
  end

  describe "filter label accessibility" do
    setup do
      theme = Cinder.Theme.default()
      %{theme: theme}
    end

    test "text filter label for attribute matches input id", %{theme: theme} do
      column = %{field: "name", label: "Name", filter_type: :text, filter_options: []}

      label_assigns = %{column: column, table_id: "test-table", theme: theme}
      label_html = render_component(&FilterManager.filter_label/1, label_assigns)

      input_assigns = %{
        column: column,
        current_value: nil,
        theme: theme,
        target: nil,
        filter_values: %{},
        table_id: "test-table"
      }

      input_html = render_component(&FilterManager.filter_input/1, input_assigns)

      # Label should have for attribute
      assert label_html =~ ~r/for="test-table-filter-name"/
      # Input should have matching id
      assert input_html =~ ~r/id="test-table-filter-name"/
    end

    test "select filter label for attribute matches button id", %{theme: theme} do
      column = %{
        field: "status",
        label: "Status",
        filter_type: :select,
        filter_options: [options: [{"Active", "active"}]]
      }

      label_assigns = %{column: column, table_id: "test-table", theme: theme}
      label_html = render_component(&FilterManager.filter_label/1, label_assigns)

      input_assigns = %{
        column: column,
        current_value: nil,
        theme: theme,
        target: nil,
        filter_values: %{},
        table_id: "test-table"
      }

      input_html = render_component(&FilterManager.filter_input/1, input_assigns)

      # Label should have for attribute pointing to button
      assert label_html =~ ~r/for="test-table-filter-status-button"/
      # Button should have matching id
      assert input_html =~ ~r/id="test-table-filter-status-button"/
    end

    test "number range filter label points to min input", %{theme: theme} do
      column = %{field: "price", label: "Price", filter_type: :number_range, filter_options: []}

      label_assigns = %{column: column, table_id: "test-table", theme: theme}
      label_html = render_component(&FilterManager.filter_label/1, label_assigns)

      input_assigns = %{
        column: column,
        current_value: nil,
        theme: theme,
        target: nil,
        filter_values: %{},
        table_id: "test-table"
      }

      input_html = render_component(&FilterManager.filter_input/1, input_assigns)

      # Label should point to min input
      assert label_html =~ ~r/for="test-table-filter-price-min"/
      # Both inputs should have ids
      assert input_html =~ ~r/id="test-table-filter-price-min"/
      assert input_html =~ ~r/id="test-table-filter-price-max"/
    end

    test "date range filter label points to from input", %{theme: theme} do
      column = %{
        field: "created_at",
        label: "Created",
        filter_type: :date_range,
        filter_options: []
      }

      label_assigns = %{column: column, table_id: "test-table", theme: theme}
      label_html = render_component(&FilterManager.filter_label/1, label_assigns)

      input_assigns = %{
        column: column,
        current_value: nil,
        theme: theme,
        target: nil,
        filter_values: %{},
        table_id: "test-table"
      }

      input_html = render_component(&FilterManager.filter_input/1, input_assigns)

      # Label should point to from input
      assert label_html =~ ~r/for="test-table-filter-created_at-from"/
      # Both inputs should have ids
      assert input_html =~ ~r/id="test-table-filter-created_at-from"/
      assert input_html =~ ~r/id="test-table-filter-created_at-to"/
    end

    test "autocomplete filter label points to input", %{theme: theme} do
      column = %{
        field: "category",
        label: "Category",
        filter_type: :autocomplete,
        filter_options: [options: []]
      }

      label_assigns = %{column: column, table_id: "test-table", theme: theme}
      label_html = render_component(&FilterManager.filter_label/1, label_assigns)

      input_assigns = %{
        column: column,
        current_value: nil,
        theme: theme,
        target: nil,
        filter_values: %{},
        table_id: "test-table"
      }

      input_html = render_component(&FilterManager.filter_input/1, input_assigns)

      # Label should point to input (not container)
      assert label_html =~ ~r/for="test-table-filter-category"/
      # Input should have the expected id
      assert input_html =~ ~r/id="test-table-filter-category"/
      # Container should have different id
      assert input_html =~ ~r/id="test-table-filter-category-dropdown"/
    end

    test "boolean filter label has no for attribute", %{theme: theme} do
      column = %{field: "active", label: "Active", filter_type: :boolean, filter_options: []}

      label_assigns = %{column: column, table_id: "test-table", theme: theme}
      label_html = render_component(&FilterManager.filter_label/1, label_assigns)

      # Boolean labels should not have for attribute (inner labels work)
      refute label_html =~ ~r/for="/
    end
  end

  describe "custom filter labels" do
    setup do
      theme = Cinder.Theme.default()
      %{theme: theme}
    end

    test "filter label uses column label by default", %{theme: theme} do
      column = %{field: "name", label: "Full Name", filter_type: :text, filter_options: []}
      label_assigns = %{column: column, table_id: "test-table", theme: theme}

      html = render_component(&FilterManager.filter_label/1, label_assigns)

      assert html =~ "Full Name:"
    end

    test "filter label option overrides column label", %{theme: theme} do
      column = %{
        field: "printed_at",
        label: "Printed at (UTC)",
        filter_type: :date_range,
        filter_options: [label: "Printed at"]
      }

      label_assigns = %{column: column, table_id: "test-table", theme: theme}

      html = render_component(&FilterManager.filter_label/1, label_assigns)

      assert html =~ "Printed at:"
      refute html =~ "Printed at (UTC)"
    end

    test "filter label option works for text filters", %{theme: theme} do
      column = %{
        field: "email",
        label: "Email Address",
        filter_type: :text,
        filter_options: [label: "Email"]
      }

      label_assigns = %{column: column, table_id: "test-table", theme: theme}

      html = render_component(&FilterManager.filter_label/1, label_assigns)

      assert html =~ "Email:"
      refute html =~ "Email Address"
    end

    test "filter label handles nil filter_options gracefully", %{theme: theme} do
      column = %{field: "name", label: "Name", filter_type: :text, filter_options: nil}
      label_assigns = %{column: column, table_id: "test-table", theme: theme}

      html = render_component(&FilterManager.filter_label/1, label_assigns)

      assert html =~ "Name:"
    end
  end
end
