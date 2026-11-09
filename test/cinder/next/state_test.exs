defmodule Cinder.Next.StateTest do
  use ExUnit.Case, async: true

  alias Cinder.Next.State

  @cycle [nil, :asc, :desc]

  describe "toggle_sort/4" do
    test "a column's clicks step through its cycle, back to unsorted" do
      assert State.toggle_sort([], "title", @cycle, :additive) == [{"title", :asc}]

      assert State.toggle_sort([{"title", :asc}], "title", @cycle, :additive) == [
               {"title", :desc}
             ]

      assert State.toggle_sort([{"title", :desc}], "title", @cycle, :additive) == []
    end

    test "additive: the column clicked becomes the main sort, the others break its ties" do
      assert State.toggle_sort([{"price", :asc}], "title", @cycle, :additive) ==
               [{"title", :asc}, {"price", :asc}]

      # Already in the sort, it changes direction and moves to the front
      assert State.toggle_sort([{"price", :asc}, {"title", :asc}], "title", @cycle, :additive) ==
               [{"title", :desc}, {"price", :asc}]

      assert State.toggle_sort([{"price", :asc}, {"title", :desc}], "title", @cycle, :additive) ==
               [{"price", :asc}]
    end

    test "exclusive: the column clicked is the only sort" do
      assert State.toggle_sort([{"price", :asc}], "title", @cycle, :exclusive) ==
               [{"title", :asc}]

      assert State.toggle_sort([{"price", :asc}, {"title", :desc}], "title", @cycle, :exclusive) ==
               []
    end

    test "a column's own cycle" do
      cycle = [:desc, :asc, nil]
      assert State.toggle_sort([], "added", cycle, :additive) == [{"added", :desc}]
      assert State.toggle_sort([{"added", :desc}], "added", cycle, :additive) == [{"added", :asc}]
      assert State.toggle_sort([{"added", :asc}], "added", cycle, :additive) == []
    end

    test "a cycle without nil never goes back to unsorted" do
      cycle = [:asc, :desc]
      assert State.toggle_sort([{"title", :desc}], "title", cycle, :additive) == [{"title", :asc}]
      # Unsorted (another column took over in exclusive mode): the cycle starts again
      assert State.toggle_sort([], "title", cycle, :exclusive) == [{"title", :asc}]
    end

    test "a direction that isn't in the cycle (from the query or the URL) starts the cycle" do
      for cycle <- [@cycle, [:asc, :desc], [:desc, :asc]] do
        first = Enum.find(cycle, & &1)

        assert State.toggle_sort([{"title", :desc_nils_last}], "title", cycle, :additive) ==
                 [{"title", first}]
      end
    end
  end

  describe "carry_over_sort/4" do
    test "a sort still at the old default becomes the new default" do
      assert State.carry_over_sort([{"title", :asc}], [{"title", :asc}], [{"price", :desc}], [
               "title"
             ]) == [{"price", :desc}]
    end

    test "a sort the user chose stays, minus fields that are no longer sortable" do
      sort = [{"title", :desc}, {"price", :asc}]
      assert State.carry_over_sort(sort, [], [], ["title"]) == [{"title", :desc}]
    end
  end

  describe "carry_over_inputs/2" do
    test "filters stay, minus fields that are no longer filterable" do
      filters = %{
        "title" => %{type: :text, value: "ab", operator: :contains, case_sensitive: false},
        "genre" => %{type: :select, value: "rock", operator: :equals}
      }

      assert State.carry_over_inputs(filters, ["genre", "price"]) ==
               %{"genre" => %{type: :select, value: "rock", operator: :equals}}
    end
  end

  describe "carry_over_search/2" do
    test "the search stays while any field is searchable" do
      assert State.carry_over_search("ab", ["title"]) == "ab"
      assert State.carry_over_search("ab", []) == ""
    end
  end

  describe "carry_over_page/3" do
    @old %Cinder.Engine.Query{sort: [{"title", :asc}], search: "ab", page: 3}

    test "the page stays if the same read gives the same records" do
      assert State.carry_over_page(@old, @old, true) == @old
    end

    test "back to the first page if the source or the query changed" do
      assert State.carry_over_page(@old, @old, false).page == 1
      assert State.carry_over_page(%{@old | search: ""}, @old, true).page == 1
      assert State.carry_over_page(%{@old | page_size: 10}, @old, true).page == 1
    end
  end

  # The selectable ids are those of the page shown that can be selected
  describe "toggle_selected/3" do
    @selectable MapSet.new(["a", "b"])

    test "a selectable id is selected, then cleared" do
      selected = State.toggle_selected(MapSet.new(["z"]), "a", @selectable)
      assert selected == MapSet.new(["a", "z"])
      assert State.toggle_selected(selected, "a", @selectable) == MapSet.new(["z"])
    end

    # Not on the page shown, or not selectable: from a forged event
    test "any other id is ignored" do
      assert State.toggle_selected(MapSet.new(["z"]), "c", @selectable) == MapSet.new(["z"])
      assert State.toggle_selected(MapSet.new(["z"]), "z", @selectable) == MapSet.new(["z"])
    end
  end

  describe "select_page/2 and clear_page/2" do
    test "add or remove the page's selectable ids, keeping others" do
      assert State.select_page(MapSet.new(["a", "z"]), MapSet.new(["a", "b"])) ==
               MapSet.new(["a", "b", "z"])

      assert State.clear_page(MapSet.new(["a", "z"]), MapSet.new(["a", "b"])) ==
               MapSet.new(["z"])
    end
  end

  describe "page_selected?/2" do
    test "whether every selectable id on the page is selected" do
      assert State.page_selected?(MapSet.new(["a", "b", "z"]), MapSet.new(["a", "b"]))
      refute State.page_selected?(MapSet.new(["a"]), MapSet.new(["a", "b"]))
    end

    # Its heading checkbox can't be checked, so it selects nothing
    test "a page with nothing selectable isn't selected" do
      refute State.page_selected?(MapSet.new(["z"]), MapSet.new())
    end
  end
end
