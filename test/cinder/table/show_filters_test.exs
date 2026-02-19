defmodule Cinder.Table.ShowFiltersTest do
  @moduledoc """
  Tests for show_filters auto-detection and toggle modes.
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

  # HEEx templates can't be inlined in tests, so we need wrapper components.
  # Kept to the minimum set needed — reuse these across test cases.
  defmodule TableWrappers do
    use Phoenix.Component

    # Auto-detection wrappers (using deprecated Table API to test backwards compat)
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

    # Parameterized wrapper for toggle mode tests
    def collection(assigns) do
      ~H"""
      <Cinder.collection resource={TestResource} actor={nil} show_filters={@show_filters}>
        <:col field="name" filter={@filter}>Name</:col>
      </Cinder.collection>
      """
    end
  end

  defp render_collection(show_filters, filter \\ [type: :text]) do
    render_component(&TableWrappers.collection/1, %{show_filters: show_filters, filter: filter})
  end

  describe "show_filters auto-detection" do
    test "shows filters when columns are filterable" do
      html = render_component(&TableWrappers.filterable/1, %{})
      assert html =~ "filter_container_class"
    end

    test "shows filters when search is enabled (regression test for #70)" do
      html = render_component(&TableWrappers.searchable/1, %{})
      assert html =~ "filter_container_class"
      assert html =~ "Search"
    end

    test "hides filters when neither filterable nor searchable" do
      html = render_component(&TableWrappers.neither/1, %{})
      refute html =~ "filter_container_class"
    end

    test "explicit show_filters=false hides filters even with filterable columns" do
      html = render_component(&TableWrappers.explicitly_disabled/1, %{})
      refute html =~ "filter_container_class"
    end

    test "hides filters when search is explicitly disabled" do
      html = render_component(&TableWrappers.search_disabled/1, %{})
      refute html =~ "filter_container_class"
    end
  end

  describe "show_filters toggle mode" do
    test ":toggle starts with filter body hidden" do
      html = render_collection(:toggle)

      assert html =~ "filter_container_class"
      assert html =~ "filter-toggle-expanded"
      assert html =~ "filter-toggle-collapsed"
      assert html =~ ~r/id="[^"]*-filter-toggle-expanded"[^>]*class="[^"]*hidden/
      assert html =~ ~r/id="[^"]*-filter-body"[^>]*class="hidden"/
    end

    test ":toggle_open starts with filter body visible" do
      html = render_collection(:toggle_open)

      assert html =~ "filter_container_class"
      assert html =~ "filter-toggle-expanded"
      assert html =~ "filter-toggle-collapsed"
      assert html =~ ~r/id="[^"]*-filter-toggle-collapsed"[^>]*class="[^"]*hidden/
      refute html =~ ~r/id="[^"]*-filter-body"[^>]*class="hidden"/
    end

    test ":toggle with no filterable columns does not render filters" do
      html = render_collection(:toggle, false)
      refute html =~ "filter_container_class"
    end

    test "true does not render toggle UI" do
      html = render_collection(true)
      assert html =~ "filter_container_class"
      refute html =~ "filter-toggle-expanded"
    end

    for {string, atom} <- [{"toggle", :toggle}, {"toggle_open", :toggle_open}] do
      test "string \"#{string}\" works the same as :#{atom}" do
        string_html = render_collection(unquote(string))
        atom_html = render_collection(unquote(atom))

        assert string_html =~ "filter-toggle-expanded"

        assert string_html =~ ~r/id="[^"]*-filter-body"[^>]*class="hidden"/ ==
                 (atom_html =~ ~r/id="[^"]*-filter-body"[^>]*class="hidden"/)
      end
    end

    test "filter inputs are still present when collapsed" do
      html = render_collection(:toggle)
      assert html =~ "filter_change"
      assert html =~ ~s(name="filters[name])
    end
  end
end
