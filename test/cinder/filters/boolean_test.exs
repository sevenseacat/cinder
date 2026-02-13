defmodule Cinder.Filters.BooleanTest do
  use ExUnit.Case, async: true

  alias Cinder.Filters.Boolean
  alias TestResourceForInference

  describe "render/4 delegates to RadioGroup" do
    test "renders true/false radio buttons" do
      column = %{field: "active", filter_options: []}
      theme = Cinder.Theme.default()

      rendered = Boolean.render(column, nil, theme, %{})
      html = Phoenix.HTML.Safe.to_iodata(rendered) |> IO.iodata_to_binary()

      assert html =~ "True"
      assert html =~ "False"
      assert html =~ ~s(value="true")
      assert html =~ ~s(value="false")
      assert html =~ ~s(type="radio")
      assert html =~ ~s(name="filters[active]")
    end

    test "renders with custom labels" do
      column = %{
        field: "active",
        filter_options: [labels: %{true: "Yes", false: "No"}]
      }

      theme = Cinder.Theme.default()

      rendered = Boolean.render(column, nil, theme, %{})
      html = Phoenix.HTML.Safe.to_iodata(rendered) |> IO.iodata_to_binary()

      assert html =~ "Yes"
      assert html =~ "No"
      refute html =~ "True"
      refute html =~ "False"
    end

    test "uses radio_group theme keys" do
      column = %{field: "active", filter_options: []}
      theme = Cinder.Theme.default()

      rendered = Boolean.render(column, nil, theme, %{})
      html = Phoenix.HTML.Safe.to_iodata(rendered) |> IO.iodata_to_binary()

      assert html =~ "filter_radio_group_container_class"
      assert html =~ "filter_radio_group_radio_class"
    end

    test "marks current value as checked" do
      column = %{field: "active", filter_options: []}
      theme = Cinder.Theme.default()

      rendered = Boolean.render(column, "true", theme, %{})
      html = Phoenix.HTML.Safe.to_iodata(rendered) |> IO.iodata_to_binary()

      assert html =~ "checked"
    end
  end

  describe "Boolean filter build_query/3 for array fields" do
    setup do
      query = Ash.Query.new(TestResourceForInference)
      %{query: query}
    end

    test "creates containment filter for boolean array fields", %{query: query} do
      filter_value = %{
        type: :boolean,
        value: true,
        operator: :equals
      }

      result_query = Boolean.build_query(query, "tags", filter_value)

      # Should create: true in tags (not tags == true)
      assert match?(
               %Ash.Filter{
                 expression: %Ash.Query.Operator.In{
                   left: true,
                   operator: :in,
                   right: %{attribute: %{name: :tags}}
                 }
               },
               result_query.filter
             )
    end

    test "handles false values in array fields", %{query: query} do
      filter_value = %{
        type: :boolean,
        value: false,
        operator: :equals
      }

      result_query = Boolean.build_query(query, "tags", filter_value)

      # Should create: false in tags (not tags == false)
      assert match?(
               %Ash.Filter{
                 expression: %Ash.Query.Operator.In{
                   left: false,
                   operator: :in,
                   right: %{attribute: %{name: :tags}}
                 }
               },
               result_query.filter
             )
    end

    test "returns unchanged query for empty values on array fields", %{query: query} do
      filter_value = %{
        type: :boolean,
        value: nil,
        operator: :equals
      }

      result_query = Boolean.build_query(query, "tags", filter_value)

      # Empty values should not modify the query, even for array fields
      assert result_query == query
    end

    test "array vs non-array fields produce different query structures", %{query: query} do
      filter_value = %{
        type: :boolean,
        value: true,
        operator: :equals
      }

      # Non-array field should use equality
      bool_query = Boolean.build_query(query, "active", filter_value)

      # Array field should use containment
      array_query = Boolean.build_query(query, "tags", filter_value)

      # Should produce different filter structures
      refute bool_query.filter == array_query.filter

      # Array query should have containment structure
      assert match?(
               %Ash.Filter{
                 expression: %Ash.Query.Operator.In{
                   left: true,
                   operator: :in,
                   right: %{attribute: %{name: :tags}}
                 }
               },
               array_query.filter
             )
    end
  end

  # Note: Basic process/2, validate/1, empty?/1 functionality is tested in
  # test/cinder/configuration/filters_test.exs
end
