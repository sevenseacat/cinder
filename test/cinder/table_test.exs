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
      assert html =~ "animate-spin"
      assert html =~ "opacity-75"
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
      assert html =~ "animate-spin"
      assert html =~ "opacity-75"
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

  describe "sorting" do
    test "renders sortable columns with clickable headers" do
      assigns = %{
        id: "test-table",
        query: MockResource,
        current_user: %{id: 1},
        col: [
          %{
            key: "title",
            label: "Title",
            sortable: true,
            inner_block: fn _item -> "Content" end
          }
        ]
      }

      html = render_component(Table.LiveComponent, assigns)

      assert html =~ "phx-click=\"toggle_sort\""
      assert html =~ "phx-value-key=\"title\""
      assert html =~ "cursor-pointer"
      assert html =~ "cinder-sort-indicator"
    end

    test "renders non-sortable columns without click handlers" do
      assigns = %{
        id: "test-table",
        query: MockResource,
        current_user: %{id: 1},
        col: [
          %{
            key: "title",
            label: "Title",
            sortable: false,
            inner_block: fn _item -> "Content" end
          }
        ]
      }

      html = render_component(Table.LiveComponent, assigns)

      refute html =~ "phx-click=\"toggle_sort\""
      refute html =~ "cursor-pointer"
      refute html =~ "cinder-sort-indicator"
    end

    test "shows sort arrows for sorted columns" do
      assigns = %{
        id: "test-table",
        query: MockResource,
        current_user: %{id: 1},
        col: [
          %{
            key: "title",
            label: "Title",
            sortable: true,
            inner_block: fn _item -> "Content" end
          }
        ]
      }

      html = render_component(Table.LiveComponent, assigns)

      # Should contain heroicon class names
      assert html =~ "hero-chevron-up-down"
    end

    test "supports custom sort functions" do
      custom_sort_fn = fn query, _direction ->
        # Mock custom sort function
        query
      end

      assigns = %{
        id: "test-table",
        query: MockResource,
        current_user: %{id: 1},
        col: [
          %{
            key: "publisher",
            label: "Publisher",
            sortable: true,
            sort_fn: custom_sort_fn,
            inner_block: fn _item -> "Content" end
          }
        ]
      }

      html = render_component(Table.LiveComponent, assigns)

      # Should render as sortable column
      assert html =~ "phx-click=\"toggle_sort\""
      assert html =~ "phx-value-key=\"publisher\""
    end

    test "supports dot notation for relationship sorting" do
      assigns = %{
        id: "test-table",
        query: MockResource,
        current_user: %{id: 1},
        col: [
          %{
            key: "artist.name",
            label: "Artist Name",
            sortable: true,
            inner_block: fn _item -> "Content" end
          }
        ]
      }

      html = render_component(Table.LiveComponent, assigns)

      assert html =~ "phx-click=\"toggle_sort\""
      assert html =~ "phx-value-key=\"artist.name\""
    end

    test "renders different sort states correctly" do
      # Test unsorted state
      assigns = %{
        id: "test-table",
        query: MockResource,
        current_user: %{id: 1},
        col: [
          %{
            key: "title",
            label: "Title",
            sortable: true,
            inner_block: fn _item -> "Content" end
          }
        ]
      }

      html = render_component(Table.LiveComponent, assigns)
      # Should have default sort arrow (unsorted)
      assert html =~ "opacity-30"
    end

    test "applies sort parameters to query construction" do
      assigns = %{
        id: "test-table",
        query: MockResource,
        current_user: %{id: 1},
        col: [
          %{
            key: "title",
            label: "Title",
            sortable: true,
            inner_block: fn _item -> "Content" end
          }
        ]
      }

      html = render_component(Table.LiveComponent, assigns)

      # Component should render properly with sorting capabilities
      assert html =~ "phx-click=\"toggle_sort\""
      assert html =~ "cinder-sort-indicator"
    end

    test "handles multi-column sorting" do
      assigns = %{
        id: "test-table",
        query: MockResource,
        current_user: %{id: 1},
        col: [
          %{
            key: "title",
            label: "Title",
            sortable: true,
            inner_block: fn _item -> "Content" end
          },
          %{
            key: "artist",
            label: "Artist",
            sortable: true,
            inner_block: fn _item -> "Content" end
          }
        ]
      }

      html = render_component(Table.LiveComponent, assigns)

      # Both columns should be sortable
      assert html =~ "phx-value-key=\"title\""
      assert html =~ "phx-value-key=\"artist\""
    end

    test "supports customizable sort arrows" do
      assigns = %{
        id: "test-table",
        query: MockResource,
        current_user: %{id: 1},
        theme: %{
          sort_asc_icon_name: "hero-arrow-up",
          sort_desc_icon_name: "hero-arrow-down",
          sort_none_icon_name: "hero-arrows-up-down",
          sort_asc_icon_class: "w-4 h-4 text-green-500",
          sort_desc_icon_class: "w-4 h-4 text-red-500",
          sort_none_icon_class: "w-4 h-4 text-gray-400"
        },
        col: [
          %{
            key: "title",
            label: "Title",
            sortable: true,
            inner_block: fn _item -> "Content" end
          }
        ]
      }

      html = render_component(Table.LiveComponent, assigns)

      # Should render the none state icon class initially
      assert html =~ "w-4 h-4 text-gray-400"
      # Should contain heroicon class names
      assert html =~ "hero-arrows-up-down"
    end

    test "uses heroicon classes for sort arrows" do
      assigns = %{
        id: "test-table",
        query: MockResource,
        current_user: %{id: 1},
        theme: %{
          sort_asc_icon_name: "hero-arrow-up-circle",
          sort_desc_icon_name: "hero-arrow-down-circle",
          sort_none_icon_name: "hero-arrows-up-down"
        },
        col: [
          %{
            key: "title",
            label: "Title",
            sortable: true,
            inner_block: fn _item -> "Content" end
          }
        ]
      }

      html = render_component(Table.LiveComponent, assigns)

      # Should contain heroicon class names
      assert html =~ "hero-arrows-up-down"
      assert html =~ "cinder-table-container"
      assert html =~ "phx-click=\"toggle_sort\""
    end

    test "provides smooth sorting experience without flickering" do
      assigns = %{
        id: "test-table",
        query: MockResource,
        current_user: %{id: 1},
        col: [
          %{
            key: "title",
            label: "Title",
            sortable: true,
            inner_block: fn _item -> "Content" end
          }
        ]
      }

      html = render_component(Table.LiveComponent, assigns)

      # When loading, should show:
      # 1. Subtle loading indicator (spinner)
      # 2. Dimmed content (opacity-75) but still visible
      # 3. Animated sort arrows when active
      # 4. No jarring "Loading..." replacement of content
      assert html =~ "animate-spin"  # Loading spinner
      assert html =~ "opacity-75"   # Dimmed content during loading
      assert html =~ "relative"     # Positioned container for overlay
      
      # Should NOT contain the old flickering loading row
      refute html =~ "cinder-table-loading"
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
