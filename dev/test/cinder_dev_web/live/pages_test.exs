defmodule CinderDevWeb.PagesTest do
  use CinderDevWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  for {path, label} <- CinderDevWeb.Layouts.pages() do
    test "#{label} page renders seeded albums", %{conn: conn} do
      {:ok, view, _html} = live(conn, unquote(path))

      # Data loads asynchronously after mount, so render again once it's in
      assert render_async(view) =~ ~r/Album \d+/
    end
  end
end
