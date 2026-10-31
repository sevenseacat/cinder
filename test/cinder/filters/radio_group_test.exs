defmodule Cinder.Filters.RadioGroupTest do
  use ExUnit.Case, async: true

  alias Cinder.Filters.RadioGroup
  alias Cinder.Test.FilterRecord
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

    test "matches a plain field by equality" do
      hit = FilterRecord.seed(name: "active")
      _miss = FilterRecord.seed(name: "inactive")
      filter_value = %{type: :radio_group, value: "active", operator: :equals}

      assert FilterRecord.matching_ids(RadioGroup, "name", filter_value) == MapSet.new([hit.id])
    end

    test "matches records whose array contains the value" do
      hit = FilterRecord.seed(tags: ["tag1", "tag2"])
      _miss = FilterRecord.seed(tags: ["tag2"])
      filter_value = %{type: :radio_group, value: "tag1", operator: :equals}

      assert FilterRecord.matching_ids(RadioGroup, "tags", filter_value) == MapSet.new([hit.id])
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

    test "checks only the option matching the current value" do
      column = %{
        field: "status",
        filter_options: [options: [{"Active", "active"}, {"Archived", "archived"}]]
      }

      assert checked_values(column, "archived") == ["archived"]
    end

    test "checks the matching option when option values are atoms, as enum options are" do
      column = %{field: "genre", filter_options: [options: [{"Rock", :rock}, {"Jazz", :jazz}]]}

      # The current value comes back from the form as a string
      assert checked_values(column, "jazz") == ["jazz"]
    end

    test "checks nothing without a current value" do
      column = %{field: "genre", filter_options: [options: [{"Rock", :rock}, {"Jazz", :jazz}]]}

      assert checked_values(column, nil) == []
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

  defp checked_values(column, current_value) do
    html =
      column
      |> RadioGroup.render(current_value, Cinder.Theme.default(), %{})
      |> Phoenix.HTML.Safe.to_iodata()
      |> IO.iodata_to_binary()

    for [input] <- Regex.scan(~r/<input[^>]*>/, html),
        input =~ ~r/\schecked/,
        [_, value] <- [Regex.run(~r/value="([^"]*)"/, input)],
        do: value
  end
end
