defmodule Cinder.Collection.TableTest do
  # The theme integration tests change the global :default_theme config
  use ExUnit.Case, async: false
  import Phoenix.LiveViewTest
  import ExUnit.CaptureLog
  import Cinder.TestHelpers, only: [put_app_env: 2, delete_app_env: 1]

  # Mock Ash resource for testing
  defmodule TestUser do
    use Ash.Resource,
      domain: nil,
      data_layer: Ash.DataLayer.Ets,
      validate_domain_inclusion?: false

    ets do
      private?(true)
    end

    attributes do
      uuid_primary_key(:id)
      attribute(:name, :string)
      attribute(:email, :string)
      attribute(:age, :integer)
      attribute(:active, :boolean)
      attribute(:created_at, :utc_datetime)
    end

    actions do
      defaults([:create, :read, :update, :destroy])
    end
  end

  defmodule TestArtist do
    use Ash.Resource,
      domain: nil,
      data_layer: Ash.DataLayer.Ets,
      validate_domain_inclusion?: false

    ets do
      private?(true)
    end

    attributes do
      uuid_primary_key(:id)
      attribute(:name, :string)
    end

    actions do
      defaults([:create, :read, :update, :destroy])
    end
  end

  defmodule TestPublisher do
    use Ash.Resource,
      domain: nil,
      data_layer: Ash.DataLayer.Ets,
      validate_domain_inclusion?: false

    ets do
      private?(true)
    end

    attributes do
      uuid_primary_key(:id)
      attribute(:name, :string)
    end

    actions do
      defaults([:create, :read, :update, :destroy])
    end
  end

  defmodule TestAlbum do
    use Ash.Resource,
      domain: nil,
      data_layer: Ash.DataLayer.Ets,
      validate_domain_inclusion?: false

    ets do
      private?(true)
    end

    attributes do
      uuid_primary_key(:id)
      attribute(:title, :string)
      attribute(:release_date, :date)
      attribute(:status, TestStatusEnum)
      attribute(:artist_id, :uuid)
      attribute(:publisher_id, :uuid)
    end

    relationships do
      belongs_to(:artist, Cinder.Collection.TableTest.TestArtist)
      belongs_to(:publisher, Cinder.Collection.TableTest.TestPublisher)
    end

    actions do
      defaults([:create, :read, :update, :destroy])
    end
  end

  defmodule TestDomain do
    use Ash.Domain, validate_config_inclusion?: false

    resources do
      resource(TestUser)
      resource(TestArtist)
      resource(TestPublisher)
      resource(TestAlbum)
    end
  end

  defmodule TestStatusEnum do
    use Ash.Type.Enum,
      values: [
        draft: [label: "Draft"],
        published: [label: "Published"],
        archived: [label: "Archived"]
      ]
  end

  describe "table/1 function signature" do
    test "renders basic table with minimal configuration" do
      assigns = %{
        resource: TestUser,
        actor: nil,
        col: [
          %{field: "name", __slot__: :col},
          %{field: "email", __slot__: :col}
        ]
      }

      html = render_component(&Cinder.collection/1, assigns)

      assert html =~ "cinder-table"
    end

    test "accepts custom configuration" do
      assigns = %{
        resource: TestUser,
        actor: nil,
        id: "custom-table",
        page_size: 50,
        theme: "modern",
        class: "custom-class",
        col: [%{field: "name", __slot__: :col}]
      }

      html = render_component(&Cinder.collection/1, assigns)

      # Should contain custom class
      assert html =~ "custom-class"
      # Should apply modern theme
      assert html =~ "bg-white shadow-lg rounded-xl"
    end
  end

  describe "column processing integration" do
    test "creates columns with proper structure" do
      # Test that columns are processed with the expected structure
      assigns = %{
        resource: TestUser,
        actor: nil,
        col: [
          %{field: "name", filter: true, sort: true, label: "Full Name", __slot__: :col}
        ]
      }

      html = render_component(&Cinder.collection/1, assigns)

      # Should render without errors - this indirectly tests column processing
      assert html =~ "cinder-table"
      assert html =~ "Full Name"
    end

    test "handles relationship fields" do
      assigns = %{
        resource: TestAlbum,
        actor: nil,
        col: [
          %{field: "artist.name", filter: true, sort: true, __slot__: :col}
        ]
      }

      html = render_component(&Cinder.collection/1, assigns)

      # Should render without errors with relationship fields
      assert html =~ "cinder-table"
      assert html =~ "Artist &gt; Name"
    end

    test "string filter types render correct input types" do
      assigns = %{
        resource: TestUser,
        actor: nil,
        col: [
          %{field: "name", filter: "text", __slot__: :col},
          %{field: "age", filter: "number_range", __slot__: :col}
        ]
      }

      html = render_component(&Cinder.collection/1, assigns)

      # Text filter should render single text input
      assert html =~ ~r/name="filters\[name\]"/
      refute html =~ ~r/name="filters\[name_min\]"/

      # Number range filter should render min/max inputs
      assert html =~ ~r/name="filters\[age_min\]"/
      assert html =~ ~r/name="filters\[age_max\]"/
    end

    test "mixed string and atom filter types render correctly" do
      assigns = %{
        resource: TestUser,
        actor: nil,
        col: [
          %{field: "name", filter: "text", __slot__: :col},
          %{field: "age", filter: :number_range, __slot__: :col},
          # Inference would give a string field a text filter, so this shows the atom is used
          %{field: "email", filter: :date, __slot__: :col}
        ]
      }

      html = render_component(&Cinder.collection/1, assigns)

      # String "text" should render single input
      assert html =~ ~r/name="filters\[name\]"/
      refute html =~ ~r/name="filters\[name_min\]"/

      # Atom :number_range should render min/max inputs
      assert html =~ ~r/name="filters\[age_min\]"/
      assert html =~ ~r/name="filters\[age_max\]"/

      assert html =~ ~r/type="date"[^>]*name="filters\[email\]"/
    end

    test "unified filter format works correctly" do
      assigns = %{
        resource: TestUser,
        actor: nil,
        col: [
          %{field: "name", filter: [type: :text, placeholder: "Search name..."], __slot__: :col},
          %{field: "age", filter: [type: "number_range", min: 0, max: 100], __slot__: :col}
        ]
      }

      html = render_component(&Cinder.collection/1, assigns)

      # Text filter should render with custom placeholder
      assert html =~ ~r/placeholder="Search name\.\.\."/
      assert html =~ ~r/name="filters\[name\]"/
      refute html =~ ~r/name="filters\[name_min\]"/

      # Number range filter should render min/max inputs
      assert html =~ ~r/name="filters\[age_min\]"/
      assert html =~ ~r/name="filters\[age_max\]"/
    end

    test "backward compatibility with old filter_options format" do
      # Capture logs to test deprecation warning
      logs =
        capture_log(fn ->
          assigns = %{
            resource: TestUser,
            actor: nil,
            col: [
              %{
                field: "name",
                filter: :text,
                filter_options: [placeholder: "Old format"],
                __slot__: :col
              }
            ]
          }

          html = render_component(&Cinder.collection/1, assigns)

          # Should still work with old format
          assert html =~ ~r/placeholder="Old format"/
        end)

      # Should log deprecation warning
      assert logs =~
               "[DEPRECATED] Field 'name' uses the filter_options attribute, which is removed in 1.0"
    end

    test "unified format takes precedence over legacy filter_options" do
      # Capture logs to test deprecation warning
      logs =
        capture_log(fn ->
          assigns = %{
            resource: TestUser,
            actor: nil,
            col: [
              %{
                field: "name",
                filter: [type: :text, placeholder: "New format"],
                filter_options: [placeholder: "Old format"],
                __slot__: :col
              }
            ]
          }

          html = render_component(&Cinder.collection/1, assigns)

          # New format should win
          assert html =~ ~r/placeholder="New format"/
          refute html =~ ~r/placeholder="Old format"/
        end)

      # Should still log deprecation warning
      assert logs =~
               "[DEPRECATED] Field 'name' uses the filter_options attribute, which is removed in 1.0"
    end
  end

  describe "show filters behavior" do
    test "auto-detects filters when columns are filterable" do
      assigns = %{
        resource: TestUser,
        actor: nil,
        col: [
          %{field: "name", filter: true, __slot__: :col}
        ]
      }

      html = render_component(&Cinder.collection/1, assigns)

      # Should show filters automatically when columns are filterable
      assert html =~ "cinder-table"
      assert html =~ "Filter Name"
    end

    test "respects explicit show_filters setting" do
      assigns = %{
        resource: TestUser,
        actor: nil,
        show_filters: false,
        col: [
          %{field: "name", filter: true, __slot__: :col}
        ]
      }

      html = render_component(&Cinder.collection/1, assigns)

      # Should respect explicit show_filters = false
      assert html =~ "cinder-table"
      refute html =~ "Filter Name"
    end
  end

  describe "theme integration" do
    test "uses configured default theme when no theme specified" do
      put_app_env(:default_theme, "modern")

      assigns = %{
        resource: TestUser,
        actor: nil,
        col: [%{field: "name", __slot__: :col}]
      }

      html = render_component(&Cinder.collection/1, assigns)

      # Should use modern theme (has shadow-lg class)
      assert html =~ "cinder-table"
      assert html =~ "shadow-lg"
    end

    test "explicit theme overrides configured default theme" do
      put_app_env(:default_theme, "modern")

      assigns = %{
        resource: TestUser,
        actor: nil,
        theme: "dark",
        col: [%{field: "name", __slot__: :col}]
      }

      html = render_component(&Cinder.collection/1, assigns)

      # Should use dark theme (has gray-800 class), not modern theme
      assert html =~ "cinder-table"
      assert html =~ "gray-900"
      refute html =~ "shadow-lg"
    end

    test "uses system default when no config and no explicit theme" do
      delete_app_env(:default_theme)

      assigns = %{
        resource: TestUser,
        actor: nil,
        col: [%{field: "name", __slot__: :col}]
      }

      html = render_component(&Cinder.collection/1, assigns)

      # Should use system default theme
      assert html =~ "cinder-table"
      # Default theme has minimal styling
      refute html =~ "shadow-lg"
      refute html =~ "gray-800"
    end

    test "handles theme modules in configuration" do
      put_app_env(:default_theme, Cinder.Themes.Retro)

      assigns = %{
        resource: TestUser,
        actor: nil,
        col: [%{field: "name", __slot__: :col}]
      }

      html = render_component(&Cinder.collection/1, assigns)

      # Should use retro theme
      assert html =~ "cinder-table"
      assert html =~ "bg-gray-900" || html =~ "border-cyan-400"
    end
  end

  describe "automatic filter type inference" do
    test "infers number range filter for integer fields" do
      assigns = %{
        resource: TestUser,
        actor: nil,
        col: [
          %{field: "age", filter: true, __slot__: :col}
        ]
      }

      html = render_component(&Cinder.collection/1, assigns)

      # Should render with number range filter (min/max inputs)
      assert html =~ "cinder-table"
      # The age field should get a number range filter with min/max inputs
      assert html =~ ~r/name="filters\[age_min\]"/
      assert html =~ ~r/name="filters\[age_max\]"/
    end

    test "uses explicit filter type when specified" do
      assigns = %{
        resource: TestUser,
        actor: nil,
        col: [
          %{field: "age", filter: :text, __slot__: :col}
        ]
      }

      html = render_component(&Cinder.collection/1, assigns)

      # Should use text filter instead of number range when explicitly specified
      assert html =~ "cinder-table"
      assert html =~ ~r/name="filters\[age\]"/
      refute html =~ ~r/name="filters\[age_min\]"/
    end
  end

  describe "edge cases and error handling" do
    test "handles empty column list" do
      assigns = %{
        resource: TestUser,
        actor: nil,
        col: []
      }

      html = render_component(&Cinder.collection/1, assigns)

      # Should handle empty columns gracefully
      assert html =~ "cinder-table"
    end
  end

  # ============================================================================
  # BACKWARD COMPATIBILITY TESTS
  # These tests establish a contract that must not be violated during refactoring.
  # ============================================================================

  describe "backward compatibility: message customization" do
    test "loading_message attribute customizes loading text" do
      assigns = %{
        resource: TestUser,
        actor: nil,
        loading_message: "Please wait, fetching data...",
        col: [%{field: "name", __slot__: :col}]
      }

      html = render_component(&Cinder.collection/1, assigns)

      # Custom loading message should be present in the rendered HTML
      assert html =~ "Please wait, fetching data..."
    end

    test "filters_label attribute customizes filter section label" do
      assigns = %{
        resource: TestUser,
        actor: nil,
        filters_label: "Search Options",
        col: [%{field: "name", filter: true, __slot__: :col}]
      }

      html = render_component(&Cinder.collection/1, assigns)

      # Custom filters label should be present in the rendered HTML
      assert html =~ "Search Options"
    end

    test "default messages are used when not specified" do
      assigns = %{
        resource: TestUser,
        actor: nil,
        col: [%{field: "name", filter: true, __slot__: :col}]
      }

      html = render_component(&Cinder.collection/1, assigns)

      # Default loading message should be present (component starts in loading state)
      assert html =~ "Loading..."
      # Default filters label should be present
      assert html =~ "Filters"
      # Note: "No results found" is only shown when data is empty AND not loading,
      # which doesn't occur in static render tests
    end
  end

  describe "backward compatibility: event parameter structures" do
    # These tests document the expected event parameter structures
    # that must be preserved during refactoring
  end

  describe "backward compatibility: state notification payload" do
    test "notify_state_change sends correct payload structure" do
      # This test documents the expected state change payload structure
      # that parent LiveViews depend on for URL synchronization

      socket = %{
        assigns: %{
          on_state_change: :table_changed,
          id: "test-table"
        }
      }

      state = %{
        filters: %{"name" => %{type: :text, value: "test", operator: :contains}},
        current_page: 2,
        sort_by: [{"name", :asc}],
        page_size: 25,
        default_page_size: 10,
        search_term: "search query",
        filter_field_names: ["name", "email", "status"]
      }

      Cinder.UrlManager.notify_state_change(socket, state)

      # Verify message was sent with correct structure
      assert_received {:table_changed, "test-table", encoded_state}

      # Verify encoded state contains expected keys
      assert Map.has_key?(encoded_state, :name)
      assert Map.has_key?(encoded_state, :page)
      assert Map.has_key?(encoded_state, :sort)
      assert Map.has_key?(encoded_state, :page_size)
      assert Map.has_key?(encoded_state, :search)
      # filter_field_names is encoded as _filter_fields
      assert Map.has_key?(encoded_state, :_filter_fields)
    end

    test "filter_field_names are included in state notification" do
      socket = %{
        assigns: %{
          on_state_change: :table_changed,
          id: "test-table"
        }
      }

      state = %{
        filters: %{},
        current_page: 1,
        sort_by: [],
        page_size: 25,
        default_page_size: 25,
        search_term: "",
        filter_field_names: ["field1", "field2", "field3"]
      }

      Cinder.UrlManager.notify_state_change(socket, state)

      assert_received {:table_changed, "test-table", encoded_state}

      # filter_field_names should be comma-separated in _filter_fields
      assert encoded_state[:_filter_fields] == "field1,field2,field3"
    end
  end

  describe "backward compatibility: all public attributes accepted" do
    test "all documented public attributes are accepted without error" do
      # This test verifies all public API attributes work together
      assigns = %{
        # Resource/Query
        resource: TestUser,
        query: nil,
        # Authorization
        actor: nil,
        tenant: nil,
        scope: nil,
        # Configuration
        id: "my-table",
        page_size: [default: 25, options: [10, 25, 50]],
        theme: "default",
        url_state: false,
        query_opts: [],
        on_state_change: nil,
        # Display options
        show_pagination: true,
        show_filters: true,
        loading_message: "Loading...",
        filters_label: "Filters",
        empty_message: "No data",
        class: "my-custom-class",
        # Search
        search: [label: "Search", placeholder: "Type to search..."],
        # Row interaction
        click: nil,
        # Columns
        col: [
          %{field: "name", filter: true, sort: true, search: true, __slot__: :col},
          %{field: "email", filter: :text, __slot__: :col}
        ]
      }

      # Should render without errors
      html = render_component(&Cinder.collection/1, assigns)
      assert html =~ "cinder-table"
      assert html =~ "my-custom-class"
    end
  end
end
