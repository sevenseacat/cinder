defmodule Cinder.Filters.SelectTest do
  use ExUnit.Case, async: true

  alias Cinder.Filters.Select
  alias TestResourceForInference

  describe "Select filter build_query/3 for array fields" do
    setup do
      query = Ash.Query.new(TestResourceForInference)
      %{query: query}
    end

    test "creates containment filter for array fields", %{query: query} do
      filter_value = %{
        type: :select,
        value: "tag1",
        operator: :equals
      }

      result_query = Select.build_query(query, "tags", filter_value)

      # Should create: "tag1" in tags (not tags == "tag1")
      assert match?(
               %Ash.Filter{
                 expression: %Ash.Query.Operator.In{
                   left: :tag1,
                   operator: :in,
                   right: %{attribute: %{name: :tags}}
                 }
               },
               result_query.filter
             )
    end

    test "returns unchanged query for empty values on array fields", %{query: query} do
      filter_value = %{
        type: :select,
        value: "",
        operator: :equals
      }

      result_query = Select.build_query(query, "tags", filter_value)

      # Empty values should not modify the query, even for array fields
      assert result_query == query
    end

    test "array vs non-array fields produce different query structures", %{query: query} do
      filter_value = %{
        type: :select,
        value: "tag2",
        operator: :equals
      }

      # Non-array field should use equality
      enum_query = Select.build_query(query, "status_enum", filter_value)

      # Array field should use containment
      array_query = Select.build_query(query, "tags", filter_value)

      # Should produce different filter structures
      refute enum_query.filter == array_query.filter

      # Array query should have containment structure
      assert match?(
               %Ash.Filter{
                 expression: %Ash.Query.Operator.In{
                   left: :tag2,
                   operator: :in,
                   right: %{attribute: %{name: :tags}}
                 }
               },
               array_query.filter
             )
    end
  end

  describe "Select filter render/4 prompt position" do
    test "lists the prompt before the options by default" do
      assert option_labels(select_column([])) == ["All Statuses", "Active", "Inactive"]
    end

    test "lists the prompt after the options with prompt_position: :last" do
      assert option_labels(select_column(prompt_position: :last)) ==
               ["Active", "Inactive", "All Statuses"]
    end

    test "keeps the prompt as the button label with prompt_position: :last" do
      html = render_html(select_column(prompt_position: :last), nil)

      assert html =~ ~r{<span class="placeholder truncate">All Statuses</span>}
    end
  end

  describe "Select filter prompt_value" do
    test "keeps the prompt value as a filter that narrows nothing" do
      column = select_column(prompt_value: "all")

      assert Select.process("all", column) == %{type: :select, value: "all", operator: :any}
      assert Select.validate(Select.process("all", column))
    end

    test "does not call the prompt value's filter empty" do
      refute Select.empty?(%{type: :select, value: "all", operator: :any})
    end

    test "still drops \"all\" when it is not the prompt value" do
      assert Select.process("all", select_column([])) == nil
    end

    test "leaves the query alone for the prompt value" do
      query = Ash.Query.new(TestResourceForInference)

      filter = %{type: :select, value: "all", operator: :any}

      assert Select.build_query(query, "status_enum", filter) == query
    end

    test "submits the prompt value from the prompt row and shows it chosen" do
      html = render_html(select_column(prompt_value: "all"), "all")

      assert html =~ ~r{<input type="radio" name="filters\[status\]" value="all" checked}
      assert html =~ ~r{<span class="\s*truncate">All Statuses</span>}
    end
  end

  defp select_column(extra_options) do
    %{
      field: "status",
      label: "Status",
      filter_options:
        [options: [{"Active", "active"}, {"Inactive", "inactive"}], prompt: "All Statuses"] ++
          extra_options
    }
  end

  defp option_labels(column) do
    ~r{<span class="label" data-key="filter_select_label_class">([^<]+)</span>}
    |> Regex.scan(render_html(column, nil), capture: :all_but_first)
    |> List.flatten()
  end

  defp render_html(column, current_value) do
    column
    |> Select.render(current_value, theme(), %{target: nil})
    |> Phoenix.HTML.Safe.to_iodata()
    |> IO.iodata_to_binary()
  end

  defp theme do
    %{
      filter_select_container_class: "container",
      filter_select_input_class: "input",
      filter_select_placeholder_class: "placeholder",
      filter_select_arrow_class: "",
      filter_select_dropdown_class: "dropdown",
      filter_select_option_class: "option",
      filter_select_label_class: "label",
      filter_select_empty_class: "empty"
    }
  end
end
