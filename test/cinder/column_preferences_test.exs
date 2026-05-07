defmodule Cinder.ColumnPreferencesTest do
  use ExUnit.Case, async: true

  alias Cinder.ColumnPreferences

  defp col(field, opts \\ []) do
    %{
      field: field,
      label: field,
      hideable: Keyword.get(opts, :hideable, true),
      reorderable: Keyword.get(opts, :reorderable, true),
      default_visible: Keyword.get(opts, :default_visible, true)
    }
  end

  describe "from_columns/1" do
    test "starts with no hidden columns and no custom order" do
      cols = [col("a"), col("b"), col("c")]
      assert ColumnPreferences.from_columns(cols) == %{order: nil, hidden: MapSet.new()}
    end

    test "adds default_visible: false hideable columns to hidden" do
      cols = [col("a"), col("b", default_visible: false), col("c")]
      assert ColumnPreferences.from_columns(cols).hidden == MapSet.new(["b"])
    end

    test "ignores default_visible: false on non-hideable columns" do
      # A column declared as not hideable but with default_visible: false would
      # be permanently invisible — silently force it visible instead.
      cols = [col("a"), col("b", hideable: false, default_visible: false)]
      assert ColumnPreferences.from_columns(cols).hidden == MapSet.new()
    end
  end

  describe "apply/2" do
    test "returns columns unchanged when prefs are empty" do
      cols = [col("a"), col("b"), col("c")]
      assert ColumnPreferences.apply(cols, ColumnPreferences.empty()) == cols
    end

    test "removes hidden columns" do
      cols = [col("a"), col("b"), col("c")]
      prefs = %{order: nil, hidden: MapSet.new(["b"])}
      result = ColumnPreferences.apply(cols, prefs)
      assert Enum.map(result, & &1.field) == ["a", "c"]
    end

    test "reorders reorderable columns by user order" do
      cols = [col("a"), col("b"), col("c")]
      prefs = %{order: ["c", "a", "b"], hidden: MapSet.new()}
      result = ColumnPreferences.apply(cols, prefs)
      assert Enum.map(result, & &1.field) == ["c", "a", "b"]
    end

    test "pinned columns stay at their declared positions" do
      cols = [
        col("a"),
        col("b", reorderable: false),
        col("c"),
        col("d"),
        col("e", reorderable: false)
      ]

      # User reorders the reorderables: d, c, a
      prefs = %{order: ["d", "c", "a"], hidden: MapSet.new()}
      result = ColumnPreferences.apply(cols, prefs)
      assert Enum.map(result, & &1.field) == ["d", "b", "c", "a", "e"]
    end

    test "pinned columns survive when reorderable columns are hidden" do
      cols = [
        col("a"),
        col("b", reorderable: false),
        col("c"),
        col("d"),
        col("e", reorderable: false)
      ]

      # Hide d, reorder remaining reorderables to [c, a]
      prefs = %{order: ["c", "a"], hidden: MapSet.new(["d"])}
      result = ColumnPreferences.apply(cols, prefs)
      assert Enum.map(result, & &1.field) == ["c", "b", "a", "e"]
    end

    test "appends new reorderable columns not present in saved order" do
      # Simulates user has saved order [a, b], then host app adds column c.
      cols = [col("a"), col("b"), col("c")]
      prefs = %{order: ["b", "a"], hidden: MapSet.new()}
      result = ColumnPreferences.apply(cols, prefs)
      assert Enum.map(result, & &1.field) == ["b", "a", "c"]
    end

    test "ignores unknown fields in saved order" do
      cols = [col("a"), col("b")]
      prefs = %{order: ["b", "phantom", "a"], hidden: MapSet.new()}
      result = ColumnPreferences.apply(cols, prefs)
      assert Enum.map(result, & &1.field) == ["b", "a"]
    end
  end

  describe "toggle_hidden/3" do
    test "hides a previously visible hideable column" do
      cols = [col("a"), col("b")]
      prefs = ColumnPreferences.empty()
      result = ColumnPreferences.toggle_hidden(prefs, "a", cols)
      assert result.hidden == MapSet.new(["a"])
    end

    test "unhides a hidden column" do
      cols = [col("a"), col("b")]
      prefs = %{order: nil, hidden: MapSet.new(["a"])}
      result = ColumnPreferences.toggle_hidden(prefs, "a", cols)
      assert result.hidden == MapSet.new()
    end

    test "refuses to hide a non-hideable column" do
      cols = [col("a", hideable: false), col("b")]
      prefs = ColumnPreferences.empty()
      result = ColumnPreferences.toggle_hidden(prefs, "a", cols)
      assert result == prefs
    end

    test "ignores unknown fields" do
      cols = [col("a")]
      prefs = ColumnPreferences.empty()
      assert ColumnPreferences.toggle_hidden(prefs, "phantom", cols) == prefs
    end
  end

  describe "set_order/3" do
    test "stores cleaned order" do
      cols = [col("a"), col("b"), col("c")]
      prefs = ColumnPreferences.set_order(ColumnPreferences.empty(), ["c", "b", "a"], cols)
      assert prefs.order == ["c", "b", "a"]
    end

    test "drops unknown fields" do
      cols = [col("a"), col("b")]
      prefs = ColumnPreferences.set_order(ColumnPreferences.empty(), ["b", "phantom", "a"], cols)
      assert prefs.order == ["b", "a"]
    end

    test "drops pinned fields from order" do
      cols = [col("a"), col("b", reorderable: false), col("c")]
      prefs = ColumnPreferences.set_order(ColumnPreferences.empty(), ["c", "b", "a"], cols)
      assert prefs.order == ["c", "a"]
    end

    test "deduplicates" do
      cols = [col("a"), col("b")]
      prefs = ColumnPreferences.set_order(ColumnPreferences.empty(), ["a", "b", "a"], cols)
      assert prefs.order == ["a", "b"]
    end
  end

  describe "from_payload/2" do
    test "round-trips through to_payload" do
      cols = [col("a"), col("b"), col("c")]
      prefs = %{order: ["c", "a", "b"], hidden: MapSet.new(["b"])}
      payload = ColumnPreferences.to_payload(prefs)
      result = ColumnPreferences.from_payload(payload, cols)
      assert result.order == ["c", "a", "b"]
      assert result.hidden == MapSet.new(["b"])
    end

    test "accepts string-keyed payload (from JS hook)" do
      cols = [col("a"), col("b")]
      payload = %{"order" => ["b", "a"], "hidden" => ["a"]}
      result = ColumnPreferences.from_payload(payload, cols)
      assert result.order == ["b", "a"]
      assert result.hidden == MapSet.new(["a"])
    end

    test "drops attempts to hide non-hideable columns from a malicious/stale payload" do
      cols = [col("a", hideable: false), col("b")]
      payload = %{"order" => [], "hidden" => ["a", "b"]}
      result = ColumnPreferences.from_payload(payload, cols)
      assert result.hidden == MapSet.new(["b"])
    end

    test "nil payload yields defaults" do
      cols = [col("a"), col("b", default_visible: false)]
      result = ColumnPreferences.from_payload(nil, cols)
      assert result.hidden == MapSet.new(["b"])
    end
  end
end
