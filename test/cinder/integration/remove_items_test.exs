defmodule Cinder.Integration.RemoveItemsTest do
  @moduledoc """
  Covers `Cinder.remove_item/3` and `Cinder.remove_items/3` against a mounted
  collection: the rows leave, the selection is pruned, and the pagination footer
  keeps up with the new total.
  """
  use Cinder.ConnCase, async: false

  import Phoenix.ConnTest, only: [get: 2]

  import Phoenix.LiveViewTest,
    only: [live: 2, element: 2, render: 1, render_click: 1, assert_patch: 1]

  defp offset_collection(assigns) do
    ~H"""
    <Cinder.collection
      id="albums"
      resource={Music.Album}
      url_state={@url_state}
      page_size={2}
      selectable
    >
      <:col :let={album} field="title" sort>{album.title}</:col>
    </Cinder.collection>
    """
  end

  defp keyset_collection(assigns) do
    ~H"""
    <Cinder.collection
      id="albums"
      resource={Music.Album}
      url_state={@url_state}
      page_size={2}
      pagination={:keyset}
      selectable
    >
      <:col :let={album} field="title" sort>{album.title}</:col>
    </Cinder.collection>
    """
  end

  setup do
    artist = generate(artist(name: "Remove Artist"))

    albums =
      for title <- ["Alpha", "Bravo", "Charlie", "Delta", "Echo"], into: %{} do
        {title, generate(album(title: title, artist_id: artist.id))}
      end

    on_exit(fn ->
      Ash.bulk_destroy!(Music.Album, :destroy, %{})
      Ash.bulk_destroy!(Music.Artist, :destroy, %{})
    end)

    %{
      albums: albums,
      offset_path: Cinder.TestLive.Fixture.register(&offset_collection/1) <> "?sort=title",
      keyset_path: Cinder.TestLive.Fixture.register(&keyset_collection/1) <> "?sort=title"
    }
  end

  defp remove(view, ids) do
    Cinder.TestLive.Fixture.run(view, &Cinder.remove_items(&1, "albums", ids))
    render(view)
  end

  defp select(view, album) do
    view
    |> element(~s(input[phx-click=toggle_select][phx-value-id="#{album.id}"]))
    |> render_click()
  end

  describe "offset pagination" do
    test "removes the rows and brings the footer count down with them", %{
      conn: conn,
      offset_path: path,
      albums: albums
    } do
      {:ok, view, html} = live(conn, path)
      assert html =~ "Alpha"
      assert html =~ "showing 1-2 of 5"

      html = remove(view, [albums["Alpha"].id])

      refute html =~ "Alpha"
      assert html =~ "Bravo"
      assert html =~ "Page 1 of 2"
      assert html =~ "showing 1-1 of 4"
    end

    test "only counts the rows that were actually removed", %{
      conn: conn,
      offset_path: path,
      albums: albums
    } do
      {:ok, view, _html} = live(conn, path)

      # Delta is on another page, and the second ID matches nothing at all
      html = remove(view, [albums["Bravo"].id, albums["Delta"].id, Ash.UUID.generate()])

      refute html =~ "Bravo"
      assert html =~ "Alpha"
      assert html =~ "showing 1-1 of 4"
    end

    test "drops removed rows from the selection and keeps the others", %{
      conn: conn,
      offset_path: path,
      albums: albums
    } do
      {:ok, view, _html} = live(conn, path)
      select(view, albums["Alpha"])
      html = select(view, albums["Bravo"])

      assert Enum.sort(checked_ids(html)) ==
               Enum.sort([albums["Alpha"].id, albums["Bravo"].id])

      html = remove(view, [albums["Alpha"].id])

      refute html =~ "Alpha"
      assert checked_ids(html) == [albums["Bravo"].id]
    end

    test "reloads a page that the removal empties, so the next rows move up", %{
      conn: conn,
      offset_path: path,
      albums: albums
    } do
      {:ok, view, _html} = live(conn, path)

      Enum.each([albums["Alpha"], albums["Bravo"]], &Ash.destroy!/1)
      html = remove(view, [albums["Alpha"].id, albums["Bravo"].id])

      refute html =~ "Alpha"
      refute html =~ "Bravo"
      assert html =~ "Charlie"
      assert html =~ "Delta"
      assert html =~ "showing 1-2 of 3"
    end

    test "steps back a page when the removal empties the last page", %{
      conn: conn,
      offset_path: path,
      albums: albums
    } do
      {:ok, view, html} = live(conn, path <> "&page=3")
      assert html =~ "Echo"

      Ash.destroy!(albums["Echo"])
      html = remove(view, [albums["Echo"].id])

      refute html =~ "Echo"
      assert html =~ "Charlie"
      assert html =~ "Delta"
      assert html =~ "Page 2 of 2"

      assert %{"page" => "2"} =
               view |> assert_patch() |> URI.parse() |> Map.get(:query) |> URI.decode_query()
    end
  end

  describe "keyset pagination" do
    test "removes the rows and brings the footer count down with them", %{
      conn: conn,
      keyset_path: path,
      albums: albums
    } do
      {:ok, view, html} = live(conn, path)
      assert html =~ "5 items"

      html = remove(view, [albums["Alpha"].id])

      refute html =~ "Alpha"
      assert html =~ "Bravo"
      assert html =~ "4 items"
    end
  end

  # The ids of the checked selection checkboxes in the rendered table
  defp checked_ids(html) do
    ~r/<input[^>]*>/
    |> Regex.scan(html)
    |> List.flatten()
    |> Enum.filter(&(&1 =~ "phx-value-id" and &1 =~ ~r/\schecked/))
    |> Enum.map(&(Regex.run(~r/phx-value-id="([^"]+)"/, &1) |> Enum.at(1)))
  end
end
