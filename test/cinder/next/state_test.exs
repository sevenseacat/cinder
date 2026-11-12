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

  # A selection is the ids picked, or every matching record except some ids. The
  # selectable ids are those of the page shown that can be selected.
  defp ids(ids), do: {:ids, MapSet.new(ids)}
  defp all_except(ids), do: {:all_except, MapSet.new(ids)}

  describe "selected?/2" do
    test "an id picked, or one not excepted from all matching" do
      assert State.selected?(ids(["a"]), "a")
      refute State.selected?(ids(["a"]), "b")
      assert State.selected?(all_except(["a"]), "b")
      refute State.selected?(all_except(["a"]), "a")
    end
  end

  describe "selected_count/2" do
    test "the ids picked, or the total less those excepted" do
      assert State.selected_count(ids(["a", "b"]), 10) == 2
      assert State.selected_count(ids(["a", "b"]), nil) == 2
      assert State.selected_count(all_except(["a"]), 10) == 9
    end

    # A failed read has no count, and records excepted may since have gone: nothing
    # to act on, rather than a guess
    test "all matching, without a count or with fewer matching than excepted, is none" do
      assert State.selected_count(all_except([]), nil) == 0
      assert State.selected_count(all_except(["a", "b"]), 1) == 0
    end
  end

  describe "toggle_selected/3" do
    @selectable MapSet.new(["a", "b"])

    test "a selectable id is selected, then cleared" do
      selected = State.toggle_selected(ids(["z"]), "a", @selectable)
      assert selected == ids(["a", "z"])
      assert State.toggle_selected(selected, "a", @selectable) == ids(["z"])
    end

    test "with all matching, a selectable id is cleared, then selected" do
      selected = State.toggle_selected(all_except([]), "a", @selectable)
      assert selected == all_except(["a"])
      assert State.toggle_selected(selected, "a", @selectable) == all_except([])
    end

    # Not on the page shown, or not selectable: from a forged event
    test "any other id is ignored" do
      assert State.toggle_selected(ids(["z"]), "c", @selectable) == ids(["z"])
      assert State.toggle_selected(ids(["z"]), "z", @selectable) == ids(["z"])
      assert State.toggle_selected(all_except([]), "c", @selectable) == all_except([])
    end
  end

  describe "select_page/2 and clear_page/2" do
    test "select or clear the page's selectable ids, keeping others" do
      page = MapSet.new(["a", "b"])
      assert State.select_page(ids(["a", "z"]), page) == ids(["a", "b", "z"])
      assert State.clear_page(ids(["a", "z"]), page) == ids(["z"])
      assert State.select_page(all_except(["a", "z"]), page) == all_except(["z"])
      assert State.clear_page(all_except(["a", "z"]), page) == all_except(["a", "b", "z"])
    end
  end

  describe "page_selected?/2" do
    test "whether every selectable id on the page is selected" do
      page = MapSet.new(["a", "b"])
      assert State.page_selected?(ids(["a", "b", "z"]), page)
      refute State.page_selected?(ids(["a"]), page)
      assert State.page_selected?(all_except(["z"]), page)
      refute State.page_selected?(all_except(["a"]), page)
    end

    # Its heading checkbox can't be checked, so it selects nothing
    test "a page with nothing selectable isn't selected" do
      refute State.page_selected?(ids(["z"]), MapSet.new())
      refute State.page_selected?(all_except([]), MapSet.new())
    end
  end
end
