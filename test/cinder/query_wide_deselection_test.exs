defmodule Cinder.QueryWideDeselectionTest do
  use ExUnit.Case, async: true

  alias Cinder.LiveComponent
  alias Cinder.Selection

  test "targeted deselection adds exclusions and preserves other matching rows" do
    socket = socket(MapSet.new(["already-excluded"]))

    assert {:ok, updated} = LiveComponent.update(%{__deselect_items__: [123]}, socket)

    assert updated.assigns.selection_mode == :all_matching
    assert updated.assigns.selected_ids == MapSet.new(["already-excluded", "123"])
    assert updated.assigns.data == socket.assigns.data
    refute Selection.item_selected?(:all_matching, updated.assigns.selected_ids, %{id: 123}, :id)

    assert Selection.item_selected?(
             :all_matching,
             updated.assigns.selected_ids,
             %{id: "keep"},
             :id
           )

    assert_receive {:selection_changed,
                    %{
                      action: :deselect,
                      selection_mode: :all_matching,
                      selected_ids: ids,
                      selected_count: 1
                    }}

    assert ids == updated.assigns.selected_ids
  end

  test "deselecting an already excluded row is idempotent and sends no notification" do
    socket = socket(MapSet.new(["123"]))

    assert {:ok, updated} = LiveComponent.update(%{__deselect_items__: [123, 123]}, socket)

    assert updated.assigns.selected_ids == socket.assigns.selected_ids
    refute_receive {:selection_changed, _}
  end

  defp socket(exclusions) do
    %Phoenix.LiveView.Socket{
      assigns: %{
        __changed__: %{},
        id: "query-selection",
        selectable: true,
        selection_mode: :all_matching,
        selected_ids: exclusions,
        total_count: 3,
        data: [%{id: 123}, %{id: "keep"}, %{id: "already-excluded"}],
        on_selection_change: :selection_changed
      }
    }
  end
end
