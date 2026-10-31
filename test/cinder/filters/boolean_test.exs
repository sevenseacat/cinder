defmodule Cinder.Filters.BooleanTest do
  use ExUnit.Case, async: true

  alias Cinder.Filters.Boolean
  alias Cinder.Test.FilterRecord
  alias TestResourceForInference

  defp filter(value), do: %{type: :boolean, value: value, operator: :equals}

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

    test "matches records whose array contains true, or false" do
      with_true = FilterRecord.seed(flags: [true])
      with_false = FilterRecord.seed(flags: [false])
      with_both = FilterRecord.seed(flags: [true, false])
      _empty = FilterRecord.seed(flags: [])

      assert FilterRecord.matching_ids(Boolean, "flags", filter(true)) ==
               MapSet.new([with_true.id, with_both.id])

      assert FilterRecord.matching_ids(Boolean, "flags", filter(false)) ==
               MapSet.new([with_false.id, with_both.id])
    end

    test "matches a plain boolean field by equality" do
      active = FilterRecord.seed(active: true)
      inactive = FilterRecord.seed(active: false)

      assert FilterRecord.matching_ids(Boolean, "active", filter(true)) == MapSet.new([active.id])

      assert FilterRecord.matching_ids(Boolean, "active", filter(false)) ==
               MapSet.new([inactive.id])
    end

    test "returns unchanged query for empty values on array fields", %{query: query} do
      filter_value = %{
        type: :boolean,
        value: nil,
        operator: :equals
      }

      result_query = Boolean.build_query(query, "flags", filter_value)

      # Empty values should not modify the query, even for array fields
      assert result_query == query
    end
  end

  # Note: Basic process/2, validate/1, empty?/1 functionality is tested in
  # test/cinder/configuration/filters_test.exs
end
