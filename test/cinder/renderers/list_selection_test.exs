defmodule Cinder.Renderers.ListSelectionTest do
  @moduledoc """
  Tests for list selection checkbox rendering.
  """

  use ExUnit.Case, async: true
  import Phoenix.LiveViewTest

  alias Cinder.Renderers.List, as: ListRenderer

  # Use default theme (includes _data attributes) with identifiable test values
  defp test_theme do
    Cinder.Theme.default()
    |> Map.merge(%{
      selection_checkbox_class: "test-checkbox-class",
      list_selection_container_class: "test-selection-container",
      selected_item_class: "test-selected-item"
    })
  end

  defp base_assigns do
    %{
      id: "test-table",
      theme: test_theme(),
      data: [],
      columns: [],
      item_slot: [%{__slot__: :item, inner_block: fn _, item -> item.name end}],
      filters: %{},
      sort_by: [],
      sort_label: "Sort",
      loading: false,
      error: false,
      loading_message: "Loading...",
      empty_message: "No results",
      error_message: "An error occurred",
      show_filters: false,
      show_sort: false,
      show_pagination: false,
      page: nil,
      page_size_config: %{},
      pagination_mode: :offset,
      myself: nil,
      container_class: nil,
      item_click: nil,
      filters_label: "Filters",
      search_term: "",
      search_enabled: false,
      search_label: "Search",
      search_placeholder: "Search...",
      selectable: false,
      selected_ids: MapSet.new(),
      id_field: :id,
      bulk_action_slots: []
    }
  end

  describe "list selection rendering" do
    test "renders leading checkbox with theme classes when selectable=true" do
      assigns =
        base_assigns()
        |> Map.merge(%{
          selectable: true,
          selected_ids: MapSet.new(),
          id_field: :id,
          data: [%{id: "item-1", name: "Item 1"}]
        })

      html = render_component(&ListRenderer.render/1, assigns)

      assert html =~ "test-selection-container"
      assert html =~ "test-checkbox-class"
      assert html =~ ~s(phx-click="toggle_select")
      assert html =~ ~s(phx-value-id="item-1")
    end

    test "does not render selection elements when selectable=false" do
      assigns =
        base_assigns()
        |> Map.merge(%{
          selectable: false,
          data: [%{id: "item-1", name: "Item 1"}]
        })

      html = render_component(&ListRenderer.render/1, assigns)

      refute html =~ "toggle_select"
      refute html =~ "test-selection-container"
      refute html =~ "test-checkbox-class"
    end

    test "applies selected_item_class to selected items" do
      assigns =
        base_assigns()
        |> Map.merge(%{
          selectable: true,
          selected_ids: MapSet.new(["item-1"]),
          id_field: :id,
          data: [%{id: "item-1", name: "Item 1"}, %{id: "item-2", name: "Item 2"}]
        })

      html = render_component(&ListRenderer.render/1, assigns)

      assert html =~ "test-selected-item"
    end

    test "checkbox reflects selection state" do
      assigns =
        base_assigns()
        |> Map.merge(%{
          selectable: true,
          selected_ids: MapSet.new(["item-1"]),
          id_field: :id,
          data: [%{id: "item-1", name: "Item 1"}, %{id: "item-2", name: "Item 2"}]
        })

      html = render_component(&ListRenderer.render/1, assigns)

      # item-1 checked, item-2 not checked
      assert html =~ ~r/<input[^>]*checked[^>]*phx-value-id="item-1"/
      refute html =~ ~r/<input[^>]*checked[^>]*phx-value-id="item-2"/
    end

    test "clicking item toggles selection when selectable and no item_click" do
      assigns =
        base_assigns()
        |> Map.merge(%{
          selectable: true,
          selected_ids: MapSet.new(),
          id_field: :id,
          item_click: nil,
          data: [%{id: "item-1", name: "Item 1"}]
        })

      html = render_component(&ListRenderer.render/1, assigns)

      # The item div should have phx-click that pushes toggle_select
      assert html =~ ~r/<div[^>]*class="[^"]*cursor-pointer/
      assert html =~ "phx-click"
      assert html =~ "toggle_select"
    end
  end

  describe "list selection rendering with predicate" do
    defp predicate_assigns do
      base_assigns()
      |> Map.merge(%{
        selectable: fn item -> item.status == :active end,
        selected_ids: MapSet.new(),
        id_field: :id,
        data: [
          %{id: "item-1", name: "Item 1", status: :active},
          %{id: "item-2", name: "Item 2", status: :inactive}
        ]
      })
    end

    test "renders a checkbox for every item, disabling non-selectable ones" do
      html = render_component(&ListRenderer.render/1, predicate_assigns())

      # Checkbox container rendered for both items, kept uniform across rows
      assert html =~ ~s(phx-value-id="item-1")
      assert html =~ ~s(phx-value-id="item-2")
      assert length(Regex.scan(~r/test-selection-container/, html)) == 2

      # Selectable item enabled, non-selectable item disabled
      refute html =~ ~r/<input[^>]*disabled[^>]*phx-value-id="item-1"/
      assert html =~ ~r/<input[^>]*disabled[^>]*phx-value-id="item-2"/
    end

    test "keeps an already-selected item's checkbox enabled even if not selectable" do
      assigns = Map.put(predicate_assigns(), :selected_ids, MapSet.new(["item-2"]))

      html = render_component(&ListRenderer.render/1, assigns)

      assert html =~ ~r/<input[^>]*checked[^>]*phx-value-id="item-2"/
      refute html =~ ~r/<input[^>]*disabled[^>]*phx-value-id="item-2"/
    end

    test "applies selected styling only to selectable selected items" do
      assigns = Map.put(predicate_assigns(), :selected_ids, MapSet.new(["item-1"]))

      html = render_component(&ListRenderer.render/1, assigns)

      assert html =~ "test-selected-item"
    end
  end
end
