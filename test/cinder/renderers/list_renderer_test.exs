defmodule Cinder.Renderers.ListTest do
  use ExUnit.Case, async: true
  import Phoenix.LiveViewTest

  alias Cinder.Renderers.List, as: ListRenderer

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
      list_container_class: "divide-y divide-gray-200",
      list_item_class: "py-3 px-4",
      list_item_clickable_class: "cursor-pointer hover:bg-gray-50",
      bulk_actions_container_class: "bulk-actions"
    }
  end

  defp base_assigns do
    %{
      id: "test-list",
      theme: build_theme(),
      data: [],
      columns: [],
      filters: %{},
      sort_by: [],
      sort_label: "Sort by:",
      loading: false,
      error: false,
      loading_message: "Loading...",
      empty_message: "No results found",
      error_message: "An error occurred while loading data",
      show_filters: false,
      show_sort: false,
      show_pagination: false,
      page: nil,
      page_size_config: %{},
      pagination_mode: :offset,
      myself: nil,
      container_class: nil,
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
    test "supports toggle filter mode without raising" do
      assigns =
        base_assigns()
        |> Map.put(:show_filters, :toggle)

      html = render_component(&ListRenderer.render/1, assigns)

      assert html =~ ~s(data-key="controls_class")
    end

    test "includes data-key for list container when using theme classes" do
      assigns = base_assigns()

      html = render_component(&ListRenderer.render/1, assigns)

      assert html =~ ~s(data-key="list_container_class")
    end

    test "includes data-key for list items when data is present" do
      assigns =
        base_assigns()
        |> Map.put(:data, [%{id: 1, name: "Test Item"}])

      html = render_component(&ListRenderer.render/1, assigns)

      assert html =~ ~s(data-key="list_item_class")
    end

    test "includes data-key for clickable items" do
      click_fn = fn item -> Phoenix.LiveView.JS.navigate("/items/#{item.id}") end

      assigns =
        base_assigns()
        |> Map.put(:data, [%{id: 1, name: "Clickable Item"}])
        |> Map.put(:item_click, click_fn)

      html = render_component(&ListRenderer.render/1, assigns)

      # Clickable items get the clickable data-key (it overwrites base in merge)
      assert html =~ ~s(data-key="list_item_clickable_class")
    end

    test "includes data-key even when custom container_class is provided" do
      assigns =
        base_assigns()
        |> Map.put(:container_class, "my-custom-container")

      html = render_component(&ListRenderer.render/1, assigns)

      assert html =~ "my-custom-container"
      assert html =~ ~s(data-key="list_container_class")
    end

    test "multiple items each have data-key attribute" do
      assigns =
        base_assigns()
        |> Map.put(:data, [
          %{id: 1, name: "Item 1"},
          %{id: 2, name: "Item 2"},
          %{id: 3, name: "Item 3"}
        ])

      html = render_component(&ListRenderer.render/1, assigns)

      # Count occurrences of the data-key attribute
      matches = Regex.scan(~r/data-key="list_item_class"/, html)
      assert length(matches) == 3
    end
  end
end
