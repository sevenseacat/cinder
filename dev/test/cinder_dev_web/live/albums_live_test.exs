defmodule CinderDevWeb.AlbumsLiveTest do
  use CinderDevWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  test "renders the seeded albums", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/")

    # Data loads asynchronously after mount, so render again once it's in
    assert render_async(view) =~ ~r/Album \d+/
  end
end
