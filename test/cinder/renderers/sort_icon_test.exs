defmodule Cinder.Renderers.SortIconTest do
  use ExUnit.Case, async: true
  import Phoenix.LiveViewTest

  alias Cinder.Renderers.SortIcon

  defp render_icon(direction, opts \\ []) do
    assigns = %{
      sort_direction: direction,
      theme: Keyword.get(opts, :theme, %{}),
      loading: Keyword.get(opts, :loading, false)
    }

    render_component(&SortIcon.sort_icon/1, assigns)
  end

  describe "direction icons" do
    test "ascending renders the asc chevron" do
      assert render_icon(:asc) =~ "hero-chevron-up"
    end

    test "descending renders the desc chevron" do
      assert render_icon(:desc) =~ "hero-chevron-down"
    end

    test "unsorted renders the none chevron" do
      assert render_icon(nil) =~ "hero-chevron-up-down"
    end

    # Regression: nils-ordering variants previously rendered no icon in list/grid.
    test "asc nils variants render the asc chevron" do
      assert render_icon(:asc_nils_first) =~ "hero-chevron-up"
      assert render_icon(:asc_nils_last) =~ "hero-chevron-up"
    end

    test "desc nils variants render the desc chevron" do
      assert render_icon(:desc_nils_first) =~ "hero-chevron-down"
      assert render_icon(:desc_nils_last) =~ "hero-chevron-down"
    end
  end

  describe "loading state" do
    test "adds animate-pulse to a directional icon while loading" do
      assert render_icon(:asc, loading: true) =~ "animate-pulse"
    end

    test "no pulse when not loading" do
      refute render_icon(:asc, loading: false) =~ "animate-pulse"
    end
  end

  describe "theme overrides" do
    test "honours custom icon names and classes" do
      theme = %{
        sort_asc_icon_name: "hero-arrow-up",
        sort_asc_icon_class: "size-4 text-pink-500"
      }

      html = render_icon(:asc, theme: theme)
      assert html =~ "hero-arrow-up"
      assert html =~ "text-pink-500"
    end
  end
end
