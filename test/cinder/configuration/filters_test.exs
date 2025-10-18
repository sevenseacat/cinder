defmodule Cinder.FiltersTest do
  use ExUnit.Case, async: true

  alias Cinder.Filters.{
    Registry,
    Text,
    Select,
    MultiSelect,
    DateRange,
    NumberRange,
    Boolean
  }

  alias Cinder.FilterManager

  describe "Cinder.Filter utilities" do
    test "has_filter_value?/1 correctly identifies empty values" do
      assert Cinder.Filter.has_filter_value?("test") == true
      assert Cinder.Filter.has_filter_value?(["option1"]) == true
      assert Cinder.Filter.has_filter_value?(%{min: "10", max: "20"}) == true

      assert Cinder.Filter.has_filter_value?("") == false
      assert Cinder.Filter.has_filter_value?(nil) == false
      assert Cinder.Filter.has_filter_value?([]) == false
      assert Cinder.Filter.has_filter_value?(%{from: "", to: ""}) == false
      assert Cinder.Filter.has_filter_value?(%{min: "", max: ""}) == false
      assert Cinder.Filter.has_filter_value?(%{from: nil, to: nil}) == false
      assert Cinder.Filter.has_filter_value?(%{min: nil, max: nil}) == false
    end

    test "humanize_key/1 converts keys to readable strings" do
      assert Cinder.Filter.humanize_key("user_name") == "User Name"
      assert Cinder.Filter.humanize_key("is_active") == "Is Active"
      assert Cinder.Filter.humanize_key("simple") == "Simple"
      assert Cinder.Filter.humanize_key(:atom_key) == "Atom Key"
    end

    test "humanize_atom/1 converts atoms to readable strings" do
      assert Cinder.Filter.humanize_atom(:active) == "Active"
      assert Cinder.Filter.humanize_atom(:super_admin) == "Super Admin"
      assert Cinder.Filter.humanize_atom(:draft_status) == "Draft Status"
    end

    test "get_option/3 retrieves nested values from filter options" do
      options = [operator: :contains, nested: [value: "test"]]

      assert Cinder.Filter.get_option(options, :operator) == :contains
      assert Cinder.Filter.get_option(options, [:nested, :value]) == "test"
      assert Cinder.Filter.get_option(options, :missing, "default") == "default"
      assert Cinder.Filter.get_option(options, :missing) == nil
    end

    test "field_name/2 generates correct form field names" do
      assert Cinder.Filter.field_name("title") == "filters[title]"
      assert Cinder.Filter.field_name("price", "min") == "filters[price_min]"
      assert Cinder.Filter.field_name("date", "from") == "filters[date_from]"
    end
  end

  describe "Cinder.Filters.Registry" do
    test "all_filters/0 returns map of all registered filter types" do
      filters = Registry.all_filters()

      assert filters[:text] == Text
      assert filters[:select] == Select
      assert filters[:multi_select] == MultiSelect
      assert filters[:multi_checkboxes] == Cinder.Filters.MultiCheckboxes
      assert filters[:date_range] == DateRange
      assert filters[:number_range] == NumberRange
      assert filters[:boolean] == Boolean
    end

    test "get_filter/1 returns correct module for filter type" do
      assert Registry.get_filter(:text) == Text
      assert Registry.get_filter(:boolean) == Boolean
      assert Registry.get_filter(:unknown) == nil
    end

    test "registered?/1 checks if filter type is registered" do
      assert Registry.registered?(:text) == true
      assert Registry.registered?(:number_range) == true
      assert Registry.registered?(:unknown) == false
    end

    test "filter_types/0 returns list of all registered types" do
      types = Registry.filter_types()

      assert :text in types
      assert :select in types
      assert :multi_select in types
      assert :multi_checkboxes in types
      assert :date_range in types
      assert :number_range in types
      assert :boolean in types
    end

    test "infer_filter_type/2 correctly infers types from Ash attributes" do
      # String type should infer to text
      string_attr = %{type: Ash.Type.String}
      assert Registry.infer_filter_type(string_attr) == :text

      # Boolean type should infer to boolean
      boolean_attr = %{type: Ash.Type.Boolean}
      assert Registry.infer_filter_type(boolean_attr) == :boolean

      # Integer type should infer to number_range
      integer_attr = %{type: Ash.Type.Integer}
      assert Registry.infer_filter_type(integer_attr) == :number_range

      # Date type should infer to date_range
      date_attr = %{type: Ash.Type.Date}
      assert Registry.infer_filter_type(date_attr) == :date_range

      # Constraint-based enum should infer to select
      enum_attr = %{type: :string, constraints: %{one_of: ["option1", "option2"]}}
      assert Registry.infer_filter_type(enum_attr) == :select

      # Unknown type should default to text
      unknown_attr = %{type: :unknown}
      assert Registry.infer_filter_type(unknown_attr) == :text

      # Nil attribute should default to text
      assert Registry.infer_filter_type(nil) == :text

      # Array type should infer to multi_select (tag-based interface)
      array_attr = %{type: {:array, :string}}
      assert Registry.infer_filter_type(array_attr) == :multi_select
    end

    test "default_options/2 returns correct defaults for each filter type" do
      text_defaults = Registry.default_options(:text)
      assert Keyword.get(text_defaults, :operator) == :contains
      assert Keyword.get(text_defaults, :case_sensitive) == false

      boolean_defaults = Registry.default_options(:boolean)
      labels = Keyword.get(boolean_defaults, :labels)
      assert labels[true] == "True"
      assert labels[false] == "False"
    end
  end

  describe "Cinder.Filters.Text" do
    test "process/2 handles text input correctly" do
      column = %{filter_options: [operator: :contains, case_sensitive: false]}

      result = Text.process("search term", column)

      assert result == %{
               type: :text,
               value: "search term",
               operator: :contains,
               case_sensitive: false
             }

      # Empty string should return nil
      assert Text.process("", column) == nil
      assert Text.process("   ", column) == nil
    end

    test "validate/1 validates text filter values" do
      valid_filter = %{type: :text, value: "test", operator: :contains}
      assert Text.validate(valid_filter) == true

      invalid_filter = %{type: :text, value: "test", operator: :invalid}
      assert Text.validate(invalid_filter) == false

      assert Text.validate(%{type: :select, value: "test"}) == false
    end

    test "empty?/1 correctly identifies empty text values" do
      assert Text.empty?(nil) == true
      assert Text.empty?("") == true
      assert Text.empty?(%{value: ""}) == true
      assert Text.empty?(%{value: nil}) == true

      assert Text.empty?("text") == false
      assert Text.empty?(%{value: "text"}) == false
    end
  end

  describe "Cinder.Filters.Select" do
    test "process/2 handles select input correctly" do
      column = %{filter_options: []}

      result = Select.process("option1", column)

      assert result == %{
               type: :select,
               value: "option1",
               operator: :equals
             }

      # Empty values should return nil
      assert Select.process("", column) == nil
    end

    test "validate/1 validates select filter values" do
      valid_filter = %{type: :select, value: "option1", operator: :equals}
      assert Select.validate(valid_filter) == true

      invalid_filter = %{type: :select, value: "", operator: :equals}
      assert Select.validate(invalid_filter) == false
    end

    test "empty?/1 correctly identifies empty select values" do
      assert Select.empty?(nil) == true
      assert Select.empty?("") == true
      assert Select.empty?(%{value: ""}) == true

      assert Select.empty?("option1") == false
      assert Select.empty?(%{value: "option1"}) == false
    end
  end

  describe "Cinder.Filters.MultiSelect" do
    test "process/2 handles multi-select input correctly" do
      column = %{filter_options: []}

      # List input
      result = MultiSelect.process(["option1", "option2"], column)

      assert result == %{
               type: :multi_select,
               value: ["option1", "option2"],
               operator: :in,
               match_mode: :any
             }

      # Single string input (converted to list)
      result = MultiSelect.process("option1", column)

      assert result == %{
               type: :multi_select,
               value: ["option1"],
               operator: :in,
               match_mode: :any
             }

      # Empty list should return nil
      assert MultiSelect.process([], column) == nil
      assert MultiSelect.process([""], column) == nil
    end

    test "validate/1 validates multi-select filter values" do
      valid_filter = %{type: :multi_select, value: ["option1", "option2"], operator: :in}
      assert MultiSelect.validate(valid_filter) == true

      invalid_filter = %{type: :multi_select, value: [], operator: :in}
      assert MultiSelect.validate(invalid_filter) == false
    end

    test "empty?/1 correctly identifies empty multi-select values" do
      assert MultiSelect.empty?(nil) == true
      assert MultiSelect.empty?([]) == true
      assert MultiSelect.empty?(%{value: []}) == true
      assert MultiSelect.empty?(%{value: nil}) == true

      assert MultiSelect.empty?(["option1"]) == false
      assert MultiSelect.empty?(%{value: ["option1"]}) == false
    end
  end

  describe "Cinder.Filters.MultiCheckboxes" do
    alias Cinder.Filters.MultiCheckboxes

    test "process/2 handles multi-checkbox input correctly" do
      column = %{field: "tags"}

      result = MultiCheckboxes.process(["option1", "option2"], column)

      assert result == %{
               type: :multi_checkboxes,
               value: ["option1", "option2"],
               operator: :in,
               match_mode: :any
             }

      result = MultiCheckboxes.process(["option1"], column)

      assert result == %{
               type: :multi_checkboxes,
               value: ["option1"],
               operator: :in,
               match_mode: :any
             }

      assert MultiCheckboxes.process([], column) == nil
      assert MultiCheckboxes.process([""], column) == nil
    end

    test "validate/1 validates multi-checkbox filter values" do
      valid_filter = %{type: :multi_checkboxes, value: ["option1", "option2"], operator: :in}
      assert MultiCheckboxes.validate(valid_filter) == true

      invalid_filter = %{type: :multi_checkboxes, value: [], operator: :in}
      assert MultiCheckboxes.validate(invalid_filter) == false
    end

    test "empty?/1 correctly identifies empty multi-checkbox values" do
      assert MultiCheckboxes.empty?(nil) == true
      assert MultiCheckboxes.empty?([]) == true
      assert MultiCheckboxes.empty?(%{value: []}) == true
      assert MultiCheckboxes.empty?(%{value: nil}) == true

      assert MultiCheckboxes.empty?(["option1"]) == false
      assert MultiCheckboxes.empty?(%{value: ["option1"]}) == false
    end
  end

  describe "Cinder.Filters.DateRange" do
    test "process/2 handles date range input correctly" do
      column = %{filter_options: []}

      # Comma-separated string
      result = DateRange.process("2024-01-01,2024-12-31", column)

      assert result == %{
               type: :date_range,
               value: %{from: "2024-01-01", to: "2024-12-31"},
               operator: :between
             }

      # Single date
      result = DateRange.process("2024-01-01", column)

      assert result == %{
               type: :date_range,
               value: %{from: "2024-01-01", to: ""},
               operator: :between
             }

      # Map input
      result = DateRange.process(%{from: "2024-01-01", to: "2024-12-31"}, column)

      assert result == %{
               type: :date_range,
               value: %{from: "2024-01-01", to: "2024-12-31"},
               operator: :between
             }

      # Empty values should return nil
      assert DateRange.process("", column) == nil
      assert DateRange.process(",", column) == nil
      assert DateRange.process(%{from: "", to: ""}, column) == nil
    end

    test "validate/1 validates date filter values with proper date format" do
      valid_filter = %{
        type: :date_range,
        value: %{from: "2024-01-01", to: "2024-12-31"},
        operator: :between
      }

      assert DateRange.validate(valid_filter) == true

      # Invalid date format
      invalid_filter = %{
        type: :date_range,
        value: %{from: "invalid-date", to: "2024-12-31"},
        operator: :between
      }

      assert DateRange.validate(invalid_filter) == false
    end

    test "validate/1 validates datetime filter values" do
      # Valid datetime format
      valid_datetime_filter = %{
        type: :date_range,
        value: %{from: "2024-01-01T10:30:00", to: "2024-12-31T15:45:00"},
        operator: :between
      }

      assert DateRange.validate(valid_datetime_filter) == true

      # Valid ISO datetime with timezone
      valid_iso_filter = %{
        type: :date_range,
        value: %{from: "2024-01-01T10:30:00Z", to: "2024-12-31T15:45:00Z"},
        operator: :between
      }

      assert DateRange.validate(valid_iso_filter) == true

      # Invalid datetime format
      invalid_datetime_filter = %{
        type: :date_range,
        value: %{from: "2024-01-01T25:00:00", to: "2024-12-31T15:45:00"},
        operator: :between
      }

      assert DateRange.validate(invalid_datetime_filter) == false
    end

    test "render/4 uses datetime-local inputs when include_time is true" do
      column = %{
        field: "created_at",
        filter_type: :date_range,
        filter_options: [include_time: true]
      }

      current_value = %{from: "2024-01-01", to: "2024-12-31"}
      theme = Cinder.Theme.default()

      rendered = DateRange.render(column, current_value, theme, %{})
      html = Phoenix.HTML.Safe.to_iodata(rendered) |> IO.iodata_to_binary()

      # Should contain datetime-local input types
      assert String.contains?(html, ~s(type="datetime-local"))
      # Should format dates as datetime-local format (YYYY-MM-DDTHH:MM)
      assert String.contains?(html, "2024-01-01T00:00")
      assert String.contains?(html, "2024-12-31T00:00")
    end

    test "render/4 uses date inputs when include_time is false or not specified" do
      column = %{
        field: "created_at",
        filter_type: :date_range,
        filter_options: [include_time: false]
      }

      current_value = %{from: "2024-01-01T10:30:00", to: "2024-12-31T15:45:00"}
      theme = Cinder.Theme.default()

      rendered = DateRange.render(column, current_value, theme, %{})
      html = Phoenix.HTML.Safe.to_iodata(rendered) |> IO.iodata_to_binary()

      # Should contain date input types
      assert String.contains?(html, ~s(type="date"))
      # Should extract only date part from datetime values
      assert String.contains?(html, ~s(value="2024-01-01"))
      assert String.contains?(html, ~s(value="2024-12-31"))
    end

    test "render/4 handles missing filter_options gracefully" do
      column = %{
        field: "created_at",
        filter_type: :date_range
      }

      current_value = %{from: "2024-01-01", to: "2024-12-31"}
      theme = Cinder.Theme.default()

      rendered = DateRange.render(column, current_value, theme, %{})
      html = Phoenix.HTML.Safe.to_iodata(rendered) |> IO.iodata_to_binary()

      # Should default to date input types
      assert String.contains?(html, ~s(type="date"))
    end

    test "default_options/0 includes include_time option" do
      options = DateRange.default_options()
      assert Keyword.get(options, :include_time) == false
    end

    test "empty?/1 correctly identifies empty date range values" do
      assert DateRange.empty?(nil) == true
      assert DateRange.empty?(%{value: %{from: "", to: ""}}) == true
      assert DateRange.empty?(%{from: "", to: ""}) == true
      assert DateRange.empty?(%{from: nil, to: nil}) == true

      assert DateRange.empty?(%{value: %{from: "2024-01-01", to: ""}}) == false
      assert DateRange.empty?(%{from: "2024-01-01", to: ""}) == false
    end
  end

  describe "Cinder.Filters.NumberRange" do
    test "process/2 handles number range input correctly" do
      column = %{filter_options: []}

      # Comma-separated string
      result = NumberRange.process("100,200", column)

      assert result == %{
               type: :number_range,
               value: %{min: "100", max: "200"},
               operator: :between
             }

      # Single number
      result = NumberRange.process("100", column)

      assert result == %{
               type: :number_range,
               value: %{min: "100", max: ""},
               operator: :between
             }

      # Map input
      result = NumberRange.process(%{min: "100", max: "200"}, column)

      assert result == %{
               type: :number_range,
               value: %{min: "100", max: "200"},
               operator: :between
             }

      # Empty values should return nil
      assert NumberRange.process("", column) == nil
      assert NumberRange.process(",", column) == nil
      assert NumberRange.process(%{min: "", max: ""}, column) == nil
    end

    test "validate/1 validates number filter values with proper number format" do
      valid_filter = %{
        type: :number_range,
        value: %{min: "100", max: "200"},
        operator: :between
      }

      assert NumberRange.validate(valid_filter) == true

      # Invalid number format
      invalid_filter = %{
        type: :number_range,
        value: %{min: "not-a-number", max: "200"},
        operator: :between
      }

      assert NumberRange.validate(invalid_filter) == false
    end

    test "empty?/1 correctly identifies empty number range values" do
      assert NumberRange.empty?(nil) == true
      assert NumberRange.empty?(%{value: %{min: "", max: ""}}) == true
      assert NumberRange.empty?(%{min: "", max: ""}) == true
      assert NumberRange.empty?(%{min: nil, max: nil}) == true

      assert NumberRange.empty?(%{value: %{min: "100", max: ""}}) == false
      assert NumberRange.empty?(%{min: "100", max: ""}) == false
    end
  end

  describe "Cinder.Filters.Boolean" do
    test "process/2 handles boolean input correctly" do
      column = %{filter_options: []}

      result = Boolean.process("true", column)

      assert result == %{
               type: :boolean,
               value: true,
               operator: :equals
             }

      result = Boolean.process("false", column)

      assert result == %{
               type: :boolean,
               value: false,
               operator: :equals
             }

      # Empty values should return nil
      assert Boolean.process("", column) == nil
    end

    test "validate/1 validates boolean filter values" do
      valid_true = %{type: :boolean, value: true, operator: :equals}
      assert Boolean.validate(valid_true) == true

      valid_false = %{type: :boolean, value: false, operator: :equals}
      assert Boolean.validate(valid_false) == true

      invalid_filter = %{type: :boolean, value: "string", operator: :equals}
      assert Boolean.validate(invalid_filter) == false
    end

    test "empty?/1 correctly identifies empty boolean values" do
      assert Boolean.empty?(nil) == true
      assert Boolean.empty?("") == true
      assert Boolean.empty?(%{value: nil}) == true

      assert Boolean.empty?(true) == false
      assert Boolean.empty?(false) == false
      assert Boolean.empty?(%{value: true}) == false
    end
  end

  describe "FilterManager integration with modular filters" do
    test "process_filter_params/2 correctly combines range inputs" do
      # Test number range combination
      filter_params = %{
        "value_min" => "100",
        "value_max" => "200",
        "other_field" => "test"
      }

      columns = [
        %{field: "value", filterable: true, filter_type: :number_range},
        %{field: "other_field", filterable: true, filter_type: :text}
      ]

      result = FilterManager.process_filter_params(filter_params, columns)

      assert result["value"] == "100,200"
      assert result["other_field"] == "test"
      refute Map.has_key?(result, "value_min")
      refute Map.has_key?(result, "value_max")
    end

    test "process_filter_params/2 correctly combines date range inputs" do
      filter_params = %{
        "created_at_from" => "2024-01-01",
        "created_at_to" => "2024-12-31",
        "title" => "test"
      }

      columns = [
        %{field: "created_at", filterable: true, filter_type: :date_range},
        %{field: "title", filterable: true, filter_type: :text}
      ]

      result = FilterManager.process_filter_params(filter_params, columns)

      assert result["created_at"] == "2024-01-01,2024-12-31"
      assert result["title"] == "test"
      refute Map.has_key?(result, "created_at_from")
      refute Map.has_key?(result, "created_at_to")
    end

    test "params_to_filters/2 delegates to correct filter modules" do
      filter_params = %{
        "title" => "search term",
        "status" => "active",
        "tags" => ["tag1", "tag2"],
        "categories" => ["cat1", "cat2"],
        "price" => "100,200",
        "created_at" => "2024-01-01,2024-12-31",
        "featured" => "true"
      }

      columns = [
        %{field: "title", filterable: true, filter_type: :text, filter_options: []},
        %{field: "status", filterable: true, filter_type: :select, filter_options: []},
        %{field: "tags", filterable: true, filter_type: :multi_select, filter_options: []},
        %{
          field: "categories",
          filterable: true,
          filter_type: :multi_checkboxes,
          filter_options: []
        },
        %{field: "price", filterable: true, filter_type: :number_range, filter_options: []},
        %{field: "created_at", filterable: true, filter_type: :date_range, filter_options: []},
        %{field: "featured", filterable: true, filter_type: :boolean, filter_options: []}
      ]

      result = FilterManager.params_to_filters(filter_params, columns)

      # Text filter
      assert result["title"] == %{
               type: :text,
               value: "search term",
               operator: :contains,
               case_sensitive: false
             }

      # Select filter
      assert result["status"] == %{
               type: :select,
               value: "active",
               operator: :equals
             }

      # Multi-select filter
      assert result["tags"] == %{
               type: :multi_select,
               value: ["tag1", "tag2"],
               operator: :in,
               match_mode: :any
             }

      assert result["categories"] == %{
               type: :multi_checkboxes,
               value: ["cat1", "cat2"],
               operator: :in,
               match_mode: :any
             }

      # Number range filter (combined from min/max)
      assert result["price"] == %{
               type: :number_range,
               value: %{min: "100", max: "200"},
               operator: :between
             }

      # Date range filter (combined from from/to)
      assert result["created_at"] == %{
               type: :date_range,
               value: %{from: "2024-01-01", to: "2024-12-31"},
               operator: :between
             }

      # Boolean filter
      assert result["featured"] == %{
               type: :boolean,
               value: true,
               operator: :equals
             }
    end

    test "build_filter_values/2 formats filters for form display" do
      filters = %{
        "title" => %{type: :text, value: "search term"},
        "price" => %{type: :number_range, value: %{min: "100", max: "200"}},
        "created_at" => %{type: :date_range, value: %{from: "2024-01-01", to: "2024-12-31"}},
        "tags" => %{type: :multi_select, value: ["tag1", "tag2"]},
        "categories" => %{type: :multi_checkboxes, value: ["cat1", "cat2"]},
        "featured" => %{type: :boolean, value: true}
      }

      columns = [
        %{field: "title", filterable: true, filter_type: :text},
        %{field: "price", filterable: true, filter_type: :number_range},
        %{field: "created_at", filterable: true, filter_type: :date_range},
        %{field: "tags", filterable: true, filter_type: :multi_select},
        %{field: "categories", filterable: true, filter_type: :multi_checkboxes},
        %{field: "featured", filterable: true, filter_type: :boolean},
        %{field: "empty_field", filterable: true, filter_type: :text}
      ]

      result = FilterManager.build_filter_values(columns, filters)

      # Text filter
      assert result["title"] == "search term"

      # Number range filter
      assert result["price"] == %{min: "100", max: "200"}

      # Date range filter
      assert result["created_at"] == %{from: "2024-01-01", to: "2024-12-31"}

      # Multi-select filter
      assert result["tags"] == ["tag1", "tag2"]

      # Boolean filter (returns string for form display)
      assert result["featured"] == "true"

      # Empty field gets default value
      assert result["empty_field"] == ""
    end

    test "infer_filter_config/3 uses Registry for type inference" do
      # Mock an Ash resource attribute
      key = "price"
      # We'll simulate this
      resource = nil
      slot = %{filterable: true}

      # Test with explicit filter type (should not infer)
      slot_with_type = Map.put(slot, :filter_type, :text)
      result = FilterManager.infer_filter_config(key, resource, slot_with_type)
      assert result.filter_type == :text

      # Test with non-filterable (should return defaults)
      non_filterable_slot = %{filterable: false}
      result = FilterManager.infer_filter_config(key, resource, non_filterable_slot)
      assert result.filter_type == :text
    end

    test "clear_filter/2 removes specific filter" do
      filters = %{
        "title" => %{type: :text, value: "test"},
        "price" => %{type: :number_range, value: %{min: "100", max: "200"}}
      }

      result = FilterManager.clear_filter(filters, "title")

      refute Map.has_key?(result, "title")
      assert Map.has_key?(result, "price")
    end

    test "clear_all_filters/1 removes all filters" do
      filters = %{
        "title" => %{type: :text, value: "test"},
        "price" => %{type: :number_range, value: %{min: "100", max: "200"}}
      }

      result = FilterManager.clear_all_filters(filters)
      assert result == %{}
    end

    test "count_active_filters/1 counts non-empty filters" do
      filters = %{
        "title" => %{type: :text, value: "test"},
        "price" => %{type: :number_range, value: %{min: "100", max: "200"}},
        "empty" => %{type: :text, value: ""}
      }

      result = FilterManager.count_active_filters(filters)
      # Counts all entries, empty check is done elsewhere
      assert result == 3
    end
  end

  describe "Real-world scenarios" do
    test "complete number range filter workflow" do
      # Simulate the exact scenario from the user's issue
      form_data = %{
        "_target" => ["filters", "value_max"],
        "filters" => %{
          "_unused_name" => "",
          "name" => "",
          "type" => "",
          "value_max" => "200",
          "value_min" => "100"
        }
      }

      columns = [
        %{
          field: "value",
          label: "Value",
          filterable: true,
          filter_type: :number_range,
          filter_options: []
        }
      ]

      filter_params = form_data["filters"]

      # Step 1: Process filter params (combine min/max)
      processed = FilterManager.process_filter_params(filter_params, columns)
      assert processed["value"] == "100,200"

      # Step 2: Convert to structured filters
      filters = FilterManager.params_to_filters(filter_params, columns)

      expected_filter = %{
        type: :number_range,
        value: %{min: "100", max: "200"},
        operator: :between
      }

      assert filters["value"] == expected_filter

      # Step 3: Verify filter would be properly applied
      assert FilterManager.has_filter_value?(filters["value"])
      assert NumberRange.validate(filters["value"])
      refute NumberRange.empty?(filters["value"])
    end

    test "mixed filter types workflow" do
      # Test a realistic form with multiple filter types
      filter_params = %{
        # text
        "name" => "weapon",
        # select
        "type" => "sword",
        # multi-select
        "rarity" => ["rare", "epic"],
        # multi-checkboxes
        "tags" => ["weapon", "melee"],
        # number range
        "damage_min" => "50",
        "damage_max" => "100",
        # date range
        "crafted_from" => "2024-01-01",
        "crafted_to" => "2024-12-31",
        # boolean
        "magical" => "true"
      }

      columns = [
        %{field: "name", filterable: true, filter_type: :text, filter_options: []},
        %{field: "type", filterable: true, filter_type: :select, filter_options: []},
        %{field: "rarity", filterable: true, filter_type: :multi_select, filter_options: []},
        %{field: "tags", filterable: true, filter_type: :multi_checkboxes, filter_options: []},
        %{field: "damage", filterable: true, filter_type: :number_range, filter_options: []},
        %{field: "crafted", filterable: true, filter_type: :date_range, filter_options: []},
        %{field: "magical", filterable: true, filter_type: :boolean, filter_options: []}
      ]

      result = FilterManager.params_to_filters(filter_params, columns)

      # All filters should be processed correctly
      assert result["name"][:type] == :text
      assert result["type"][:type] == :select
      assert result["rarity"][:type] == :multi_select
      assert result["tags"][:type] == :multi_checkboxes
      assert result["damage"][:type] == :number_range
      assert result["crafted"][:type] == :date_range
      assert result["magical"][:type] == :boolean

      # Verify specific values
      assert result["damage"][:value] == %{min: "50", max: "100"}
      assert result["crafted"][:value] == %{from: "2024-01-01", to: "2024-12-31"}
      assert result["rarity"][:value] == ["rare", "epic"]
      assert result["magical"][:value] == true
    end
  end
end
