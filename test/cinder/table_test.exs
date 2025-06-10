defmodule Cinder.TableTest do
  use ExUnit.Case, async: true
  import Phoenix.LiveViewTest

  alias Cinder.Table

  describe "component structure" do
    test "renders basic table with columns" do
      assigns = %{
        id: "test-table",
        query: MockResource,
        current_user: %{id: 1},
        col: [
          %{
            key: "title",
            label: "Title",
            sortable: true,
            inner_block: fn _item -> "Title Content" end
          },
          %{
            key: "artist",
            label: "Artist",
            filterable: true,
            inner_block: fn _item -> "Artist Content" end
          }
        ]
      }

      html = render_component(Table.LiveComponent, assigns)

      assert html =~ ~r/class="cinder-table/
      assert html =~ "Title"
      assert html =~ "Artist"
      assert html =~ "cinder-table-th"
    end

    test "applies default theme classes" do
      assigns = %{
        id: "test-table",
        query: MockResource,
        current_user: %{id: 1},
        col: [
          %{key: "title", label: "Title", inner_block: fn _item -> "Content" end}
        ]
      }

      html = render_component(Table.LiveComponent, assigns)

      assert html =~ "cinder-table-container"
      assert html =~ "cinder-table w-full border-collapse"
      assert html =~ "cinder-table-th px-4 py-2"
    end

    test "applies custom theme classes" do
      assigns = %{
        id: "test-table",
        query: MockResource,
        current_user: %{id: 1},
        theme: %{table_class: "custom-table", th_class: "custom-th"},
        col: [
          %{key: "title", label: "Title", inner_block: fn _item -> "Content" end}
        ]
      }

      html = render_component(Table.LiveComponent, assigns)

      assert html =~ "custom-table"
      assert html =~ "custom-th"
    end

    test "shows loading state initially" do
      assigns = %{
        id: "test-table",
        query: MockResource,
        current_user: %{id: 1},
        col: [
          %{key: "title", label: "Title", inner_block: fn _item -> "Content" end}
        ]
      }

      html = render_component(Table.LiveComponent, assigns)

      # Component shows loading initially until async data loads
      assert html =~ "Loading..."
      assert html =~ "cinder-table-loading"
    end

    test "shows loading state initially when no data" do
      assigns = %{
        id: "test-table",
        query: MockResource,
        current_user: %{id: 1},
        col: [
          %{key: "title", label: "Title", inner_block: fn _item -> "Content" end}
        ]
      }

      html = render_component(Table.LiveComponent, assigns)

      # Component starts with loading state before async data loads
      assert html =~ "Loading..."
      assert html =~ "cinder-table-loading"
    end

    test "parses column definitions correctly" do
      assigns = %{
        id: "test-table",
        query: MockResource,
        current_user: %{id: 1},
        col: [
          %{
            key: "title",
            label: "Album Title",
            sortable: true,
            searchable: true,
            filterable: false,
            options: ["rock", "pop"],
            inner_block: fn _item -> "Content" end
          }
        ]
      }

      html = render_component(Table.LiveComponent, assigns)

      assert html =~ "Album Title"
    end

    test "uses key as label when label not provided" do
      assigns = %{
        id: "test-table",
        query: MockResource,
        current_user: %{id: 1},
        col: [
          %{key: "title", inner_block: fn _item -> "Content" end}
        ]
      }

      html = render_component(Table.LiveComponent, assigns)

      assert html =~ "title"
    end

    test "renders sortable indicator placeholder" do
      assigns = %{
        id: "test-table",
        query: MockResource,
        current_user: %{id: 1},
        col: [
          %{key: "title", label: "Title", sortable: true, inner_block: fn _item -> "Content" end}
        ]
      }

      html = render_component(Table.LiveComponent, assigns)

      assert html =~ "cinder-sort-indicator"
    end
  end

  describe "pagination" do
    test "includes pagination wrapper" do
      assigns = %{
        id: "test-table",
        query: MockResource,
        current_user: %{id: 1},
        col: [
          %{key: "title", label: "Title", inner_block: fn _item -> "Content" end}
        ]
      }

      html = render_component(Table.LiveComponent, assigns)

      assert html =~ "cinder-pagination-wrapper"
    end

    test "does not show pagination controls for empty data" do
      assigns = %{
        id: "test-table",
        query: MockResource,
        current_user: %{id: 1},
        page_size: 5,
        col: [
          %{key: "title", label: "Title", inner_block: fn _item -> "Content" end}
        ]
      }

      html = render_component(Table.LiveComponent, assigns)

      assert html =~ "cinder-pagination-wrapper"
      # No pagination controls shown for empty data
      refute html =~ "Previous"
      refute html =~ "Next"
    end
  end

  describe "component initialization" do
    test "sets default values" do
      assigns = %{
        id: "test-table",
        query: MockResource,
        current_user: %{id: 1},
        col: []
      }

      html = render_component(Table.LiveComponent, assigns)

      # Component should render without errors with defaults
      assert html =~ "cinder-table-container"
    end

    test "accepts custom page size" do
      assigns = %{
        id: "test-table",
        query: MockResource,
        current_user: %{id: 1},
        page_size: 50,
        col: []
      }

      html = render_component(Table.LiveComponent, assigns)

      # Component should render without errors
      assert html =~ "cinder-table-container"
    end
  end

  describe "ash integration" do
    test "handles query options" do
      assigns = %{
        id: "test-table",
        query: MockResource,
        query_opts: [load: [:artist], select: [:title]],
        current_user: %{id: 1},
        col: [
          %{key: "title", label: "Title", inner_block: fn _item -> "Content" end}
        ]
      }

      html = render_component(Table.LiveComponent, assigns)

      # Component should render and handle query options
      assert html =~ "cinder-table-container"
    end

    test "passes current_user as actor" do
      assigns = %{
        id: "test-table",
        query: MockResource,
        current_user: %{id: 42, role: :admin},
        col: [
          %{key: "title", label: "Title", inner_block: fn _item -> "Content" end}
        ]
      }

      html = render_component(Table.LiveComponent, assigns)

      # Component should render with proper actor
      assert html =~ "cinder-table-container"
    end
  end
end

# Mock resources for testing
defmodule MockResource do
  def __ash_schema__ do
    %{attributes: []}
  end
end
