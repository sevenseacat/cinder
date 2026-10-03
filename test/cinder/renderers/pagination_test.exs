defmodule Cinder.Renderers.PaginationTest do
  use ExUnit.Case, async: true
  import Phoenix.LiveViewTest

  alias Cinder.Renderers.Pagination

  defp build_theme do
    %{
      pagination_wrapper_class: "pagination-wrapper",
      pagination_container_class: "pagination-container",
      pagination_info_class: "pagination-info",
      pagination_count_class: "pagination-count",
      pagination_nav_class: "pagination-nav",
      pagination_button_class: "pagination-button",
      pagination_current_class: "pagination-current",
      page_size_container_class: "page-size-container",
      page_size_label_class: "page-size-label",
      page_size_dropdown_class: "page-size-dropdown",
      page_size_dropdown_container_class: "page-size-dropdown-container",
      page_size_option_class: "page-size-option",
      page_size_selected_class: "page-size-selected"
    }
  end

  defp base_assigns(id) do
    %{
      id: id,
      theme: build_theme(),
      page: %Ash.Page.Offset{
        results: [%{id: 1}, %{id: 2}],
        count: 100,
        offset: 0,
        limit: 10,
        more?: true
      },
      page_size_config: %{
        configurable: true,
        selected_page_size: 10,
        default_page_size: 10,
        page_size_options: [10, 25, 50]
      },
      myself: nil,
      show_pagination: true,
      pagination_mode: :offset
    }
  end

  describe "page size dropdown IDs" do
    test "dropdown ID is prefixed with table ID" do
      assigns = base_assigns("my-table")
      html = render_component(&Pagination.render/1, assigns)

      # The dropdown should have an ID prefixed with the table ID
      assert html =~ ~s(id="my-table-page-size-options")
    end

    test "different table IDs produce different dropdown IDs" do
      html1 = render_component(&Pagination.render/1, base_assigns("table-1"))
      html2 = render_component(&Pagination.render/1, base_assigns("table-2"))

      # Each table should have its own unique dropdown ID
      assert html1 =~ ~s(id="table-1-page-size-options")
      assert html2 =~ ~s(id="table-2-page-size-options")

      # They should NOT have the old hardcoded ID
      refute html1 =~ ~s(id="page-size-options")
      refute html2 =~ ~s(id="page-size-options")
    end

    test "JS toggle targets the correct prefixed ID" do
      assigns = base_assigns("users-table")
      html = render_component(&Pagination.render/1, assigns)

      # The toggle should target the prefixed ID
      assert html =~ ~s(#users-table-page-size-options)
    end
  end

  describe "keyset numbering" do
    test "renders a meaningful ordinal range on later pages" do
      assigns =
        base_assigns("keyset")
        |> Map.merge(%{pagination_mode: :keyset, current_page: 3})

      html = render_component(&Pagination.render/1, assigns)

      assert html =~ "Page 3"
      assert html =~ "showing 21-22 of 100"
    end

    test "renders cursor navigation without a total count" do
      assigns =
        base_assigns("keyset-no-count")
        |> Map.merge(%{
          pagination_mode: :keyset,
          current_page: 1,
          total_count: nil,
          page: %{base_assigns("unused").page | count: nil, more?: true}
        })

      html = render_component(&Pagination.render/1, assigns)

      assert html =~ "Page 1"
      assert html =~ "Next"
      refute html =~ "showing"
      refute html =~ " of "
    end

    test "keeps the footer after navigating backward to the first page" do
      page = %Ash.Page.Keyset{
        results: [%{id: 1}, %{id: 2}],
        count: nil,
        limit: 10,
        more?: false,
        after: nil,
        before: "page-2-first-cursor",
        rerun: nil
      }

      assigns =
        base_assigns("keyset-back-to-first")
        |> Map.merge(%{
          pagination_mode: :keyset,
          current_page: 1,
          total_count: nil,
          page: page
        })

      html = render_component(&Pagination.render/1, assigns)

      assert html =~ "Page 1"
      assert html =~ "Next"
      refute html =~ ~s(title="Previous page" disabled)
    end
  end

  describe "infinite pagination" do
    test "renders an ahead-of-viewport sentinel while more results remain" do
      assigns =
        base_assigns("items")
        |> Map.merge(%{
          pagination_mode: :infinite,
          current_page: 1,
          loaded_count: 10,
          loading: false,
          error: false
        })

      html = render_component(&Pagination.render/1, assigns)

      assert html =~ ~s(data-pagination-mode="infinite")
      assert html =~ ~s(phx-hook="CinderInfiniteSentinel")
      assert html =~ ~s(data-infinite-prefetch-distance="viewport")
      assert html =~ ~s(data-infinite-overscan="1")
      assert html =~ "h-px overflow-hidden p-0"
      assert html =~ "sr-only"
      assert html =~ "100 items"
      refute html =~ ~s(phx-viewport-bottom="load_more")
      refute html =~ ~s(id="items-page-size-options")
      refute html =~ "showing 1-10 of 100"
      assert html =~ ~s(class="pagination-info")
      assert html =~ ~s(data-key="pagination_info_class")
    end

    test "passes configured overscan to the automatic sentinel and keeps manual controls visible" do
      automatic =
        base_assigns("automatic-items")
        |> Map.merge(%{
          pagination_mode: :infinite,
          loaded_count: 10,
          loading: false,
          error: false,
          overscan: 3
        })

      assert render_component(&Pagination.render/1, automatic) =~
               ~s(data-infinite-overscan="3")

      manual = Map.put(automatic, :infinite_load, :manual)
      manual_html = render_component(&Pagination.render/1, manual)

      refute manual_html =~ ~s(phx-hook="CinderInfiniteSentinel")
      refute manual_html =~ "h-px overflow-hidden p-0"
      refute manual_html =~ "sr-only"
      assert manual_html =~ "Load more"
    end

    test "renders infinite navigation when count is disabled" do
      assigns =
        base_assigns("items-no-count")
        |> Map.merge(%{
          pagination_mode: :infinite,
          total_count: nil,
          page: %{base_assigns("unused").page | count: nil, more?: true},
          loaded_count: 10,
          loading: false,
          error: false
        })

      html = render_component(&Pagination.render/1, assigns)

      assert html =~ ~s(phx-hook="CinderInfiniteSentinel")
      refute html =~ "showing"
      refute html =~ ~s(data-pagination-state="counted")
    end

    test "renders loading, retry, and end states without another sentinel" do
      loading =
        base_assigns("items")
        |> Map.merge(%{pagination_mode: :infinite, loaded_count: 10, loading: true, error: false})

      assert render_component(&Pagination.render/1, loading) =~
               ~s(data-pagination-state="loading")

      failed = %{loading | loading: false, error: true}
      assert render_component(&Pagination.render/1, failed) =~ ~s(phx-click="retry_load_more")

      ended =
        failed
        |> Map.merge(%{error: false, page: %{failed.page | more?: false}})

      end_html = render_component(&Pagination.render/1, ended)
      assert end_html =~ ~s(data-pagination-state="end")
      assert end_html =~ "You have reached the end of this list"
      assert end_html =~ ~s(class="pagination-info")
      assert end_html =~ ~s(data-key="pagination_info_class")
      refute end_html =~ ~s(id="items-page-size-options")
      refute end_html =~ "showing"
      refute end_html =~ ~s(phx-hook="CinderInfiniteSentinel")
    end
  end

  describe "item numbering" do
    test "numbers keyset pages and accumulated infinite results" do
      page = %{limit: 10}

      assert Cinder.Renderers.Helpers.item_number(0, :keyset, 3, page) == 21
      assert Cinder.Renderers.Helpers.item_number(24, :infinite, 3, page) == 25
    end
  end
end
