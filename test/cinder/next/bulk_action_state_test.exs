defmodule Cinder.Next.BulkActionStateTest do
  use ExUnit.Case, async: true

  alias Cinder.Next.BulkActionState

  # As `Cinder.Next.Config` declares them, less what these rules don't read
  @delete %{name: "destroy", label: "Delete", confirm: "Delete {count} albums?"}
  @remaster %{name: "remaster", label: "Remaster", confirm: nil}

  # Asked at 1000ms, answerable from 1500ms
  @confirming {:confirming, @delete, 1000}
  @running {:running, @remaster, 2}

  describe "ask/4, when the user clicks an action" do
    test "one with a confirm asks first, and one without runs" do
      assert BulkActionState.ask(:idle, @delete, 2, 1000) == {:confirming, @confirming}
      assert BulkActionState.ask(:idle, @remaster, 2, 1000) == {:run, @remaster}
    end

    # From a tampered event: the buttons only send declared names, and are disabled
    # with nothing selected, or while one is waiting or running
    test "one that isn't declared, with nothing selected, or while another waits or runs, is ignored" do
      assert BulkActionState.ask(:idle, nil, 2, 1000) == :ignore
      assert BulkActionState.ask(:idle, @remaster, 0, 1000) == :ignore
      assert BulkActionState.ask(@confirming, @remaster, 2, 1200) == :ignore
      assert BulkActionState.ask(@running, @delete, 2, 1200) == :ignore
    end
  end

  describe "answer/5, when the user confirms" do
    test "after the delay, it runs" do
      assert BulkActionState.answer(@confirming, "destroy", 2, 1500, 500) == {:run, @delete}
    end

    # A slow double click on the action would land its second click on confirming
    test "too soon after asking is ignored" do
      assert BulkActionState.answer(@confirming, "destroy", 2, 1499, 500) == :ignore
    end

    # From tampering: the dialog only confirms the action it asks about
    test "with nothing waiting, another action than the one waiting, or nothing selected, is ignored" do
      assert BulkActionState.answer(:idle, "destroy", 2, 1500, 500) == :ignore
      assert BulkActionState.answer(@running, "remaster", 2, 1500, 500) == :ignore
      assert BulkActionState.answer(@confirming, "remaster", 2, 1500, 500) == :ignore
      assert BulkActionState.answer(@confirming, "destroy", 0, 1500, 500) == :ignore
    end
  end

  test "cancel/1 closes a confirm, but doesn't stop a running action" do
    assert BulkActionState.cancel(@confirming) == :idle
    assert BulkActionState.cancel(@running) == @running
    assert BulkActionState.cancel(:idle) == :idle
  end

  test "running/2 is the action, and how many records it runs on" do
    assert BulkActionState.running(@remaster, 2) == @running
  end

  describe "carry_over/2, when the collection is rebuilt" do
    test "a confirm asks about its action as now declared, or goes with it" do
      reworded = %{@delete | confirm: "Really delete {count}?"}

      assert BulkActionState.carry_over(@confirming, [@remaster, reworded]) ==
               {:confirming, reworded, 1000}

      assert BulkActionState.carry_over(@confirming, [@remaster]) == :idle
    end

    test "a running action is left to finish" do
      assert BulkActionState.carry_over(@running, []) == @running
      assert BulkActionState.carry_over(:idle, []) == :idle
    end
  end

  test "for_selection/2: a confirm with nothing left selected closes" do
    assert BulkActionState.for_selection(@confirming, 0) == :idle
    assert BulkActionState.for_selection(@confirming, 1) == @confirming
    assert BulkActionState.for_selection(@running, 0) == @running
  end
end
