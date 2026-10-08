defmodule Cinder.Integration.RemoveItemsTest do
  @moduledoc """
  Covers `Cinder.remove_item/3` and `Cinder.remove_items/3` against a mounted
  collection: the rows leave, the selection is pruned, and the pagination footer
  keeps up with the new total.
  """
  use Cinder.ConnCase, async: false

  import Phoenix.ConnTest, only: [get: 2]
  import Phoenix.LiveViewTest, only: [live: 2, element: 2, render: 1, render_click: 1]

  defp offset_collection(assigns) do
    ~H"""
    <Cinder.collection
      id="albums"
      resource={Cinder.Integration.Album}
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
      resource={Cinder.Integration.Album}
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
      Ash.bulk_destroy!(Cinder.Integration.Album, :destroy, %{})
      Ash.bulk_destroy!(Cinder.Integration.Artist, :destroy, %{})
    end)

    %{
      albums: albums,
      offset_path: Cinder.TestLive.Fixture.register(&offset_collection/1) <> "?sort=title",
      keyset_path: Cinder.TestLive.Fixture.register(&keyset_collection/1) <> "?sort=title"
    }
  end

  defp remove(view, ids) do
    send(view.pid, {:remove_items, "albums", ids})
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

    test "keeps the total consistent when a whole page is removed", %{
      conn: conn,
      offset_path: path,
      albums: albums
    } do
      {:ok, view, _html} = live(conn, path)

      html = remove(view, [albums["Alpha"].id, albums["Bravo"].id])

      refute html =~ "Alpha"
      refute html =~ "Bravo"
      refute html =~ "of 5"
      assert html =~ "of 3"
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
