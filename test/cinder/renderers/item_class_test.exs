defmodule Cinder.Renderers.ItemClassTest do
  @moduledoc """
  Tests for the `item_class` feature across all renderers.
  """

  use ExUnit.Case, async: true
  import Phoenix.LiveViewTest

  alias Cinder.Renderers.Table, as: TableRenderer
  alias Cinder.Renderers.List, as: ListRenderer
  alias Cinder.Renderers.Grid, as: GridRenderer

  # Two items that differ on `flagged`, so a per-item function produces two classes.
  @data [%{id: "1", flagged: true}, %{id: "2", flagged: false}]

  defp flag_class(item), do: if(item.flagged, do: "is-flagged", else: "not-flagged")

  # Each renderer uses the default theme with one identifiable item/row class to assert on.
  defp table_assigns do
    col_slot = %{__slot__: :col, field: :name, inner_block: fn _, _item -> "cell" end}

    %{
      id: "test-table",
      theme: Cinder.Theme.default() |> Map.put(:row_class, "theme-row"),
      data: @data,
      columns: [%{field: :name, label: "Name", sortable: false, class: nil, slot: col_slot}],
      col_slot: [col_slot],
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

  defp list_assigns do
    %{
      id: "test-list",
      theme: Cinder.Theme.default() |> Map.put(:list_item_class, "theme-item"),
      data: @data,
      columns: [],
      item_slot: [%{__slot__: :item, inner_block: fn _, _ -> "item content" end}],
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

  defp grid_assigns do
    list_assigns()
    |> Map.merge(%{
      id: "test-grid",
      theme: Cinder.Theme.default() |> Map.put(:grid_item_class, "theme-item"),
      grid_columns: [xs: 1]
    })
  end

  describe "table item_class" do
    test "applies a static string to every row, merged with the theme row class" do
      html =
        render_component(
          &TableRenderer.render/1,
          Map.put(table_assigns(), :item_class, "extra-row")
        )

      assert html =~ "theme-row"
      assert html =~ "extra-row"
    end

    test "evaluates a function per item, merged with the theme row class" do
      html =
        render_component(
          &TableRenderer.render/1,
          Map.put(table_assigns(), :item_class, &flag_class/1)
        )

      assert html =~ "is-flagged"
      assert html =~ "not-flagged"
      assert html =~ "theme-row"
    end

    test "is optional and defaults to the theme class only" do
      html = render_component(&TableRenderer.render/1, table_assigns())

      assert html =~ "theme-row"
      refute html =~ "is-flagged"
    end

    test "merges with cursor-pointer and selection classes" do
      assigns =
        table_assigns()
        |> Map.merge(%{
          item_class: &flag_class/1,
          selectable: true,
          selected_ids: MapSet.new(["1"])
        })

      html = render_component(&TableRenderer.render/1, assigns)

      assert html =~ "is-flagged"
      assert html =~ "bg-blue-50"
      assert html =~ "cursor-pointer"
    end
  end

  describe "list item_class" do
    test "evaluates a function per item, merged with the theme item class" do
      html =
        render_component(
          &ListRenderer.render/1,
          Map.put(list_assigns(), :item_class, &flag_class/1)
        )

      assert html =~ "is-flagged"
      assert html =~ "not-flagged"
      assert html =~ "theme-item"
    end

    test "is optional" do
      html = render_component(&ListRenderer.render/1, list_assigns())

      assert html =~ "theme-item"
      refute html =~ "is-flagged"
    end
  end

  describe "grid item_class" do
    test "evaluates a function per item, merged with the theme item class" do
      html =
        render_component(
          &GridRenderer.render/1,
          Map.put(grid_assigns(), :item_class, &flag_class/1)
        )

      assert html =~ "is-flagged"
      assert html =~ "not-flagged"
      assert html =~ "theme-item"
    end

    test "is optional" do
      html = render_component(&GridRenderer.render/1, grid_assigns())

      assert html =~ "theme-item"
      refute html =~ "is-flagged"
    end
  end
end
