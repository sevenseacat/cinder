defmodule Cinder.Next.ComponentTest do
  @moduledoc "Clicking through a mounted `Cinder.Next.collection`."
  use Cinder.ConnCase, async: false

  import Phoenix.ConnTest, only: [get: 2]
  import Phoenix.LiveViewTest, only: [live: 2, render_async: 1, render_click: 1, element: 2]

  setup do
    artist = generate(artist(name: "Next Artist"))

    for title <- ["Alpha", "Bravo", "Charlie", "Delta", "Echo"] do
      generate(album(title: title, artist_id: artist.id))
    end

    on_exit(fn ->
      Ash.bulk_destroy!(Music.Album, :destroy, %{})
      Ash.bulk_destroy!(Music.Artist, :destroy, %{})
    end)

    path =
      Cinder.TestLive.Fixture.register(fn assigns ->
        ~H"""
        <Cinder.Next.collection id="albums" resource={Music.Album} page_size={2}>
          <:col :let={album} field="title" sort>{album.title}</:col>
        </Cinder.Next.collection>
        """
      end)

    %{path: path}
  end

  defp titles(html), do: Regex.scan(~r/Alpha|Bravo|Charlie|Delta|Echo/, html) |> List.flatten()

  defp click(view, selector) do
    view |> element(selector) |> render_click()
    render_async(view)
  end

  test "sorting cycles through ascending and descending", %{conn: conn, path: path} do
    {:ok, view, _html} = live(conn, path)
    render_async(view)

    assert titles(click(view, ~s([data-part="sort"][phx-value-field="title"]))) == [
             "Alpha",
             "Bravo"
           ]

    assert titles(click(view, ~s([data-part="sort"][phx-value-field="title"]))) == [
             "Echo",
             "Delta"
           ]
  end

  test "paging moves through the sorted records", %{conn: conn, path: path} do
    {:ok, view, _html} = live(conn, path)
    render_async(view)
    click(view, ~s([data-part="sort"][phx-value-field="title"]))

    assert titles(click(view, ~s([data-part="page"][data-kind="page"][phx-value-page="2"]))) ==
             ["Charlie", "Delta"]

    assert titles(click(view, ~s([data-part="page"][data-kind="next"]))) == ["Echo"]

    html = click(view, ~s([data-part="page"][data-kind="prev"]))
    assert titles(html) == ["Charlie", "Delta"]
    assert html =~ "showing 3-4 of 5"
  end

  test "sorting goes back to the first page", %{conn: conn, path: path} do
    {:ok, view, _html} = live(conn, path)
    render_async(view)
    click(view, ~s([data-part="sort"][phx-value-field="title"]))
    click(view, ~s([data-part="page"][data-kind="next"]))

    html = click(view, ~s([data-part="sort"][phx-value-field="title"]))

    assert titles(html) == ["Echo", "Delta"]
    assert html =~ "showing 1-2 of 5"
  end
end
