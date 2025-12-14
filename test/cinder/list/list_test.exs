defmodule Cinder.ListTest do
  use ExUnit.Case, async: true
  import Phoenix.LiveViewTest

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
      attribute(:status, :string)
    end

    actions do
      defaults([:create, :read, :update, :destroy])
    end
  end

  defmodule TestDomain do
    use Ash.Domain, validate_config_inclusion?: false

    resources do
      resource(TestUser)
    end
  end

  describe "list/1 function signature" do
    test "renders basic list with minimal configuration" do
      assigns = %{
        resource: TestUser,
        actor: nil,
        col: [
          %{field: "name", __slot__: :col}
        ],
        item: [
          %{__slot__: :item, inner_block: fn _, _ -> "test" end}
        ]
      }

      html = render_component(&Cinder.List.list/1, assigns)

      assert html =~ "cinder-list"
    end

    test "applies intelligent defaults" do
      assigns = %{
        resource: TestUser,
        actor: nil,
        col: [%{field: "name", __slot__: :col}],
        item: []
      }

      html = render_component(&Cinder.List.list/1, assigns)

      # Should render successfully with default configuration
      assert html =~ "cinder-list"
    end

    test "accepts custom id" do
      assigns = %{
        resource: TestUser,
        actor: nil,
        id: "my-custom-list",
        col: [%{field: "name", __slot__: :col}],
        item: []
      }

      html = render_component(&Cinder.List.list/1, assigns)

      assert html =~ "cinder-list"
    end

    test "accepts custom class" do
      assigns = %{
        resource: TestUser,
        actor: nil,
        class: "my-custom-class",
        col: [%{field: "name", __slot__: :col}],
        item: []
      }

      html = render_component(&Cinder.List.list/1, assigns)

      assert html =~ "my-custom-class"
    end

    test "accepts container_class for grid layouts" do
      assigns = %{
        resource: TestUser,
        actor: nil,
        container_class: "grid grid-cols-3 gap-4",
        col: [%{field: "name", __slot__: :col}],
        item: []
      }

      html = render_component(&Cinder.List.list/1, assigns)

      assert html =~ "cinder-list"
      # Verify the custom container class is rendered (overrides theme default)
      assert html =~ "grid grid-cols-3 gap-4"
    end
  end

  describe "sort controls" do
    test "shows sort controls when columns have sort enabled" do
      assigns = %{
        resource: TestUser,
        actor: nil,
        col: [
          %{field: "name", sort: true, __slot__: :col},
          %{field: "email", sort: true, __slot__: :col}
        ],
        item: []
      }

      html = render_component(&Cinder.List.list/1, assigns)

      # Should have sort controls
      assert html =~ "Sort by:"
    end

    test "hides sort controls when no sortable columns" do
      assigns = %{
        resource: TestUser,
        actor: nil,
        col: [
          %{field: "name", __slot__: :col},
          %{field: "email", __slot__: :col}
        ],
        item: []
      }

      html = render_component(&Cinder.List.list/1, assigns)

      # Should not have sort controls
      refute html =~ "Sort by:"
    end

    test "accepts custom sort_label" do
      assigns = %{
        resource: TestUser,
        actor: nil,
        sort_label: "Order by:",
        col: [
          %{field: "name", sort: true, __slot__: :col}
        ],
        item: []
      }

      html = render_component(&Cinder.List.list/1, assigns)

      assert html =~ "Order by:"
    end

    test "show_sort=false hides sort controls even with sortable columns" do
      assigns = %{
        resource: TestUser,
        actor: nil,
        show_sort: false,
        col: [
          %{field: "name", sort: true, __slot__: :col}
        ],
        item: []
      }

      html = render_component(&Cinder.List.list/1, assigns)

      refute html =~ "Sort by:"
    end
  end

  describe "filter controls" do
    test "shows filter controls when columns are filterable" do
      assigns = %{
        resource: TestUser,
        actor: nil,
        col: [
          %{field: "name", filter: true, __slot__: :col}
        ],
        item: []
      }

      html = render_component(&Cinder.List.list/1, assigns)

      # Should have filter controls
      assert html =~ "filter_container_class"
    end

    test "hides filter controls when no filterable columns" do
      assigns = %{
        resource: TestUser,
        actor: nil,
        col: [
          %{field: "name", __slot__: :col}
        ],
        item: []
      }

      html = render_component(&Cinder.List.list/1, assigns)

      # Should not have filter controls
      refute html =~ "filter_container_class"
    end

    test "show_filters=false hides filter controls even with filterable columns" do
      assigns = %{
        resource: TestUser,
        actor: nil,
        show_filters: false,
        col: [
          %{field: "name", filter: true, __slot__: :col}
        ],
        item: []
      }

      html = render_component(&Cinder.List.list/1, assigns)

      refute html =~ "filter_container_class"
    end
  end

  describe "message customization" do
    test "loading_message attribute customizes loading text" do
      assigns = %{
        resource: TestUser,
        actor: nil,
        loading_message: "Please wait...",
        col: [%{field: "name", __slot__: :col}],
        item: []
      }

      html = render_component(&Cinder.List.list/1, assigns)

      assert html =~ "Please wait..."
    end

    test "empty_message attribute customizes empty state text" do
      assigns = %{
        resource: TestUser,
        actor: nil,
        empty_message: "No items found",
        col: [%{field: "name", __slot__: :col}],
        item: []
      }

      # empty_message is passed to component but only rendered when data is empty and not loading
      html = render_component(&Cinder.List.list/1, assigns)
      assert html =~ "cinder-list"
    end

    test "filters_label attribute customizes filter section label" do
      assigns = %{
        resource: TestUser,
        actor: nil,
        filters_label: "Search Options",
        col: [%{field: "name", filter: true, __slot__: :col}],
        item: []
      }

      html = render_component(&Cinder.List.list/1, assigns)

      assert html =~ "Search Options"
    end
  end

  describe "missing item slot" do
    test "logs warning when no item slot provided" do
      import ExUnit.CaptureLog

      assigns = %{
        resource: TestUser,
        actor: nil,
        col: [%{field: "name", __slot__: :col}],
        item: []
      }

      log =
        capture_log(fn ->
          render_component(&Cinder.List.list/1, assigns)
        end)

      # Should log a warning about missing item slot
      assert log =~ "No <:item> slot provided"
    end
  end

  describe "item_click attribute" do
    test "accepts item_click function" do
      item_click_fn = fn item -> Phoenix.LiveView.JS.navigate("/users/#{item.id}") end

      assigns = %{
        resource: TestUser,
        actor: nil,
        item_click: item_click_fn,
        col: [%{field: "name", __slot__: :col}],
        item: []
      }

      html = render_component(&Cinder.List.list/1, assigns)

      # Should render list successfully with item_click attribute
      assert html =~ "cinder-list"
    end
  end

  describe "page_size configuration" do
    test "supports simple integer page size" do
      assigns = %{
        resource: TestUser,
        actor: nil,
        page_size: 50,
        col: [%{field: "name", __slot__: :col}],
        item: []
      }

      html = render_component(&Cinder.List.list/1, assigns)

      assert html =~ "cinder-list"
    end

    test "supports configurable page size format" do
      assigns = %{
        resource: TestUser,
        actor: nil,
        page_size: [default: 25, options: [10, 25, 50]],
        col: [%{field: "name", __slot__: :col}],
        item: []
      }

      html = render_component(&Cinder.List.list/1, assigns)

      assert html =~ "cinder-list"
    end
  end
end
