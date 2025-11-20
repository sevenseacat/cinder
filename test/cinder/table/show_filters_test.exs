defmodule Cinder.Table.ShowFiltersTest do
  @moduledoc """
  Regression tests for show_filters auto-detection.

  This tests the fix for the bug where the filters section would not be shown
  automatically when search was enabled but no filterable columns existed.
  """
  use ExUnit.Case, async: true
  import Phoenix.LiveViewTest

  defmodule TestResource do
    @moduledoc false
    use Ash.Resource,
      domain: Cinder.Table.ShowFiltersTest.Domain,
      data_layer: Ash.DataLayer.Ets,
      validate_domain_inclusion?: false

    ets do
      private?(true)
    end

    attributes do
      uuid_primary_key(:id)
      attribute(:name, :string, public?: true)
      attribute(:email, :string, public?: true)
      attribute(:description, :string, public?: true)
    end

    actions do
      defaults([:read])
    end
  end

  defmodule Domain do
    @moduledoc false
    use Ash.Domain, validate_config_inclusion?: false

    resources do
      resource(TestResource)
    end
  end

  defmodule TableWrappers do
    use Phoenix.Component

    def filterable(assigns) do
      ~H"""
      <Cinder.Table.table resource={TestResource} actor={nil}>
        <:col field="name" filter={[type: :text]}>Name</:col>
      </Cinder.Table.table>
      """
    end

    def searchable(assigns) do
      ~H"""
      <Cinder.Table.table resource={TestResource} actor={nil}>
        <:col field="name" search>Name</:col>
        <:col field="email" search>Email</:col>
      </Cinder.Table.table>
      """
    end

    def both(assigns) do
      ~H"""
      <Cinder.Table.table resource={TestResource} actor={nil}>
        <:col field="name" filter={[type: :text]} search>Name</:col>
        <:col field="email" search>Email</:col>
      </Cinder.Table.table>
      """
    end

    def neither(assigns) do
      ~H"""
      <Cinder.Table.table resource={TestResource} actor={nil}>
        <:col field="name">Name</:col>
      </Cinder.Table.table>
      """
    end

    def explicitly_disabled(assigns) do
      ~H"""
      <Cinder.Table.table resource={TestResource} actor={nil} show_filters={false}>
        <:col field="name" filter={[type: :text]}>Name</:col>
      </Cinder.Table.table>
      """
    end

    def search_disabled(assigns) do
      ~H"""
      <Cinder.Table.table resource={TestResource} actor={nil} search={false}>
        <:col field="name" search>Name</:col>
      </Cinder.Table.table>
      """
    end
  end

  describe "show_filters auto-detection" do
    test "shows filters when columns are filterable" do
      html = render_component(&TableWrappers.filterable/1, %{})

      # Should have the filters section
      assert html =~ "filter_container_class"
    end

    test "shows filters when search is enabled (regression test for #70)" do
      html = render_component(&TableWrappers.searchable/1, %{})

      # Should have the filters section because search is enabled
      assert html =~ "filter_container_class"
      # Should have search input
      assert html =~ "Search"
    end

    test "shows filters when both filterable and searchable" do
      html = render_component(&TableWrappers.both/1, %{})

      # Should have the filters section
      assert html =~ "filter_container_class"
    end

    test "hides filters when neither filterable nor searchable" do
      html = render_component(&TableWrappers.neither/1, %{})

      # Should NOT have the filters section
      refute html =~ "filter_container_class"
    end

    test "explicit show_filters=false hides filters even with filterable columns" do
      html = render_component(&TableWrappers.explicitly_disabled/1, %{})

      # Should NOT have the filters section (explicitly disabled)
      refute html =~ "filter_container_class"
    end

    test "hides filters when search is explicitly disabled" do
      html = render_component(&TableWrappers.search_disabled/1, %{})

      # Should NOT have the filters section (search disabled, no filterable columns)
      refute html =~ "filter_container_class"
    end
  end
end
