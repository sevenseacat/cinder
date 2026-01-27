defmodule Cinder.Renderers.TableSelectionTest do
  @moduledoc """
  Tests for table selection checkbox rendering.
  """

  use ExUnit.Case, async: true
  import Phoenix.LiveViewTest

  alias Cinder.Renderers.Table, as: TableRenderer

  # Use default theme (includes _data attributes) with identifiable test values
  defp test_theme do
    Cinder.Theme.default()
    |> Map.merge(%{
      selection_checkbox_class: "test-checkbox-class",
      selection_th_class: "test-selection-th",
      selection_td_class: "test-selection-td",
      selected_row_class: "test-selected-row"
    })
  end

  defp base_assigns do
    col_slot = %{__slot__: :col, field: :name, inner_block: fn _, item -> item.name end}

    %{
      id: "test-table",
      theme: test_theme(),
      data: [],
      columns: [%{field: :name, label: "Name", sortable: false, class: nil, slot: col_slot}],
      col_slot: [col_slot],
      filters: %{},
      sort_by: [],
      sort_label: "Sort",
      loading: false,
      loading_message: "Loading...",
      empty_message: "No results",
      show_filters: false,
      show_sort: false,
      show_pagination: false,
      page: nil,
      page_size_config: %{},
      pagination_mode: :offset,
      myself: nil,
      filters_label: "Filters",
      search_term: "",
      search_enabled: false,
      search_label: "Search",
      search_placeholder: "Search...",
      row_click: nil,
      selectable: false,
      selected_ids: MapSet.new(),
      id_field: :id,
      bulk_action_slots: []
    }
  end

  describe "table selection rendering" do
    test "renders header checkbox with theme class when selectable=true" do
      assigns =
        base_assigns()
        |> Map.merge(%{selectable: true, selected_ids: MapSet.new(), id_field: :id})

      html = render_component(&TableRenderer.render/1, assigns)

      assert html =~ ~s(phx-click="toggle_select_all_page")
      assert html =~ "test-selection-th"
    end

    test "renders row checkboxes with correct attributes when selectable=true" do
      assigns =
        base_assigns()
        |> Map.merge(%{
          selectable: true,
          selected_ids: MapSet.new(),
          id_field: :id,
          data: [%{id: "user-1", name: "Alice"}, %{id: "user-2", name: "Bob"}]
        })

      html = render_component(&TableRenderer.render/1, assigns)

      assert html =~ ~s(phx-click="toggle_select")
      assert html =~ ~s(phx-value-id="user-1")
      assert html =~ ~s(phx-value-id="user-2")
      assert html =~ "test-selection-td"
      assert html =~ "test-checkbox-class"
    end

    test "does not render selection elements when selectable=false" do
      assigns =
        base_assigns()
        |> Map.merge(%{selectable: false, data: [%{id: "user-1", name: "Alice"}]})

      html = render_component(&TableRenderer.render/1, assigns)

      refute html =~ "toggle_select"
      refute html =~ "test-selection-th"
      refute html =~ "test-selection-td"
    end

    test "applies selected_row_class to selected rows" do
      assigns =
        base_assigns()
        |> Map.merge(%{
          selectable: true,
          selected_ids: MapSet.new(["user-1"]),
          id_field: :id,
          data: [%{id: "user-1", name: "Alice"}, %{id: "user-2", name: "Bob"}]
        })

      html = render_component(&TableRenderer.render/1, assigns)

      assert html =~ "test-selected-row"
    end

    test "header checkbox is checked when all items selected" do
      assigns =
        base_assigns()
        |> Map.merge(%{
          selectable: true,
          selected_ids: MapSet.new(["user-1", "user-2"]),
          id_field: :id,
          data: [%{id: "user-1", name: "Alice"}, %{id: "user-2", name: "Bob"}]
        })

      html = render_component(&TableRenderer.render/1, assigns)

      assert html =~ ~r/<input[^>]*checked[^>]*phx-click="toggle_select_all_page"/
    end

    test "row checkbox reflects selection state" do
      assigns =
        base_assigns()
        |> Map.merge(%{
          selectable: true,
          selected_ids: MapSet.new(["user-1"]),
          id_field: :id,
          data: [%{id: "user-1", name: "Alice"}, %{id: "user-2", name: "Bob"}]
        })

      html = render_component(&TableRenderer.render/1, assigns)

      # user-1 checked, user-2 not checked
      assert html =~ ~r/<input[^>]*checked[^>]*phx-value-id="user-1"/
      refute html =~ ~r/<input[^>]*checked[^>]*phx-value-id="user-2"/
    end
  end
end
