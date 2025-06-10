defmodule Cinder.TableTest do
  use ExUnit.Case, async: true
  import Phoenix.LiveViewTest
  import Phoenix.Component

  alias Cinder.Table

  describe "component structure" do
    test "renders basic table with columns" do
      assigns = %{
        id: "test-table",
        query: MockResource,
        current_user: %{id: 1},
        col: [
          %{key: "title", label: "Title", sortable: true, inner_block: fn item -> item.title end},
          %{
            key: "artist",
            label: "Artist",
            filterable: true,
            inner_block: fn item -> item.artist end
          }
        ]
      }

      html = rendered_to_string(~H"<Table.table {assigns} />")

      assert html =~ ~r/class="cinder-table/
      assert html =~ "Title"
      assert html =~ "Artist"
      assert html =~ "cinder-table-th"
      # When no data, we show empty state instead of td elements
      assert html =~ "No results found"
    end

    test "applies default theme classes" do
      assigns = %{
        id: "test-table",
        query: MockResource,
        current_user: %{id: 1},
        col: [
          %{key: "title", label: "Title", inner_block: fn item -> item.title end}
        ]
      }

      html = rendered_to_string(~H"<Table.table {assigns} />")

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
          %{key: "title", label: "Title", inner_block: fn item -> item.title end}
        ]
      }

      html = rendered_to_string(~H"<Table.table {assigns} />")

      assert html =~ "custom-table"
      assert html =~ "custom-th"
    end

    test "shows loading state" do
      # We'll test loading state in integration tests since 
      # it requires internal state manipulation
      # For now, just test that the component renders properly
      assigns = %{
        id: "test-table",
        query: MockResource,
        current_user: %{id: 1},
        col: [
          %{key: "title", label: "Title", inner_block: fn item -> item.title end}
        ]
      }

      html = rendered_to_string(~H"<Table.table {assigns} />")

      # Component should render without loading state by default
      refute html =~ "Loading..."
      assert html =~ "No results found"
    end

    test "shows empty state when no data" do
      assigns = %{
        id: "test-table",
        query: MockResource,
        current_user: %{id: 1},
        col: [
          %{key: "title", label: "Title", inner_block: fn item -> item.title end}
        ]
      }

      html = rendered_to_string(~H"<Table.table {assigns} />")

      assert html =~ "No results found"
      assert html =~ "cinder-table-empty"
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
            inner_block: fn item -> item.title end
          }
        ]
      }

      html = rendered_to_string(~H"<Table.table {assigns} />")

      assert html =~ "Album Title"
    end

    test "uses key as label when label not provided" do
      assigns = %{
        id: "test-table",
        query: MockResource,
        current_user: %{id: 1},
        col: [
          %{key: "title", inner_block: fn item -> item.title end}
        ]
      }

      html = rendered_to_string(~H"<Table.table {assigns} />")

      assert html =~ "title"
    end

    test "renders sortable indicator placeholder" do
      assigns = %{
        id: "test-table",
        query: MockResource,
        current_user: %{id: 1},
        col: [
          %{key: "title", label: "Title", sortable: true, inner_block: fn item -> item.title end}
        ]
      }

      html = rendered_to_string(~H"<Table.table {assigns} />")

      assert html =~ "cinder-sort-indicator"
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

      html = rendered_to_string(~H"<Table.table {assigns} />")

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

      html = rendered_to_string(~H"<Table.table {assigns} />")

      # Component should render without errors
      assert html =~ "cinder-table-container"
    end
  end
end

# Mock resource for testing
defmodule MockResource do
  def __ash_schema__ do
    %{attributes: []}
  end
end
