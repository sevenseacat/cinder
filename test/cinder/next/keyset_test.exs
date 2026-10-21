defmodule Cinder.Next.KeysetTest do
  @moduledoc "Keyset pagination on a mounted `Cinder.Next.collection`, with and without the URL."
  use Cinder.ConnCase, async: false

  import Phoenix.ConnTest, only: [get: 2]

  import Phoenix.LiveViewTest,
    only: [
      live: 2,
      render_async: 1,
      render_change: 2,
      render_click: 1,
      render_patch: 2,
      element: 2,
      assert_patch: 1
    ]

  setup do
    artist = generate(artist(name: "Keyset Artist"))

    for {title, genre} <- [
          {"Alpha", :rock},
          {"Bravo", :jazz},
          {"Charlie", :rock},
          {"Delta", :jazz},
          {"Echo", :pop}
        ] do
      generate(album(title: title, genre: genre, artist_id: artist.id))
    end

    on_exit(fn ->
      Ash.bulk_destroy!(Music.Album, :destroy, %{})
      Ash.bulk_destroy!(Music.Artist, :destroy, %{})
    end)

    :ok
  end

  defp mount(conn, url_synced?) do
    path =
      Cinder.TestLive.Fixture.register(fn assigns ->
        assigns = assign(assigns, :url_synced?, url_synced?)

        ~H"""
        <Cinder.Next.collection
          id="albums"
          query={Ash.Query.sort(Music.Album, :title)}
          action={:paginated}
          pagination_mode="keyset"
          url_state={@url_synced? && @url_state}
          page_size={2}
        >
          <:col :let={album} field="title">{album.title}</:col>
          <:col field="genre" filter />
        </Cinder.Next.collection>
        """
      end)

    {:ok, view, _html} = live(conn, path)
    render_async(view)
    {view, path}
  end

  defp titles(html), do: Regex.scan(~r/Alpha|Bravo|Charlie|Delta|Echo/, html) |> List.flatten()

  defp page(view, kind) do
    view |> element(~s([data-part="page"][data-kind="#{kind}"])) |> render_click()
    render_async(view)
  end

  defp disabled?(html, kind),
    do: html =~ ~r/<button(?=[^>]*data-kind="#{kind}")(?=[^>]*disabled)[^>]*>/

  test "pages forwards and back by cursor, with no page numbers", %{conn: conn} do
    {view, _path} = mount(conn, false)
    html = render_async(view)

    assert titles(html) == ["Alpha", "Bravo"]
    assert disabled?(html, "prev")
    refute html =~ ~s(data-kind="page")

    assert titles(page(view, "next")) == ["Charlie", "Delta"]

    html = page(view, "next")
    assert titles(html) == ["Echo"]
    assert disabled?(html, "next")

    assert titles(page(view, "prev")) == ["Charlie", "Delta"]

    html = page(view, "prev")
    assert titles(html) == ["Alpha", "Bravo"]
    assert disabled?(html, "prev")
  end

  test "changing the filters starts again from the first page", %{conn: conn} do
    {view, _path} = mount(conn, false)
    page(view, "next")

    view |> element("#albums-filters") |> render_change(%{"filters" => %{"genre" => "rock"}})

    assert titles(render_async(view)) == ["Alpha", "Charlie"]
  end

  test "the cursor goes in the URL, and an older URL goes back to it", %{conn: conn} do
    {view, path} = mount(conn, true)

    view |> element(~s([data-part="page"][data-kind="next"])) |> render_click()
    assert assert_patch(view) =~ "after="
    assert titles(render_async(view)) == ["Charlie", "Delta"]

    # What browser back does
    render_patch(view, path)
    assert titles(render_async(view)) == ["Alpha", "Bravo"]
  end
end
