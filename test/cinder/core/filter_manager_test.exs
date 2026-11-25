defmodule Cinder.FilterManagerRuntimeTest do
  use ExUnit.Case, async: false
  import ExUnit.CaptureLog
  import Cinder.TestHelpers, only: [put_app_env: 2]

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
    # Start every test with no custom filters registered
    put_app_env(:filters, [])
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

    test "skips the filter when a custom filter's processing raises" do
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

          # A bug in the filter fails closed: no filter, rather than a different one
          assert result == nil
        end)

      assert log_output =~ "Error processing filter value for custom filter :broken"
      assert log_output =~ "Skipping it"
    end

    test "skips the filter when a custom filter module is missing" do
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

          # A bug in the filter fails closed: no filter, rather than a different one
          assert result == nil
        end)

      assert log_output =~ "Error processing filter value for custom filter :missing"
      assert log_output =~ "Skipping it"
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

  describe "integration with built-in filter system" do
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

  # Regression: a form event could post any number of multi-select values, each one
  # part of the query, just as a URL could
  test "params_to_filters/2 trims a form's multi-select values to the filter's options" do
    columns = [
      %{
        field: "tags",
        filterable: true,
        filter_type: :multi_checkboxes,
        filter_options: [options: [{"A", "a"}, {"B", "b"}]]
      }
    ]

    params = %{"tags" => ["b", "a", "b"] ++ Enum.map(1..1000, &"junk#{&1}")}

    assert %{"tags" => %{value: ["b", "a"]}} = FilterManager.params_to_filters(params, columns)
  end
end
