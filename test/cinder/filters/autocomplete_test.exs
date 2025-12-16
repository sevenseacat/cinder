defmodule Cinder.Filters.AutocompleteTest do
  use ExUnit.Case, async: true

  alias Cinder.Filters.Autocomplete

  describe "process/2" do
    test "processes valid string value" do
      column = %{field: "category_id", filter_options: []}

      result = Autocomplete.process("123", column)

      assert result == %{
               type: :autocomplete,
               value: "123",
               operator: :equals
             }
    end

    test "returns nil for empty string" do
      column = %{field: "category_id", filter_options: []}

      assert Autocomplete.process("", column) == nil
    end

    test "returns nil for whitespace-only string" do
      column = %{field: "category_id", filter_options: []}

      assert Autocomplete.process("   ", column) == nil
    end

    test "trims whitespace from value" do
      column = %{field: "category_id", filter_options: []}

      result = Autocomplete.process("  abc  ", column)

      assert result.value == "abc"
    end

    test "returns nil for non-binary values" do
      column = %{field: "category_id", filter_options: []}

      assert Autocomplete.process(nil, column) == nil
      assert Autocomplete.process(123, column) == nil
      assert Autocomplete.process([], column) == nil
    end
  end

  describe "validate/1" do
    test "validates correct filter structure" do
      valid_filter = %{type: :autocomplete, value: "123", operator: :equals}

      assert Autocomplete.validate(valid_filter) == true
    end

    test "rejects filter with empty value" do
      invalid_filter = %{type: :autocomplete, value: "", operator: :equals}

      assert Autocomplete.validate(invalid_filter) == false
    end

    test "rejects filter with wrong type" do
      invalid_filter = %{type: :select, value: "123", operator: :equals}

      assert Autocomplete.validate(invalid_filter) == false
    end

    test "rejects filter with wrong operator" do
      invalid_filter = %{type: :autocomplete, value: "123", operator: :contains}

      assert Autocomplete.validate(invalid_filter) == false
    end

    test "rejects nil value" do
      assert Autocomplete.validate(nil) == false
    end

    test "rejects non-map values" do
      assert Autocomplete.validate("string") == false
      assert Autocomplete.validate(123) == false
    end
  end

  describe "empty?/1" do
    test "returns true for nil" do
      assert Autocomplete.empty?(nil) == true
    end

    test "returns true for empty string" do
      assert Autocomplete.empty?("") == true
    end

    test "returns true for map with empty value" do
      assert Autocomplete.empty?(%{value: ""}) == true
    end

    test "returns true for map with nil value" do
      assert Autocomplete.empty?(%{value: nil}) == true
    end

    test "returns false for non-empty value" do
      assert Autocomplete.empty?(%{value: "123"}) == false
    end

    test "returns false for non-empty string" do
      assert Autocomplete.empty?("123") == false
    end
  end

  describe "default_options/0" do
    test "returns expected default options" do
      defaults = Autocomplete.default_options()

      assert defaults[:options] == []
      assert defaults[:placeholder] == nil
      assert defaults[:max_results] == 10
    end
  end

  describe "build_query/3" do
    defmodule TestResource do
      use Ash.Resource,
        domain: Cinder.Filters.AutocompleteTest.TestDomain,
        data_layer: Ash.DataLayer.Ets

      attributes do
        uuid_primary_key(:id)
        attribute(:category_id, :string, public?: true)
        attribute(:name, :string, public?: true)
      end

      actions do
        defaults([:read, create: [:category_id, :name]])
      end
    end

    defmodule TestDomain do
      use Ash.Domain, validate_config_inclusion?: false

      resources do
        resource(TestResource)
      end
    end

    test "builds equals filter for simple field" do
      query = Ash.Query.new(TestResource)
      filter_value = %{type: :autocomplete, value: "electronics", operator: :equals}

      result = Autocomplete.build_query(query, "category_id", filter_value)

      assert %Ash.Query{} = result
    end

    test "handles string field names" do
      query = Ash.Query.new(TestResource)
      filter_value = %{type: :autocomplete, value: "123", operator: :equals}

      result = Autocomplete.build_query(query, "category_id", filter_value)

      assert %Ash.Query{} = result
    end
  end

  describe "render/4" do
    test "renders with static options" do
      column = %{
        field: "category_id",
        label: "Category",
        filter_options: [
          options: [{"Electronics", "1"}, {"Clothing", "2"}, {"Books", "3"}],
          placeholder: "Search categories..."
        ]
      }

      theme = %{
        filter_select_container_class: "container",
        filter_text_input_class: "input",
        filter_text_input_data: [],
        filter_select_dropdown_class: "dropdown",
        filter_select_dropdown_data: [],
        filter_select_option_class: "option",
        filter_select_option_data: [],
        filter_select_label_class: "label",
        filter_select_label_data: [],
        filter_select_empty_class: "empty",
        filter_select_empty_data: []
      }

      assigns = %{target: nil, raw_filter_params: %{}}

      result = Autocomplete.render(column, nil, theme, assigns)

      # Verify it returns rendered HEEx
      assert %Phoenix.LiveView.Rendered{} = result

      # Convert to string and check for key elements
      html = Phoenix.HTML.Safe.to_iodata(result) |> IO.iodata_to_binary()

      assert html =~ "Search categories..."
      assert html =~ "Electronics"
      assert html =~ "Clothing"
      assert html =~ "Books"
      # Check for JS commands for dropdown show/hide
      assert html =~ "phx-focus"
      assert html =~ "phx-click-away"
      # Check for radio button inputs (like select filter)
      assert html =~ "type=\"radio\""
    end

    test "renders with current value showing label" do
      column = %{
        field: "category_id",
        label: "Category",
        filter_options: [
          options: [{"Electronics", "1"}, {"Clothing", "2"}, {"Books", "3"}]
        ]
      }

      theme = %{
        filter_select_container_class: "container",
        filter_text_input_class: "input",
        filter_text_input_data: [],
        filter_select_dropdown_class: "dropdown",
        filter_select_dropdown_data: [],
        filter_select_option_class: "option",
        filter_select_option_data: [],
        filter_select_label_class: "label",
        filter_select_label_data: [],
        filter_select_empty_class: "empty",
        filter_select_empty_data: []
      }

      assigns = %{target: nil, raw_filter_params: %{}}

      result = Autocomplete.render(column, "2", theme, assigns)

      html = Phoenix.HTML.Safe.to_iodata(result) |> IO.iodata_to_binary()

      # Should show "Clothing" as the input value since value "2" maps to that label
      assert html =~ ~s(value="Clothing")
      # Hidden input should have the actual value
      assert html =~ ~s(value="2")
    end

    test "filters options based on search term" do
      column = %{
        field: "category_id",
        label: "Category",
        filter_options: [
          options: [{"Electronics", "1"}, {"Clothing", "2"}, {"Books", "3"}]
        ]
      }

      theme = %{
        filter_select_container_class: "container",
        filter_text_input_class: "input",
        filter_text_input_data: [],
        filter_select_dropdown_class: "dropdown",
        filter_select_dropdown_data: [],
        filter_select_option_class: "option",
        filter_select_option_data: [],
        filter_select_label_class: "label",
        filter_select_label_data: [],
        filter_select_empty_class: "empty",
        filter_select_empty_data: []
      }

      # Search for "elec" should only match Electronics
      assigns = %{target: nil, raw_filter_params: %{"category_id_autocomplete_search" => "elec"}}

      result = Autocomplete.render(column, nil, theme, assigns)

      html = Phoenix.HTML.Safe.to_iodata(result) |> IO.iodata_to_binary()

      assert html =~ "Electronics"
      refute html =~ ">Clothing<"
      refute html =~ ">Books<"
    end

    test "shows no results message when filtered options are empty" do
      column = %{
        field: "category_id",
        label: "Category",
        filter_options: [
          options: [{"Electronics", "1"}]
        ]
      }

      theme = %{
        filter_select_container_class: "container",
        filter_text_input_class: "input",
        filter_text_input_data: [],
        filter_select_dropdown_class: "dropdown",
        filter_select_dropdown_data: [],
        filter_select_option_class: "option",
        filter_select_option_data: [],
        filter_select_label_class: "label",
        filter_select_label_data: [],
        filter_select_empty_class: "empty",
        filter_select_empty_data: []
      }

      # Simulate a search that matches nothing
      assigns = %{target: nil, raw_filter_params: %{"category_id_autocomplete_search" => "xyz"}}

      result = Autocomplete.render(column, nil, theme, assigns)

      html = Phoenix.HTML.Safe.to_iodata(result) |> IO.iodata_to_binary()

      # No results message should be visible
      assert html =~ "No results found"
    end

    test "limits rendered options to max_results" do
      options = Enum.map(1..20, fn i -> {"Option #{i}", "#{i}"} end)

      column = %{
        field: "category_id",
        label: "Category",
        filter_options: [
          options: options,
          max_results: 5
        ]
      }

      theme = %{
        filter_select_container_class: "container",
        filter_text_input_class: "input",
        filter_text_input_data: [],
        filter_select_dropdown_class: "dropdown",
        filter_select_dropdown_data: [],
        filter_select_option_class: "option",
        filter_select_option_data: [],
        filter_select_label_class: "label",
        filter_select_label_data: [],
        filter_select_empty_class: "empty",
        filter_select_empty_data: []
      }

      assigns = %{target: nil, raw_filter_params: %{}}

      result = Autocomplete.render(column, nil, theme, assigns)

      html = Phoenix.HTML.Safe.to_iodata(result) |> IO.iodata_to_binary()

      # Only first 5 options rendered (server-side limiting)
      assert html =~ "Option 1"
      assert html =~ "Option 5"
      refute html =~ "Option 6"
      refute html =~ "Option 20"
      # "More" hint shown when there are more options
      assert html =~ "Type to search more options"
    end

    test "uses label and radio button elements for options like select filter" do
      column = %{
        field: "category_id",
        label: "Category",
        filter_options: [
          options: [{"Electronics", "1"}]
        ]
      }

      theme = %{
        filter_select_container_class: "container",
        filter_text_input_class: "input",
        filter_text_input_data: [],
        filter_select_dropdown_class: "dropdown",
        filter_select_dropdown_data: [],
        filter_select_option_class: "option",
        filter_select_option_data: [],
        filter_select_label_class: "label",
        filter_select_label_data: [],
        filter_select_empty_class: "empty",
        filter_select_empty_data: []
      }

      assigns = %{target: nil, raw_filter_params: %{}}

      result = Autocomplete.render(column, "1", theme, assigns)

      html = Phoenix.HTML.Safe.to_iodata(result) |> IO.iodata_to_binary()

      # Options should use label elements with radio buttons like select filter
      assert html =~ "<label"
      assert html =~ "flex items-center cursor-pointer"
      assert html =~ "type=\"radio\""
      assert html =~ "class=\"sr-only\""
    end
  end
end
