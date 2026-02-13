defmodule Cinder.Filters.RadioGroupTest do
  use ExUnit.Case, async: true

  alias Cinder.Filters.RadioGroup
  alias TestResourceForInference

  describe "process/2" do
    test "returns structured filter for non-empty string" do
      assert RadioGroup.process("active", %{}) == %{
               type: :radio_group,
               value: "active",
               operator: :equals
             }
    end

    test "trims whitespace" do
      assert RadioGroup.process("  active  ", %{}) == %{
               type: :radio_group,
               value: "active",
               operator: :equals
             }
    end

    test "returns nil for empty string" do
      assert RadioGroup.process("", %{}) == nil
    end

    test "returns nil for whitespace-only string" do
      assert RadioGroup.process("   ", %{}) == nil
    end

    test "returns nil for non-binary values" do
      assert RadioGroup.process(nil, %{}) == nil
      assert RadioGroup.process(123, %{}) == nil
    end
  end

  describe "validate/1" do
    test "accepts valid radio_group filter" do
      assert RadioGroup.validate(%{type: :radio_group, value: "active", operator: :equals})
    end

    test "rejects empty value" do
      refute RadioGroup.validate(%{type: :radio_group, value: "", operator: :equals})
    end

    test "rejects non-string value" do
      refute RadioGroup.validate(%{type: :radio_group, value: 123, operator: :equals})
    end

    test "rejects wrong type" do
      refute RadioGroup.validate(%{type: :boolean, value: "active", operator: :equals})
    end

    test "rejects missing fields" do
      refute RadioGroup.validate(%{type: :radio_group, value: "active"})
      refute RadioGroup.validate(nil)
    end
  end

  describe "empty?/1" do
    test "nil is empty" do
      assert RadioGroup.empty?(nil)
    end

    test "empty string is empty" do
      assert RadioGroup.empty?("")
    end

    test "map with nil value is empty" do
      assert RadioGroup.empty?(%{value: nil})
    end

    test "map with empty string value is empty" do
      assert RadioGroup.empty?(%{value: ""})
    end

    test "non-empty string is not empty" do
      refute RadioGroup.empty?("active")
    end

    test "map with non-empty value is not empty" do
      refute RadioGroup.empty?(%{value: "active"})
    end
  end

  describe "default_options/0" do
    test "returns options with empty list" do
      assert RadioGroup.default_options() == [options: []]
    end
  end

  describe "build_query/3" do
    setup do
      query = Ash.Query.new(TestResourceForInference)
      %{query: query}
    end

    test "builds equality filter for direct fields", %{query: query} do
      filter_value = %{type: :radio_group, value: "active", operator: :equals}
      result = RadioGroup.build_query(query, "name", filter_value)
      assert result.filter != nil
    end

    test "builds filter for array fields", %{query: query} do
      filter_value = %{type: :radio_group, value: "tag1", operator: :equals}
      result = RadioGroup.build_query(query, "tags", filter_value)

      # Array fields use containment
      assert match?(
               %Ash.Filter{
                 expression: %Ash.Query.Operator.In{
                   left: "tag1",
                   operator: :in,
                   right: %{attribute: %{name: :tags}}
                 }
               },
               result.filter
             )
    end

    test "returns unchanged query for nil value", %{query: query} do
      filter_value = %{type: :radio_group, value: nil, operator: :equals}
      result = RadioGroup.build_query(query, "name", filter_value)
      assert result == query
    end
  end

  describe "render/4" do
    test "renders radio buttons for each option" do
      column = %{
        field: "status",
        filter_options: [options: [{"Active", "active"}, {"Archived", "archived"}]]
      }

      theme = Cinder.Theme.default()
      rendered = RadioGroup.render(column, nil, theme, %{})
      html = Phoenix.HTML.Safe.to_iodata(rendered) |> IO.iodata_to_binary()

      assert html =~ "Active"
      assert html =~ "Archived"
      assert html =~ ~s(value="active")
      assert html =~ ~s(value="archived")
      assert html =~ ~s(type="radio")
      assert html =~ ~s(name="filters[status]")
    end

    test "marks the current value as checked" do
      column = %{
        field: "status",
        filter_options: [options: [{"Active", "active"}, {"Archived", "archived"}]]
      }

      theme = Cinder.Theme.default()
      rendered = RadioGroup.render(column, "active", theme, %{})
      html = Phoenix.HTML.Safe.to_iodata(rendered) |> IO.iodata_to_binary()

      # The active radio should be checked
      assert html =~ "checked"
    end

    test "renders with no options" do
      column = %{field: "status", filter_options: [options: []]}
      theme = Cinder.Theme.default()
      rendered = RadioGroup.render(column, nil, theme, %{})
      html = Phoenix.HTML.Safe.to_iodata(rendered) |> IO.iodata_to_binary()

      # Should render container but no radio buttons
      assert html =~ "filter_radio_group_container_class"
      refute html =~ ~s(type="radio")
    end

    test "renders with missing filter_options" do
      column = %{field: "status"}
      theme = Cinder.Theme.default()
      rendered = RadioGroup.render(column, nil, theme, %{})
      html = Phoenix.HTML.Safe.to_iodata(rendered) |> IO.iodata_to_binary()

      # Should render without error
      assert html =~ "filter_radio_group_container_class"
    end
  end
end
