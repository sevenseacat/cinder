defmodule Cinder.Integration.OnStateChangeTest do
  @moduledoc """
  A collection with `on_state_change` but no URL sync still filters and sorts its own data, and
  sends the message.
  """
  use Cinder.ConnCase, async: false
  import Phoenix.ConnTest, only: [get: 2]

  import Phoenix.LiveViewTest,
    only: [live: 2, element: 2, render: 1, render_change: 2, render_click: 1]

  defp collection(assigns) do
    ~H"""
    <Cinder.collection id="albums" resource={Music.Album} on_state_change={:albums_changed}>
      <:col :let={album} field="title" filter sort>[{album.title}]</:col>
    </Cinder.collection>
    """
  end

  setup do
    artist = generate(artist(name: "Artist"))
    generate(album(title: "Dirt", artist_id: artist.id))
    generate(album(title: "Ten", artist_id: artist.id))

    on_exit(fn ->
      Ash.bulk_destroy!(Music.Album, :destroy, %{})
      Ash.bulk_destroy!(Music.Artist, :destroy, %{})
    end)

    {:ok, path: Cinder.TestLive.Fixture.register(&collection/1, forward_to: self())}
  end

  test "filtering applies, and the parent is told", %{conn: conn, path: path} do
    {:ok, view, _html} = live(conn, path)

    view
    |> element("form[phx-change=filter_change]")
    |> render_change(%{"filters" => %{"title" => "Dirt"}})

    html = render(view)
    assert html =~ "[Dirt]"
    refute html =~ "[Ten]"
    assert_receive {:albums_changed, "albums", _state}
  end

  test "sorting applies", %{conn: conn, path: path} do
    {:ok, view, _html} = live(conn, path)

    view |> element("th [phx-click=toggle_sort]") |> render_click()
    view |> element("th [phx-click=toggle_sort]") |> render_click()

    html = render(view)
    assert :binary.match(html, "[Ten]") < :binary.match(html, "[Dirt]")
  end
end
