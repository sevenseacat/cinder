defmodule Cinder.Filters.CheckboxTest do
  use ExUnit.Case, async: true

  alias Cinder.Filters.Checkbox
  alias TestResourceForInference

  describe "process/2" do
    test "returns nil for empty string" do
      column = %{field: :published, filter_options: [label: "Published only"]}
      assert Checkbox.process("", column) == nil
    end

    test "returns nil for whitespace string" do
      column = %{field: :published, filter_options: [label: "Published only"]}
      assert Checkbox.process("   ", column) == nil
    end

    test "returns nil for non-matching value" do
      column = %{field: :published, filter_options: [label: "Published only", value: "published"]}
      assert Checkbox.process("draft", column) == nil
    end

    test "processes matching boolean value" do
      column = %{field: :published, filter_options: [label: "Published only", value: true]}
      result = Checkbox.process("true", column)

      assert result == %{
               type: :checkbox,
               value: true,
               operator: :equals
             }
    end

    test "processes explicit string value" do
      column = %{field: :status, filter_options: [label: "Published only", value: "published"]}
      result = Checkbox.process("published", column)

      assert result == %{
               type: :checkbox,
               value: "published",
               operator: :equals
             }
    end

    test "processes integer value" do
      column = %{field: :priority, filter_options: [label: "High priority", value: 1]}
      result = Checkbox.process("1", column)

      assert result == %{
               type: :checkbox,
               value: 1,
               operator: :equals
             }
    end

    test "processes false value correctly" do
      column = %{field: :scroll, filter_options: [label: "Books only", value: false]}
      result = Checkbox.process("false", column)

      assert result == %{
               type: :checkbox,
               value: false,
               operator: :equals
             }
    end

    test "returns nil for non-binary input" do
      column = %{field: :published, filter_options: [label: "Published only"]}
      assert Checkbox.process(nil, column) == nil
      assert Checkbox.process([], column) == nil
      assert Checkbox.process(%{}, column) == nil
    end
  end

  describe "validate/1" do
    test "returns true for valid checkbox filter structure" do
      filter = %{type: :checkbox, value: true, operator: :equals}
      assert Checkbox.validate(filter) == true
    end

    test "returns true for valid string value" do
      filter = %{type: :checkbox, value: "published", operator: :equals}
      assert Checkbox.validate(filter) == true
    end

    test "returns true for valid integer value" do
      filter = %{type: :checkbox, value: 1, operator: :equals}
      assert Checkbox.validate(filter) == true
    end

    test "returns false for wrong type" do
      filter = %{type: :text, value: true, operator: :equals}
      assert Checkbox.validate(filter) == false
    end

    test "returns false for wrong operator" do
      filter = %{type: :checkbox, value: true, operator: :contains}
      assert Checkbox.validate(filter) == false
    end

    test "returns false for missing fields" do
      assert Checkbox.validate(%{type: :checkbox, value: true}) == false
      assert Checkbox.validate(%{value: true, operator: :equals}) == false
      assert Checkbox.validate(%{type: :checkbox, operator: :equals}) == false
    end

    test "returns false for completely invalid input" do
      assert Checkbox.validate(nil) == false
      assert Checkbox.validate("invalid") == false
      assert Checkbox.validate([]) == false
    end
  end

  describe "empty?/1" do
    test "returns true for nil" do
      assert Checkbox.empty?(nil) == true
    end

    test "returns true for empty string" do
      assert Checkbox.empty?("") == true
    end

    test "returns true for filter with nil value" do
      assert Checkbox.empty?(%{value: nil}) == true
    end

    test "returns false for valid filter value" do
      assert Checkbox.empty?("true") == false
      assert Checkbox.empty?("published") == false
    end

    test "returns false for valid filter structure" do
      filter = %{type: :checkbox, value: true, operator: :equals}
      assert Checkbox.empty?(filter) == false
    end
  end

  describe "default_options/0" do
    test "returns default options" do
      options = Checkbox.default_options()
      assert is_list(options)
      assert Keyword.get(options, :label) == ""
      assert Keyword.get(options, :value) == true
    end
  end

  describe "render/4" do
    setup do
      theme = %{
        filter_checkbox_container_class: "checkbox-container",
        filter_checkbox_container_data: [],
        filter_checkbox_input_class: "checkbox-input",
        filter_checkbox_input_data: [],
        filter_checkbox_label_class: "checkbox-label",
        filter_checkbox_label_data: []
      }

      %{theme: theme}
    end

    test "raises error when label is missing and no column label", %{theme: theme} do
      column = %{field: :published, filter_options: []}

      assert_raise ArgumentError,
                   ~r/requires either a 'label' option or column must have a label/,
                   fn ->
                     Cinder.Filters.Checkbox.render(column, nil, theme, %{})
                   end
    end

    test "raises error when label is empty string and no column label", %{theme: theme} do
      column = %{field: :published, filter_options: [label: ""]}

      assert_raise ArgumentError,
                   ~r/requires either a 'label' option or column must have a label/,
                   fn ->
                     Cinder.Filters.Checkbox.render(column, nil, theme, %{})
                   end
    end

    test "renders unchecked checkbox for boolean field", %{theme: theme} do
      column = %{
        field: :published,
        filter_options: [label: "Published only"],
        filter_type: :boolean
      }

      html = Checkbox.render(column, nil, theme, %{})
      html_string = Phoenix.HTML.Safe.to_iodata(html) |> IO.iodata_to_binary()

      assert html_string =~ ~r/type="checkbox"/
      assert html_string =~ ~r/name="filters\[published\]"/
      assert html_string =~ ~r/value="true"/
      refute html_string =~ ~r/checked/
      assert html_string =~ "Published only"
    end

    test "renders checked checkbox when current value matches", %{theme: theme} do
      column = %{
        field: :published,
        filter_options: [label: "Published only"],
        filter_type: :boolean
      }

      html = Checkbox.render(column, "true", theme, %{})
      html_string = Phoenix.HTML.Safe.to_iodata(html) |> IO.iodata_to_binary()

      assert html_string =~ ~r/checked/
    end

    test "renders checkbox with explicit value", %{theme: theme} do
      column = %{field: :status, filter_options: [label: "Published only", value: "published"]}

      html = Checkbox.render(column, nil, theme, %{})
      html_string = Phoenix.HTML.Safe.to_iodata(html) |> IO.iodata_to_binary()

      assert html_string =~ ~r/value="published"/
      refute html_string =~ ~r/checked/
    end

    test "renders checked when current value matches explicit value", %{theme: theme} do
      column = %{field: :status, filter_options: [label: "Published only", value: "published"]}

      html = Checkbox.render(column, "published", theme, %{})
      html_string = Phoenix.HTML.Safe.to_iodata(html) |> IO.iodata_to_binary()

      assert html_string =~ ~r/checked/
    end

    test "applies theme classes", %{theme: theme} do
      column = %{
        field: :published,
        filter_options: [label: "Published only"],
        filter_type: :boolean
      }

      html = Checkbox.render(column, nil, theme, %{})
      html_string = Phoenix.HTML.Safe.to_iodata(html) |> IO.iodata_to_binary()

      assert html_string =~ "checkbox-container"
      assert html_string =~ "checkbox-input"
      assert html_string =~ "checkbox-label"
    end

    test "raises error for non-boolean field without explicit value", %{theme: theme} do
      column = %{field: :status, filter_options: [label: "Published only"], filter_type: :text}

      assert_raise ArgumentError, ~r/requires explicit 'value' option/, fn ->
        Checkbox.render(column, nil, theme, %{})
      end
    end

    test "works with boolean field type inference", %{theme: theme} do
      column = %{
        field: :published,
        filter_options: [label: "Published only"],
        filter_type: :boolean
      }

      html = Checkbox.render(column, nil, theme, %{})
      html_string = Phoenix.HTML.Safe.to_iodata(html) |> IO.iodata_to_binary()

      assert html_string =~ ~r/value="true"/
    end

    test "uses column label when no explicit label provided", %{theme: theme} do
      column = %{
        field: :published,
        label: "Published Status",
        filter_options: [],
        filter_type: :boolean
      }

      html = Checkbox.render(column, nil, theme, %{})
      html_string = Phoenix.HTML.Safe.to_iodata(html) |> IO.iodata_to_binary()

      assert html_string =~ "Published Status"
      refute html_string =~ "Published only"
    end

    test "explicit label takes precedence over column label", %{theme: theme} do
      column = %{
        field: :published,
        label: "Published Status",
        filter_options: [label: "Show published only"],
        filter_type: :boolean
      }

      html = Checkbox.render(column, nil, theme, %{})
      html_string = Phoenix.HTML.Safe.to_iodata(html) |> IO.iodata_to_binary()

      assert html_string =~ "Show published only"
      refute html_string =~ "Published Status"
    end

    test "handles value: false correctly without error", %{theme: theme} do
      column = %{
        field: :scroll,
        filter_options: [label: "Books only", value: false]
      }

      html = Checkbox.render(column, nil, theme, %{})
      html_string = Phoenix.HTML.Safe.to_iodata(html) |> IO.iodata_to_binary()

      assert html_string =~ ~r/value="false"/
      assert html_string =~ "Books only"
      refute html_string =~ ~r/checked/
    end
  end

  describe "integration with FilterManager - reproducing bug" do
    test "checkbox filter processes correctly through full pipeline" do
      # This test reproduces the bug reported where checkbox filter
      # doesn't apply on first click

      # Simulate a checkbox filter column for track_count field
      column = %{
        field: "track_count",
        filterable: true,
        filter_type: :checkbox,
        filter_options: [label: "Has 8+ tracks", value: 8]
      }

      # Simulate form parameters from a checked checkbox
      raw_value = "8"  # This is what comes from the form

      # Process the raw value through the checkbox filter
      processed = Checkbox.process(raw_value, column)

      # Should return proper filter structure
      assert processed == %{
        type: :checkbox,
        value: 8,
        operator: :equals
      }

      # Validate the processed filter
      assert Checkbox.validate(processed) == true

      # Ensure it's not considered empty
      assert Checkbox.empty?(processed) == false
    end

    test "checkbox filter returns nil when unchecked" do
      column = %{
        field: "track_count",
        filterable: true,
        filter_type: :checkbox,
        filter_options: [label: "Has 8+ tracks", value: 8]
      }

      # When checkbox is unchecked, no value is sent
      processed = Checkbox.process("", column)

      # Should return nil to remove the filter
      assert processed == nil
    end

    test "checkbox filter handles mismatched values" do
      column = %{
        field: "track_count",
        filterable: true,
        filter_type: :checkbox,
        filter_options: [label: "Has 8+ tracks", value: 8]
      }

      # If somehow a different value comes through
      processed = Checkbox.process("5", column)

      # Should return nil since it doesn't match the expected value
      assert processed == nil
    end
  end
end
