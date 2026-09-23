defmodule Cinder.QueryWideRemovalTest do
  use ExUnit.Case, async: true
  alias Cinder.LiveComponent

  test "removing an excluded row does not select it again" do
    socket = socket(MapSet.new(["123"]))
    {:ok, updated} = LiveComponent.update(%{__remove_items__: [123]}, socket)

    assert updated.assigns.data == [%{id: "keep"}]
    assert updated.assigns.selection_mode == :all_matching
    assert updated.assigns.selected_ids == MapSet.new(["123"])
  end

  test "removing a selected row adds an exclusion and retains other exclusions" do
    socket = socket(MapSet.new(["off-page"]))
    {:ok, updated} = LiveComponent.update(%{__remove_items__: [123, "not-rendered"]}, socket)

    assert updated.assigns.data == [%{id: "keep"}]
    assert updated.assigns.selected_ids == MapSet.new(["123", "not-rendered", "off-page"])
  end

  defp socket(exclusions) do
    %Phoenix.LiveView.Socket{
      assigns: %{
        __changed__: %{},
        id_field: :id,
        data: [%{id: 123}, %{id: "keep"}],
        selection_mode: :all_matching,
        selected_ids: exclusions
      }
    }
  end
end
