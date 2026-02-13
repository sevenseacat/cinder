defmodule Cinder.Renderers.GridTest do
  use ExUnit.Case, async: true
  import Phoenix.LiveViewTest

  alias Cinder.Renderers.Grid, as: GridRenderer

  # Build a minimal theme with data-key attributes (mimics what Theme module generates)
  defp build_theme do
    %{
      container_class: "container",
      controls_class: "controls",
      empty_class: "empty",
      loading_overlay_class: "loading-overlay",
      loading_container_class: "loading-container",
      loading_spinner_class: "spinner",
      loading_spinner_circle_class: "spinner-circle",
      loading_spinner_path_class: "spinner-path",
      pagination_wrapper_class: "pagination",
      grid_container_class: "grid gap-4",
      grid_item_class: "p-4 bg-white border rounded-lg",
      grid_item_clickable_class: "cursor-pointer hover:shadow-md",
      bulk_actions_container_class: "bulk-actions"
    }
  end

  defp base_assigns do
    %{
      id: "test-grid",
      theme: build_theme(),
      data: [],
      columns: [],
      filters: %{},
      sort_by: [],
      sort_label: "Sort by:",
      loading: false,
      loading_message: "Loading...",
      empty_message: "No results found",
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
      item_slot: [%{__slot__: :item, inner_block: fn _, _ -> "item content" end}],
      filters_label: "Filters",
      search_term: "",
      search_enabled: false,
      search_label: "Search",
      search_placeholder: "Search...",
      selectable: false,
      selected_ids: MapSet.new(),
      bulk_action_slots: [],
      id_field: :id
    }
  end

  describe "data-key attributes" do
    test "includes data-key for grid container when using theme classes" do
      assigns = base_assigns()

      html = render_component(&GridRenderer.render/1, assigns)

      assert html =~ ~s(data-key="grid_container_class")
    end

    test "includes data-key for grid items when data is present" do
      assigns =
        base_assigns()
        |> Map.put(:data, [%{id: 1, name: "Test Item"}])

      html = render_component(&GridRenderer.render/1, assigns)

      assert html =~ ~s(data-key="grid_item_class")
    end

    test "includes data-key for clickable items" do
      click_fn = fn item -> Phoenix.LiveView.JS.navigate("/items/#{item.id}") end

      assigns =
        base_assigns()
        |> Map.put(:data, [%{id: 1, name: "Clickable Item"}])
        |> Map.put(:item_click, click_fn)

      html = render_component(&GridRenderer.render/1, assigns)

      # Clickable items get the clickable data-key (it overwrites base in merge)
      assert html =~ ~s(data-key="grid_item_clickable_class")
    end

    test "includes data-key even when custom container_class is provided" do
      assigns =
        base_assigns()
        |> Map.put(:container_class, "my-custom-grid")

      html = render_component(&GridRenderer.render/1, assigns)

      assert html =~ "my-custom-grid"
      assert html =~ ~s(data-key="grid_container_class")
    end

    test "includes data-key with responsive grid_columns" do
      assigns =
        base_assigns()
        |> Map.put(:grid_columns, xs: 1, md: 2, lg: 3)

      html = render_component(&GridRenderer.render/1, assigns)

      # Should still have data-key even with dynamic grid columns
      assert html =~ ~s(data-key="grid_container_class")
      assert html =~ "grid-cols-1"
      assert html =~ "md:grid-cols-2"
      assert html =~ "lg:grid-cols-3"
    end

    test "multiple items each have data-key attribute" do
      assigns =
        base_assigns()
        |> Map.put(:data, [
          %{id: 1, name: "Item 1"},
          %{id: 2, name: "Item 2"},
          %{id: 3, name: "Item 3"}
        ])

      html = render_component(&GridRenderer.render/1, assigns)

      # Count occurrences of the data-key attribute
      matches = Regex.scan(~r/data-key="grid_item_class"/, html)
      assert length(matches) == 3
    end
  end
end
