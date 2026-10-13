defmodule Cinder.Renderers.SelectAllTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias Cinder.Renderers.SelectAll

  test "query mode stays available when the current page has no eligible rows" do
    assigns = %{
      data: [%{id: "inactive", active?: false}],
      id_field: :id,
      loading: false,
      myself: nil,
      selectable: & &1.active?,
      selected_ids: MapSet.new(),
      theme: Cinder.Theme.default()
    }

    query_html = render_component(&SelectAll.render/1, Map.put(assigns, :mode, :query))
    refute query_html =~ ~r/<input[^>]*\sdisabled(?:\s|>)/

    page_html = render_component(&SelectAll.render/1, Map.put(assigns, :mode, :page))
    assert page_html =~ ~r/<input[^>]*\sdisabled(?:\s|>)/
  end

  test "keeps the native checked state and disables the control while select-all is pending" do
    html =
      render_component(&SelectAll.render/1,
        data: [%{id: "product-1"}],
        id_field: :id,
        label: "Choose every matching row",
        loading: true,
        myself: nil,
        pending: true,
        selectable: true,
        selected_ids: MapSet.new(),
        theme: %{
          select_all_container_class: "select-all",
          selection_checkbox_class: "checkbox",
          selection_indeterminate_class: "indeterminate"
        }
      )

    assert html =~ ~s(checked)
    assert html =~ ~s(aria-checked="true")
    assert html =~ ~s(data-selection-state="all")
    assert html =~ ~s(disabled)
    assert html =~ "Choose every matching row"
    assert html =~ ~s(aria-label="Choose every matching row")
  end

  test "page mode targets the visible-page event and label" do
    html =
      render_component(&SelectAll.render/1,
        data: [%{id: "product-1"}],
        id_field: :id,
        loading: false,
        mode: :page,
        myself: nil,
        selectable: true,
        selected_ids: MapSet.new(),
        theme: %{
          select_all_container_class: "select-all",
          selection_checkbox_class: "checkbox",
          selection_indeterminate_class: "indeterminate"
        }
      )

    assert html =~ ~s(phx-click="toggle_select_all_page")
    assert html =~ "Select all visible items"
  end

  test "query mode is checked for all-matching selection without selected IDs" do
    html =
      render_component(&SelectAll.render/1,
        data: [%{id: "product-1"}],
        id_field: :id,
        loading: false,
        myself: nil,
        selectable: true,
        selected_ids: MapSet.new(),
        selection_mode: :all_matching,
        theme: %{
          select_all_container_class: "select-all",
          selection_checkbox_class: "checkbox",
          selection_indeterminate_class: "indeterminate"
        }
      )

    assert html =~ ~s(data-selection-state="all")
    assert html =~ ~s(aria-checked="true")
  end

  test "query mode is indeterminate when all-matching has exclusions" do
    html =
      render_component(&SelectAll.render/1,
        data: [%{id: "product-1"}],
        id_field: :id,
        loading: false,
        myself: nil,
        selectable: true,
        selected_ids: MapSet.new(["product-1"]),
        selection_mode: :all_matching,
        theme: %{
          select_all_container_class: "select-all",
          selection_checkbox_class: "checkbox",
          selection_indeterminate_class: "indeterminate"
        }
      )

    assert html =~ ~s(data-selection-state="some")
    assert html =~ ~s(aria-checked="mixed")
  end

  test "page mode ignores a cached query scope when deriving checkbox state" do
    html =
      render_component(&SelectAll.render/1,
        data: [%{id: "product-1"}],
        id_field: :id,
        loading: false,
        mode: :page,
        myself: nil,
        scope_ids: MapSet.new(["product-1", "product-2"]),
        selectable: true,
        selected_ids: MapSet.new(["product-1"]),
        theme: %{
          select_all_container_class: "select-all",
          selection_checkbox_class: "checkbox",
          selection_indeterminate_class: "indeterminate"
        }
      )

    assert html =~ ~s(data-selection-state="all")
  end
end
