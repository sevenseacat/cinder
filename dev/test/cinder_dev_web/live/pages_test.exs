defmodule CinderDevWeb.PagesTest do
  use CinderDevWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  # The States page's failing read action logs an error on purpose
  @moduletag :capture_log

  for {path, label} <- CinderDevWeb.Layouts.pages() do
    test "#{label} page renders seeded albums", %{conn: conn} do
      {:ok, view, _html} = live(conn, unquote(path))

      # Data loads asynchronously after mount, so render again once it's in. The
      # States page's slow read action takes 1.5s.
      assert render_async(view, 3_000) =~ ~r/Album \d+/
    end

    test "#{label} page switches theme", %{conn: conn} do
      {:ok, view, _html} = live(conn, unquote(path))

      assert view |> element("a", "modern") |> render_click() =~ "Theme: modern"
    end
  end
end
