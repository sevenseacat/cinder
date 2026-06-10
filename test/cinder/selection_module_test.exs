defmodule Cinder.SelectionModuleTest do
  @moduledoc """
  Unit tests for the Cinder.Selection helper module.
  """

  use ExUnit.Case, async: true

  alias Cinder.Selection

  describe "enabled?/1" do
    test "returns false for false and nil" do
      refute Selection.enabled?(false)
      refute Selection.enabled?(nil)
    end

    test "returns true for true" do
      assert Selection.enabled?(true)
    end

    test "returns true for a function" do
      assert Selection.enabled?(fn _item -> true end)
      assert Selection.enabled?(fn _item -> false end)
    end
  end

  describe "item_selectable?/2" do
    test "false is never selectable" do
      refute Selection.item_selectable?(false, %{id: 1})
    end

    test "true is always selectable" do
      assert Selection.item_selectable?(true, %{id: 1})
    end

    test "function decides per item" do
      predicate = fn item -> item.status == :active end

      assert Selection.item_selectable?(predicate, %{status: :active})
      refute Selection.item_selectable?(predicate, %{status: :inactive})
    end

    test "function result is coerced to a boolean" do
      assert Selection.item_selectable?(fn item -> item.name end, %{name: "Alice"}) == true
      assert Selection.item_selectable?(fn _ -> nil end, %{}) == false
    end

    test "unexpected values are not selectable" do
      refute Selection.item_selectable?(:nonsense, %{id: 1})
      refute Selection.item_selectable?(fn a, b -> a || b end, %{id: 1})
    end
  end

  describe "item_selected?/3" do
    test "matches on the stringified id field" do
      selected = MapSet.new(["1", "2"])

      assert Selection.item_selected?(selected, %{id: 1}, :id)
      assert Selection.item_selected?(selected, %{id: "2"}, :id)
      refute Selection.item_selected?(selected, %{id: 3}, :id)
    end

    test "respects a custom id field" do
      selected = MapSet.new(["abc"])

      assert Selection.item_selected?(selected, %{uuid: "abc"}, :uuid)
      refute Selection.item_selected?(selected, %{id: "abc"}, :uuid)
    end
  end

  describe "item_toggleable?/4" do
    test "true when the row is selectable" do
      assert Selection.item_toggleable?(true, MapSet.new(), %{id: 1}, :id)

      predicate = fn item -> item.status == :active end
      assert Selection.item_toggleable?(predicate, MapSet.new(), %{id: 1, status: :active}, :id)
    end

    test "true when not selectable but already selected (so it can be removed)" do
      selected = MapSet.new(["1"])

      assert Selection.item_toggleable?(false, selected, %{id: 1}, :id)
      assert Selection.item_toggleable?(fn _ -> false end, selected, %{id: 1}, :id)
    end

    test "false when neither selectable nor selected" do
      refute Selection.item_toggleable?(false, MapSet.new(), %{id: 1}, :id)
      refute Selection.item_toggleable?(fn _ -> false end, MapSet.new(), %{id: 1}, :id)
    end
  end
end
