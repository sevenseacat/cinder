defmodule Cinder.Next.RowSelectionTest do
  use ExUnit.Case, async: true

  alias Cinder.Engine.{Page, Query}
  alias Cinder.Next.RowSelection

  # Records 1 and 2 are shown, of 10 matching. What's picked can be on other pages
  # ("9").
  @page %Page{records: [%{id: 1, genre: :rock}, %{id: 2, genre: :jazz}], count: 10}

  defp jazz?(record), do: record.genre == :jazz

  defp shown(selectable \\ true, page \\ @page) do
    selectable |> RowSelection.new(:id) |> RowSelection.for_page(page)
  end

  defp picked(ids, selection \\ shown()), do: %{selection | ids: MapSet.new(ids)}

  defp all_except(ids, selection \\ shown()) do
    %{selection | mode: :all_except, ids: MapSet.new(ids)}
  end

  describe "the page shown" do
    test "its records that can be selected, by their ids as strings, and how many match" do
      selection = shown()
      assert selection.page_ids == MapSet.new(["1", "2"])
      assert selection.total == 10
      assert RowSelection.count(selection) == 0
      assert RowSelection.id(selection, %{id: 1}) == "1"
    end

    test "with a `selectable` function, only the records it accepts" do
      assert shown(&jazz?/1).page_ids == MapSet.new(["2"])
    end
  end

  test "selected?/2: an id picked, or one not excepted from all matching" do
    assert RowSelection.selected?(picked(["1"]), "1")
    refute RowSelection.selected?(picked(["1"]), "2")
    assert RowSelection.selected?(all_except(["1"]), "2")
    refute RowSelection.selected?(all_except(["1"]), "1")
  end

  describe "count/1" do
    test "the ids picked, or how many match less those excepted" do
      assert RowSelection.count(picked(["1", "9"])) == 2
      assert RowSelection.count(picked(["1", "9"], shown(true, %{@page | count: nil}))) == 2
      assert RowSelection.count(all_except(["1"])) == 9
    end

    # A failed read has no count, and records excepted may since have gone: nothing
    # to act on, rather than a guess
    test "all matching, without a count or with fewer matching than excepted, is none" do
      assert RowSelection.count(all_except([], shown(true, %{@page | count: nil}))) == 0
      assert RowSelection.count(all_except(["1", "2"], shown(true, %{@page | count: 1}))) == 0
    end
  end

  test "everything?/1: all matching, with none excepted" do
    assert RowSelection.everything?(all_except([]))
    refute RowSelection.everything?(all_except(["1"]))
    refute RowSelection.everything?(picked(["1", "2"]))
  end

  describe "toggle/2" do
    test "an id on the page is picked, then cleared" do
      assert RowSelection.toggle(picked(["9"]), "1") == picked(["1", "9"])
      assert RowSelection.toggle(picked(["1", "9"]), "1") == picked(["9"])
    end

    test "with all matching, an id is excepted, then selected again" do
      assert RowSelection.toggle(all_except([]), "1") == all_except(["1"])
      assert RowSelection.toggle(all_except(["1"]), "1") == all_except([])
    end

    # Not on the page shown, or not one `selectable` accepts: from a forged event
    test "any other id is ignored" do
      assert RowSelection.toggle(picked(["9"]), "9") == picked(["9"])
      assert RowSelection.toggle(all_except([]), "3") == all_except([])
      assert RowSelection.toggle(shown(&jazz?/1), "1") == shown(&jazz?/1)
    end
  end

  describe "the page's box" do
    test "selects the page's ids, keeping others, unless they all are, which clears them" do
      assert RowSelection.toggle_page(picked(["1", "9"])) == picked(["1", "2", "9"])
      assert RowSelection.toggle_page(picked(["1", "2", "9"])) == picked(["9"])
      assert RowSelection.toggle_page(all_except(["1", "9"])) == all_except(["9"])
      assert RowSelection.toggle_page(all_except(["9"])) == all_except(["1", "2", "9"])
    end

    test "is checked when every id on the page is selected" do
      assert RowSelection.page_selected?(picked(["1", "2", "9"]))
      refute RowSelection.page_selected?(picked(["1"]))
      assert RowSelection.page_selected?(all_except(["9"]))
      refute RowSelection.page_selected?(all_except(["1"]))
    end

    # It can't be checked, so it selects nothing
    test "isn't checked on a page with nothing to select" do
      empty = shown(true, %{@page | records: []})
      refute RowSelection.page_selected?(picked(["9"], empty))
      refute RowSelection.page_selected?(all_except([], empty))
      assert RowSelection.toggle_page(picked(["9"], empty)) == picked(["9"], empty)
    end
  end

  describe "all matching" do
    test "is offered, with how many, once the whole page is picked and more match" do
      assert RowSelection.all_matching_offer(picked(["1", "2"])) == 10
      assert RowSelection.select_all_matching(picked(["1", "2", "9"])) == all_except([])
    end

    # Without a count it can't say how many, and a `selectable` function can't be
    # asked of records not read
    test "isn't offered otherwise, and selecting it changes nothing" do
      for selection <- [
            picked(["1"]),
            picked(["1", "2"], shown(true, %{@page | count: nil})),
            picked(["1", "2"], shown(true, %{@page | count: 2})),
            picked(["2"], shown(&jazz?/1)),
            all_except(["1"])
          ] do
        assert RowSelection.all_matching_offer(selection) == nil
        assert RowSelection.select_all_matching(selection) == selection
      end
    end
  end

  test "clear/1 picks nothing, and keeps the page" do
    assert RowSelection.clear(all_except(["1"])) == shown()
  end

  describe "carry_over/4, when the collection is rebuilt" do
    test "reading the same records, what's picked stays" do
      assert RowSelection.carry_over(picked(["1"]), &jazz?/1, :id, true) ==
               picked(["1"], %{shown() | selectable: &jazz?/1})

      assert RowSelection.carry_over(all_except(["1"]), true, :id, true) == all_except(["1"])
    end

    # A function can't be asked of records not read
    test "a `selectable` function ends all matching" do
      assert RowSelection.carry_over(all_except(["1"]), &jazz?/1, :id, true) ==
               %{shown() | selectable: &jazz?/1}
    end

    test "reading other records, or when records can't be selected, nothing is picked" do
      assert RowSelection.carry_over(picked(["1"]), true, :id, false) ==
               RowSelection.new(true, :id)

      assert RowSelection.carry_over(picked(["1"]), false, :id, true) ==
               RowSelection.new(false, :id)
    end
  end

  # Arguments decide what's read, and the filters and search what all matching is.
  # Ids picked stay through a filter, which hides a record without unselecting it.
  test "for_query/3 clears what a new query makes stale" do
    old = %Query{}
    jazz = %{"genre" => %{type: :select, value: "jazz", operator: :equals}}

    assert RowSelection.for_query(picked(["1"]), old, %{old | arguments: jazz}) == shown()
    assert RowSelection.for_query(picked(["1"]), old, %{old | filters: jazz}) == picked(["1"])
    assert RowSelection.for_query(all_except([]), old, %{old | filters: jazz}) == shown()
    assert RowSelection.for_query(all_except([]), old, %{old | search: "b"}) == shown()

    assert RowSelection.for_query(all_except([]), old, %{old | sort: [{"title", :asc}], page: 2}) ==
             all_except([])
  end

  test "changed?/2 compares what's picked, not the page" do
    refute RowSelection.changed?(picked(["1"]), picked(["1"], shown(true, %{@page | count: 3})))
    assert RowSelection.changed?(picked(["1"]), picked(["2"]))
    assert RowSelection.changed?(picked([]), all_except([]))
  end

  test "payload/1 is what the parent hears" do
    assert RowSelection.payload(picked(["1", "9"])) == %{
             selected_ids: MapSet.new(["1", "9"]),
             selected_count: 2,
             all_matching?: false,
             excluded_ids: MapSet.new()
           }

    assert RowSelection.payload(all_except(["1"])) == %{
             selected_ids: MapSet.new(),
             selected_count: 9,
             all_matching?: true,
             excluded_ids: MapSet.new(["1"])
           }
  end

  test "to_engine/1 is what `Cinder.Engine.run_bulk_action/6` takes" do
    assert RowSelection.to_engine(picked(["1"])) == {:ids, ["1"]}
    assert RowSelection.to_engine(all_except(["1"])) == {:all_except, ["1"]}
  end
end
