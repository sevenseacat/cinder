defmodule Cinder.Renderers.StateSlotsTest do
  @moduledoc """
  Tests for loading, empty, and error state slots across all renderers.
  """
  use ExUnit.Case, async: true
  import Phoenix.LiveViewTest

  alias Cinder.Renderers.Table, as: TableRenderer
  alias Cinder.Renderers.List, as: ListRenderer
  alias Cinder.Renderers.Grid, as: GridRenderer

  defp base_theme do
    %{
      container_class: "container",
      controls_class: "controls",
      empty_class: "empty",
      error_container_class: "error-container",
      error_message_class: "error-message",
      loading_overlay_class: "loading-overlay",
      loading_container_class: "loading-container",
      loading_spinner_class: "spinner",
      loading_spinner_circle_class: "spinner-circle",
      loading_spinner_path_class: "spinner-path",
      pagination_wrapper_class: "pagination",
      table_wrapper_class: "table-wrapper",
      table_class: "table",
      thead_class: "thead",
      tbody_class: "tbody",
      th_class: "th",
      td_class: "td",
      row_class: "row",
      header_row_class: "header-row",
      sort_indicator_class: "sort-indicator",
      list_container_class: "list-container",
      list_item_class: "list-item",
      list_item_clickable_class: "list-item-clickable",
      grid_container_class: "grid-container",
      grid_item_class: "grid-item",
      grid_item_clickable_class: "grid-item-clickable",
      bulk_actions_container_class: "bulk-actions"
    }
  end

  defp table_assigns(overrides \\ %{}) do
    col_slot = %{
      __slot__: :col,
      inner_block: fn _, _ -> "cell" end
    }

    base = %{
      id: "test",
      theme: base_theme(),
      data: [],
      columns: [
        %{field: :name, label: "Name", sortable: false, class: nil, slot: col_slot}
      ],
      filters: %{},
      sort_by: [],
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
      filters_label: "Filters",
      search_term: "",
      search_enabled: false,
      search_label: "Search",
      search_placeholder: "Search...",
      row_click: nil,
      selectable: false,
      selected_ids: MapSet.new(),
      bulk_action_slots: [],
      id_field: :id
    }

    Map.merge(base, overrides)
  end

  defp list_assigns(overrides \\ %{}) do
    base = %{
      id: "test",
      theme: base_theme(),
      data: [],
      columns: [],
      item_slot: [%{__slot__: :item, inner_block: fn _, _ -> "item content" end}],
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

    Map.merge(base, overrides)
  end

  defp grid_assigns(overrides \\ %{}) do
    base = %{
      id: "test",
      theme: base_theme(),
      data: [],
      columns: [],
      item_slot: [%{__slot__: :item, inner_block: fn _, _ -> "item content" end}],
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
      grid_columns: 3,
      item_click: nil,
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

    Map.merge(base, overrides)
  end

  defp make_slot(content) do
    [%{__slot__: :custom, inner_block: fn _, _ -> content end}]
  end

  defp make_slot_with_let(render_fn) do
    [%{__slot__: :custom, inner_block: fn _changed, ctx -> render_fn.(ctx) end}]
  end

  # ============================================================================
  # TABLE RENDERER
  # ============================================================================

  describe "table renderer - default states" do
    test "shows default empty message when no data and no error" do
      html = render_component(&TableRenderer.render/1, table_assigns())

      assert html =~ "No results found"
      refute html =~ "An error occurred"
    end

    test "shows default loading spinner when loading" do
      html = render_component(&TableRenderer.render/1, table_assigns(%{loading: true}))

      assert html =~ "loading-overlay"
      assert html =~ "Loading..."
      assert html =~ "<svg"
    end

    test "shows default error message when error" do
      html = render_component(&TableRenderer.render/1, table_assigns(%{error: true}))

      assert html =~ "An error occurred while loading data"
      assert html =~ "error-container"
      assert html =~ "error-message"
    end
  end

  describe "table renderer - custom slots" do
    test "custom loading slot replaces default spinner" do
      assigns =
        table_assigns(%{
          loading: true,
          loading_slot: make_slot("Custom spinner here")
        })

      html = render_component(&TableRenderer.render/1, assigns)

      assert html =~ "Custom spinner here"
      refute html =~ "<svg"
      refute html =~ "Loading..."
    end

    test "custom empty slot replaces default message" do
      assigns =
        table_assigns(%{
          empty_slot: make_slot("Nothing to see here")
        })

      html = render_component(&TableRenderer.render/1, assigns)

      assert html =~ "Nothing to see here"
      refute html =~ "No results found"
    end

    test "empty slot receives filtered? false when no filters active" do
      assigns =
        table_assigns(%{
          empty_slot:
            make_slot_with_let(fn ctx ->
              if ctx.filtered?, do: "HAS_FILTERS", else: "NO_FILTERS"
            end)
        })

      html = render_component(&TableRenderer.render/1, assigns)

      assert html =~ "NO_FILTERS"
      refute html =~ "HAS_FILTERS"
    end

    test "empty slot receives filtered? true and filter data when filters active" do
      assigns =
        table_assigns(%{
          filters: %{
            "name" => %{type: :text, value: "bob", operator: :contains}
          },
          empty_slot:
            make_slot_with_let(fn ctx ->
              if ctx.filtered?,
                do: "filtered: #{inspect(ctx.filters)}",
                else: "no filters"
            end)
        })

      html = render_component(&TableRenderer.render/1, assigns)

      assert html =~ "filtered:"
      assert html =~ "bob"
      refute html =~ "no filters"
    end

    test "empty slot receives filtered? false when filter present but value empty" do
      assigns =
        table_assigns(%{
          filters: %{
            "name" => %{type: :text, value: "", operator: :contains}
          },
          empty_slot:
            make_slot_with_let(fn ctx ->
              if ctx.filtered?, do: "HAS_FILTERS", else: "NO_FILTERS"
            end)
        })

      html = render_component(&TableRenderer.render/1, assigns)

      assert html =~ "NO_FILTERS"
    end

    test "empty slot receives filtered? true when search term active" do
      assigns =
        table_assigns(%{
          search_term: "hello",
          empty_slot:
            make_slot_with_let(fn ctx ->
              if ctx.filtered?,
                do: "searched: #{ctx.search_term}",
                else: "no search"
            end)
        })

      html = render_component(&TableRenderer.render/1, assigns)

      assert html =~ "searched: hello"
    end

    test "custom error slot replaces default error message" do
      assigns =
        table_assigns(%{
          error: true,
          error_slot: make_slot("Something went wrong! Try again.")
        })

      html = render_component(&TableRenderer.render/1, assigns)

      assert html =~ "Something went wrong! Try again."
      refute html =~ "An error occurred"
      refute html =~ "error-container"
    end
  end

  describe "table renderer - state precedence" do
    test "error state suppresses empty state" do
      html = render_component(&TableRenderer.render/1, table_assigns(%{error: true}))

      assert html =~ "An error occurred"
      refute html =~ "No results found"
    end

    test "loading state suppresses error state" do
      html =
        render_component(
          &TableRenderer.render/1,
          table_assigns(%{
            loading: true,
            error: true
          })
        )

      assert html =~ "Loading..."
      refute html =~ ~r/data-key="error_class"/
    end

    test "loading state suppresses empty state" do
      html = render_component(&TableRenderer.render/1, table_assigns(%{loading: true}))

      assert html =~ "Loading..."
      refute html =~ "No results found"
    end

    test "error_message string attr works without slot" do
      assigns =
        table_assigns(%{
          error: true,
          error_message: "Custom error text"
        })

      html = render_component(&TableRenderer.render/1, assigns)

      assert html =~ "Custom error text"
    end

    test "error state hides data rows even if stale data present" do
      assigns =
        table_assigns(%{
          error: true,
          data: [%{id: 1, name: "Stale Item"}]
        })

      html = render_component(&TableRenderer.render/1, assigns)

      assert html =~ "An error occurred"
      refute html =~ "Stale Item"
    end
  end

  # ============================================================================
  # LIST RENDERER
  # ============================================================================

  describe "list renderer - default states" do
    test "shows default empty message when no data and no error" do
      html = render_component(&ListRenderer.render/1, list_assigns())

      assert html =~ "No results found"
      refute html =~ "An error occurred"
    end

    test "shows default loading spinner when loading" do
      html = render_component(&ListRenderer.render/1, list_assigns(%{loading: true}))

      assert html =~ "loading-overlay"
      assert html =~ "Loading..."
    end

    test "shows default error message when error" do
      html = render_component(&ListRenderer.render/1, list_assigns(%{error: true}))

      assert html =~ "An error occurred while loading data"
      assert html =~ "error-container"
    end
  end

  describe "list renderer - custom slots" do
    test "custom loading slot replaces default spinner" do
      assigns =
        list_assigns(%{
          loading: true,
          loading_slot: make_slot("Custom list spinner")
        })

      html = render_component(&ListRenderer.render/1, assigns)

      assert html =~ "Custom list spinner"
      refute html =~ "<svg"
    end

    test "custom empty slot replaces default message" do
      assigns =
        list_assigns(%{
          empty_slot: make_slot("List is empty")
        })

      html = render_component(&ListRenderer.render/1, assigns)

      assert html =~ "List is empty"
      refute html =~ "No results found"
    end

    test "custom error slot replaces default error message" do
      assigns =
        list_assigns(%{
          error: true,
          error_slot: make_slot("List error! Retry?")
        })

      html = render_component(&ListRenderer.render/1, assigns)

      assert html =~ "List error! Retry?"
      refute html =~ "An error occurred"
    end
  end

  describe "list renderer - state precedence" do
    test "error state suppresses empty state" do
      html = render_component(&ListRenderer.render/1, list_assigns(%{error: true}))

      assert html =~ "An error occurred"
      refute html =~ "No results found"
    end

    test "loading state suppresses error state" do
      html =
        render_component(
          &ListRenderer.render/1,
          list_assigns(%{
            loading: true,
            error: true
          })
        )

      assert html =~ "Loading..."
      refute html =~ ~r/data-key="error_class"/
    end

    test "error state hides data items even if stale data present" do
      assigns =
        list_assigns(%{
          error: true,
          data: [%{id: 1, name: "Stale Item"}]
        })

      html = render_component(&ListRenderer.render/1, assigns)

      assert html =~ "An error occurred"
      refute html =~ "item content"
    end
  end

  # ============================================================================
  # GRID RENDERER
  # ============================================================================

  describe "grid renderer - default states" do
    test "shows default empty message when no data and no error" do
      html = render_component(&GridRenderer.render/1, grid_assigns())

      assert html =~ "No results found"
      refute html =~ "An error occurred"
    end

    test "shows default loading spinner when loading" do
      html = render_component(&GridRenderer.render/1, grid_assigns(%{loading: true}))

      assert html =~ "loading-overlay"
      assert html =~ "Loading..."
    end

    test "shows default error message when error" do
      html = render_component(&GridRenderer.render/1, grid_assigns(%{error: true}))

      assert html =~ "An error occurred while loading data"
      assert html =~ "error-container"
    end
  end

  describe "grid renderer - custom slots" do
    test "custom loading slot replaces default spinner" do
      assigns =
        grid_assigns(%{
          loading: true,
          loading_slot: make_slot("Custom grid spinner")
        })

      html = render_component(&GridRenderer.render/1, assigns)

      assert html =~ "Custom grid spinner"
      refute html =~ "<svg"
    end

    test "custom empty slot replaces default message" do
      assigns =
        grid_assigns(%{
          empty_slot: make_slot("Grid is empty")
        })

      html = render_component(&GridRenderer.render/1, assigns)

      assert html =~ "Grid is empty"
      refute html =~ "No results found"
    end

    test "custom error slot replaces default error message" do
      assigns =
        grid_assigns(%{
          error: true,
          error_slot: make_slot("Grid error! Retry?")
        })

      html = render_component(&GridRenderer.render/1, assigns)

      assert html =~ "Grid error! Retry?"
      refute html =~ "An error occurred"
    end
  end

  describe "grid renderer - state precedence" do
    test "error state suppresses empty state" do
      html = render_component(&GridRenderer.render/1, grid_assigns(%{error: true}))

      assert html =~ "An error occurred"
      refute html =~ "No results found"
    end

    test "loading state suppresses error state" do
      html =
        render_component(
          &GridRenderer.render/1,
          grid_assigns(%{
            loading: true,
            error: true
          })
        )

      assert html =~ "Loading..."
      refute html =~ ~r/data-key="error_class"/
    end

    test "error state hides data items even if stale data present" do
      assigns =
        grid_assigns(%{
          error: true,
          data: [%{id: 1, name: "Stale Item"}]
        })

      html = render_component(&GridRenderer.render/1, assigns)

      assert html =~ "An error occurred"
      refute html =~ "item content"
    end
  end

  # ============================================================================
  # BACKWARD COMPATIBILITY
  # ============================================================================

  describe "backward compatibility" do
    test "table renders normally without new assigns (slots default to empty)" do
      # No loading_slot, empty_slot, error_slot - should use defaults
      html = render_component(&TableRenderer.render/1, table_assigns())

      assert html =~ "No results found"
      refute html =~ "An error occurred"
    end

    test "loading_message string attr still works" do
      assigns =
        table_assigns(%{
          loading: true,
          loading_message: "Please wait..."
        })

      html = render_component(&TableRenderer.render/1, assigns)

      assert html =~ "Please wait..."
    end

    test "empty_message string attr still works" do
      assigns = table_assigns(%{empty_message: "Nothing here"})

      html = render_component(&TableRenderer.render/1, assigns)

      assert html =~ "Nothing here"
    end
  end
end
