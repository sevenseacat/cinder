defmodule Cinder.Renderers.GridSelectionTest do
  @moduledoc """
  Tests for grid selection checkbox rendering.
  """

  use ExUnit.Case, async: true
  import Phoenix.LiveViewTest

  alias Cinder.Renderers.Grid, as: GridRenderer

  # Use default theme (includes _data attributes) with identifiable test values
  defp test_theme do
    Cinder.Theme.default()
    |> Map.merge(%{
      selection_checkbox_class: "test-checkbox-class",
      grid_selection_overlay_class: "test-overlay-class",
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
      grid_columns: 3,
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

  describe "grid selection rendering" do
    test "renders overlay checkbox with theme classes when selectable=true" do
      assigns =
        base_assigns()
        |> Map.merge(%{
          selectable: true,
          selected_ids: MapSet.new(),
          id_field: :id,
          data: [%{id: "item-1", name: "Item 1"}]
        })

      html = render_component(&GridRenderer.render/1, assigns)

      assert html =~ "test-overlay-class"
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

      html = render_component(&GridRenderer.render/1, assigns)

      refute html =~ "toggle_select"
      refute html =~ "test-overlay-class"
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

      html = render_component(&GridRenderer.render/1, assigns)

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

      html = render_component(&GridRenderer.render/1, assigns)

      # item-1 checked, item-2 not checked
      assert html =~ ~r/<input[^>]*checked[^>]*phx-value-id="item-1"/
      refute html =~ ~r/<input[^>]*checked[^>]*phx-value-id="item-2"/
    end

    test "renders checkbox for each item" do
      assigns =
        base_assigns()
        |> Map.merge(%{
          selectable: true,
          selected_ids: MapSet.new(),
          id_field: :id,
          data: [
            %{id: "item-1", name: "Item 1"},
            %{id: "item-2", name: "Item 2"},
            %{id: "item-3", name: "Item 3"}
          ]
        })

      html = render_component(&GridRenderer.render/1, assigns)

      # Count overlay divs
      overlay_count = length(Regex.scan(~r/test-overlay-class/, html))
      assert overlay_count == 3
    end
  end
end
