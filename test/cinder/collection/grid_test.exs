defmodule Cinder.Collection.GridTest do
  use ExUnit.Case, async: true
  import Phoenix.LiveViewTest

  defmodule TestProduct do
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
      attribute(:category, :string)
      attribute(:price, :decimal)
    end

    actions do
      defaults([:create, :read, :update, :destroy])
    end
  end

  defmodule TestDomain do
    use Ash.Domain, validate_config_inclusion?: false

    resources do
      resource(TestProduct)
    end
  end

  # Helper to create a basic item slot
  defp item_slot do
    [%{__slot__: :item, inner_block: fn _, _ -> "item content" end}]
  end

  describe "grid layout" do
    test "renders with layout={:grid}" do
      assigns = %{
        resource: TestProduct,
        actor: nil,
        layout: :grid,
        col: [%{field: "name", __slot__: :col}],
        item: item_slot()
      }

      html = render_component(&Cinder.collection/1, assigns)

      assert html =~ "cinder-grid"
    end

    test "renders with layout=\"grid\" (string)" do
      assigns = %{
        resource: TestProduct,
        actor: nil,
        layout: "grid",
        col: [%{field: "name", __slot__: :col}],
        item: item_slot()
      }

      html = render_component(&Cinder.collection/1, assigns)

      assert html =~ "cinder-grid"
    end

    test "logs warning when no item slot provided" do
      import ExUnit.CaptureLog

      assigns = %{
        resource: TestProduct,
        actor: nil,
        layout: :grid,
        col: [%{field: "name", __slot__: :col}],
        item: []
      }

      log =
        capture_log(fn ->
          render_component(&Cinder.collection/1, assigns)
        end)

      assert log =~ "No <:item> slot provided"
    end

    test "shows sort controls when columns have sort enabled" do
      assigns = %{
        resource: TestProduct,
        actor: nil,
        layout: :grid,
        col: [
          %{field: "name", sort: true, __slot__: :col},
          %{field: "price", sort: true, __slot__: :col}
        ],
        item: item_slot()
      }

      html = render_component(&Cinder.collection/1, assigns)

      assert html =~ "Sort by:"
    end

    test "accepts click function" do
      click_fn = fn item -> Phoenix.LiveView.JS.navigate("/products/#{item.id}") end

      assigns = %{
        resource: TestProduct,
        actor: nil,
        layout: :grid,
        click: click_fn,
        col: [%{field: "name", __slot__: :col}],
        item: item_slot()
      }

      html = render_component(&Cinder.collection/1, assigns)

      assert html =~ "cinder-grid"
    end
  end

  describe "grid_columns attribute" do
    test "accepts integer value" do
      assigns = %{
        resource: TestProduct,
        actor: nil,
        layout: :grid,
        grid_columns: 4,
        col: [%{field: "name", __slot__: :col}],
        item: item_slot()
      }

      html = render_component(&Cinder.collection/1, assigns)

      assert html =~ "grid-cols-4"
      assert html =~ "gap-4"
    end

    test "accepts string integer value" do
      assigns = %{
        resource: TestProduct,
        actor: nil,
        layout: :grid,
        grid_columns: "6",
        col: [%{field: "name", __slot__: :col}],
        item: item_slot()
      }

      html = render_component(&Cinder.collection/1, assigns)

      assert html =~ "grid-cols-6"
    end

    test "accepts responsive keyword list" do
      assigns = %{
        resource: TestProduct,
        actor: nil,
        layout: :grid,
        grid_columns: [xs: 1, md: 2, lg: 3, xl: 4],
        col: [%{field: "name", __slot__: :col}],
        item: item_slot()
      }

      html = render_component(&Cinder.collection/1, assigns)

      assert html =~ "grid-cols-1"
      assert html =~ "md:grid-cols-2"
      assert html =~ "lg:grid-cols-3"
      assert html =~ "xl:grid-cols-4"
    end

    test "container_class overrides grid_columns" do
      assigns = %{
        resource: TestProduct,
        actor: nil,
        layout: :grid,
        grid_columns: 4,
        container_class: "custom-grid-class",
        col: [%{field: "name", __slot__: :col}],
        item: item_slot()
      }

      html = render_component(&Cinder.collection/1, assigns)

      assert html =~ "custom-grid-class"
      refute html =~ "grid-cols-4"
    end

    test "grid_columns is ignored for non-grid layouts" do
      assigns = %{
        resource: TestProduct,
        actor: nil,
        layout: :list,
        grid_columns: 4,
        col: [%{field: "name", __slot__: :col}],
        item: item_slot()
      }

      html = render_component(&Cinder.collection/1, assigns)

      assert html =~ "cinder-list"
      refute html =~ "grid-cols-4"
    end
  end

  describe "layout string support" do
    test "layout=\"table\" works" do
      assigns = %{
        resource: TestProduct,
        actor: nil,
        layout: "table",
        col: [%{field: "name", __slot__: :col}]
      }

      html = render_component(&Cinder.collection/1, assigns)

      assert html =~ "cinder-table"
    end

    test "layout=\"list\" works" do
      assigns = %{
        resource: TestProduct,
        actor: nil,
        layout: "list",
        col: [%{field: "name", __slot__: :col}],
        item: item_slot()
      }

      html = render_component(&Cinder.collection/1, assigns)

      assert html =~ "cinder-list"
    end

    test "invalid layout falls back to table" do
      assigns = %{
        resource: TestProduct,
        actor: nil,
        layout: "invalid",
        col: [%{field: "name", __slot__: :col}]
      }

      html = render_component(&Cinder.collection/1, assigns)

      assert html =~ "cinder-table"
    end
  end
end
