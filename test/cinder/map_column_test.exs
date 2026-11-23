defmodule Cinder.MapColumnTest do
  use ExUnit.Case, async: true

  require Ash.Query

  alias Cinder.MapColumn

  # A resource carrying a `:map` attribute (`:metadata`) to exercise the field
  # naming and the query-building filter functions against a real attribute.
  @source :metadata

  defp descriptor(type, opts \\ []) do
    %{
      key: Keyword.get(opts, :key, "colour"),
      type: type,
      label: Keyword.get(opts, :label, "Colour"),
      options: Keyword.get(opts, :options, [])
    }
  end

  defp query, do: Ash.Query.new(TestResourceForInference)

  describe "field/2" do
    test "scalar types resolve to source__key" do
      assert MapColumn.field(descriptor(:text), @source) == "metadata__colour"
      assert MapColumn.field(descriptor(:number, key: "size"), @source) == "metadata__size"
    end

    test "range types resolve to the from bound" do
      assert MapColumn.field(descriptor(:number_range, key: "size"), @source) ==
               "metadata__size__from"

      assert MapColumn.field(descriptor(:date_range, key: "when"), @source) ==
               "metadata__when__from"
    end
  end

  describe "sortable?/1" do
    test "multi-selects are not sortable" do
      refute MapColumn.sortable?(descriptor(:multi_select))
    end

    test "every other type is sortable" do
      for type <- [:text, :number, :date, :boolean, :single_select, :date_range, :number_range] do
        assert MapColumn.sortable?(descriptor(type))
      end
    end
  end

  describe "filter/2" do
    test "text uses the built-in text filter (no custom fn)" do
      assert MapColumn.filter(descriptor(:text), @source) == :text
    end

    test "single-select maps options to a multi-select filter" do
      config = MapColumn.filter(descriptor(:single_select, options: ["red", "green"]), @source)
      assert config[:type] == :multi_select
      assert config[:options] == [{"red", "red"}, {"green", "green"}]
      assert is_function(config[:fn], 2)
    end

    test "casting types attach a 2-arity custom fn" do
      for {type, cinder_type} <- [
            number: :number_range,
            number_range: :number_range,
            date: :date_range,
            date_range: :date_range,
            boolean: :boolean,
            multi_select: :multi_select
          ] do
        config = MapColumn.filter(descriptor(type, options: ["a"]), @source)
        assert config[:type] == cinder_type
        assert is_function(config[:fn], 2)
      end
    end
  end

  describe "filter/2 custom fn query building" do
    test "number scalar casts both bounds and returns a query" do
      fun = MapColumn.filter(descriptor(:number, key: "size"), @source)[:fn]
      assert %Ash.Query{} = fun.(query(), %{value: %{min: "1", max: "10"}})
    end

    test "number range binds the from bound" do
      fun = MapColumn.filter(descriptor(:number_range, key: "size"), @source)[:fn]
      assert %Ash.Query{} = fun.(query(), %{value: %{min: "1", max: nil}})
    end

    test "blank bounds leave the query untouched" do
      fun = MapColumn.filter(descriptor(:number, key: "size"), @source)[:fn]
      built = fun.(query(), %{value: %{min: "", max: nil}})
      assert built == query()
    end

    test "date scalar binds string bounds" do
      fun = MapColumn.filter(descriptor(:date, key: "when"), @source)[:fn]
      assert %Ash.Query{} = fun.(query(), %{value: %{from: "2026-01-01", to: "2026-12-31"}})
    end

    test "boolean binds the stringified value" do
      fun = MapColumn.filter(descriptor(:boolean, key: "flag"), @source)[:fn]
      assert %Ash.Query{} = fun.(query(), %{value: true})
    end

    test "boolean ignores a non-boolean config" do
      fun = MapColumn.filter(descriptor(:boolean, key: "flag"), @source)[:fn]
      assert fun.(query(), %{value: "maybe"}) == query()
    end

    test "multi-select any/all containment builds a query" do
      fun =
        MapColumn.filter(descriptor(:multi_select, key: "tags", options: ["a", "b"]), @source)[
          :fn
        ]

      assert %Ash.Query{} = fun.(query(), %{value: ["a", "b"], match_mode: :any})
      assert %Ash.Query{} = fun.(query(), %{value: ["a", "b"], match_mode: :all})
    end

    test "single-select matches any of several chosen values" do
      fun = MapColumn.filter(descriptor(:single_select, options: ["red", "green"]), @source)[:fn]
      assert %Ash.Query{} = fun.(query(), %{value: ["red", "green"], match_mode: :any})
    end

    test "single-select ignores an empty selection" do
      fun = MapColumn.filter(descriptor(:single_select, options: ["red"]), @source)[:fn]
      assert fun.(query(), %{value: []}) == query()
    end

    test "multi-select ignores an empty selection" do
      fun = MapColumn.filter(descriptor(:multi_select, key: "tags"), @source)[:fn]
      assert fun.(query(), %{value: []}) == query()
    end
  end

  describe "display/3" do
    defp record(map), do: %{@source => map}

    test "boolean renders a check or dash" do
      assert MapColumn.display(
               record(%{"flag" => true}),
               descriptor(:boolean, key: "flag"),
               @source
             ) == "✓"

      assert MapColumn.display(
               record(%{"flag" => false}),
               descriptor(:boolean, key: "flag"),
               @source
             ) == "—"

      assert MapColumn.display(record(%{}), descriptor(:boolean, key: "flag"), @source) == "—"
    end

    test "multi-select joins the list" do
      descriptor = descriptor(:multi_select, key: "tags")
      assert MapColumn.display(record(%{"tags" => ["a", "b"]}), descriptor, @source) == "a, b"
      assert MapColumn.display(record(%{"tags" => nil}), descriptor, @source) == ""
    end

    test "ranges render both bounds with an ellipsis for a missing side" do
      descriptor = descriptor(:number_range, key: "size")

      assert MapColumn.display(
               record(%{"size" => %{"from" => "1", "to" => "9"}}),
               descriptor,
               @source
             ) == "1 – 9"

      assert MapColumn.display(record(%{"size" => %{"from" => "1"}}), descriptor, @source) ==
               "1 – …"

      assert MapColumn.display(record(%{}), descriptor, @source) == ""
    end

    test "scalars stringify, nil renders empty" do
      descriptor = descriptor(:text, key: "colour")
      assert MapColumn.display(record(%{"colour" => "red"}), descriptor, @source) == "red"

      assert MapColumn.display(
               record(%{"colour" => 42}),
               descriptor(:number, key: "colour"),
               @source
             ) == "42"

      assert MapColumn.display(record(%{}), descriptor, @source) == ""
    end

    test "a nil map attribute renders empty" do
      assert MapColumn.display(%{@source => nil}, descriptor(:text), @source) == ""
    end
  end
end
