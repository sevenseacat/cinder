defmodule Cinder.Next.SelectionTest do
  @moduledoc "Selecting rows and running bulk actions on a mounted `Cinder.Next.collection`."
  use Cinder.ConnCase, async: false

  import Phoenix.ConnTest, only: [get: 2]

  import Phoenix.LiveViewTest,
    only: [
      live: 2,
      render: 1,
      render_async: 1,
      render_change: 2,
      render_click: 1,
      render_click: 3,
      element: 2,
      has_element?: 2,
      with_target: 2
    ]

  setup %{conn: conn} do
    artist = generate(artist(name: "Selection Artist"))

    albums =
      for {title, genre} <- [
            {"Alpha", :rock},
            {"Bravo", :jazz},
            {"Charlie", :rock},
            {"Delta", :jazz},
            {"Echo", :pop}
          ],
          into: %{} do
        {title, generate(album(title: title, genre: genre, artist_id: artist.id))}
      end

    on_exit(fn ->
      Ash.bulk_destroy!(Music.Album, :destroy, %{})
      Ash.bulk_destroy!(Music.Artist, :destroy, %{})
    end)

    path =
      Cinder.TestLive.Fixture.register(fn assigns ->
        ~H"""
        <Cinder.Next.collection
          id="albums"
          query={Ash.Query.sort(Music.Album, :title)}
          page_size={2}
          selectable={&(&1.title != "Bravo")}
        >
          <:col :let={album} field="title">{album.title}</:col>
          <:col field="genre" filter />
          <:bulk_action name="remaster" action={:remaster} />
          <:bulk_action name="delete" action={:destroy} confirm="Delete {count} albums?" />
        </Cinder.Next.collection>
        """
      end)

    {:ok, view, _html} = live(conn, path)
    render_async(view)

    %{view: view, albums: albums}
  end

  defp pick(view, albums, title) do
    view
    |> element(~s(.cinder-select[phx-value-id="#{albums[title].id}"]))
    |> render_click()
  end

  defp event(view, name, params \\ %{}),
    do: view |> with_target("#albums") |> render_click(name, params)

  defp remastered do
    Music.Album |> Ash.read!() |> Enum.filter(& &1.is_remastered) |> Enum.map(& &1.title)
  end

  test "rows and the page checkbox select, and the count follows", %{view: view, albums: albums} do
    # Bravo isn't selectable, so Alpha alone completes the first page
    pick(view, albums, "Alpha")
    assert has_element?(view, ~s(.cinder-select-page[data-state="all"]))

    assert has_element?(
             view,
             ~s(.cinder-select[phx-value-id="#{albums["Bravo"].id}"][disabled])
           )

    view |> element(~s(.cinder-page[data-kind="next"])) |> render_click()
    render_async(view)
    pick(view, albums, "Charlie")
    assert has_element?(view, ~s(.cinder-select-page[data-state="some"]))

    html = view |> element(~s(.cinder-select-page)) |> render_click()
    assert html =~ ~s(data-state="all")
    assert render(view) =~ "3 selected"

    view |> element(~s(.cinder-clear-selection)) |> render_click()
    assert has_element?(view, ~s(.cinder-select-page[data-state="none"]))
  end

  test "the selection survives paging and filtering", %{view: view, albums: albums} do
    pick(view, albums, "Alpha")
    view |> element(~s(.cinder-page[data-kind="next"])) |> render_click()
    render_async(view)
    pick(view, albums, "Charlie")

    view |> element("#albums-filters") |> render_change(%{"filters" => %{"genre" => "pop"}})
    assert render_async(view) =~ "2 selected"
  end

  test "only records served on the page can be selected", %{view: view, albums: albums} do
    # Echo is on page 3, and Bravo isn't selectable: a client can't add either
    event(view, "toggle_select", %{"id" => to_string(albums["Echo"].id)})
    event(view, "toggle_select", %{"id" => to_string(albums["Bravo"].id)})

    refute has_element?(view, ~s(.cinder-bulk-bar))
  end

  test "an action without a confirm runs on the selection, then clears it", %{
    view: view,
    albums: albums
  } do
    pick(view, albums, "Alpha")
    view |> element(~s(.cinder-page[data-kind="next"])) |> render_click()
    render_async(view)
    pick(view, albums, "Charlie")

    view |> element(~s([data-action="remaster"])) |> render_click()
    render_async(view)

    assert Enum.sort(remastered()) == ["Alpha", "Charlie"]
    refute has_element?(view, ~s(.cinder-bulk-bar))
  end

  test "an action with a confirm only asks, and runs once confirmed", %{
    view: view,
    albums: albums
  } do
    pick(view, albums, "Alpha")

    html = view |> element(~s([data-action="delete"])) |> render_click()
    assert html =~ ~r/class="cinder-confirmation".*Delete 1 albums\?/s
    assert length(Ash.read!(Music.Album)) == 5

    view |> element(~s(.cinder-cancel)) |> render_click()
    refute has_element?(view, ~s(.cinder-confirmation))
    assert length(Ash.read!(Music.Album)) == 5

    view |> element(~s([data-action="delete"])) |> render_click()
    view |> element(~s(.cinder-confirm)) |> render_click()
    render_async(view)

    assert Music.Album |> Ash.read!() |> Enum.map(& &1.title) |> Enum.sort() ==
             ["Bravo", "Charlie", "Delta", "Echo"]
  end

  test "a forged confirm, or an unknown action, does nothing", %{view: view, albums: albums} do
    pick(view, albums, "Alpha")

    # Nothing is pending, so there's nothing to confirm
    event(view, "confirm_action")
    event(view, "bulk_action", %{"name" => "drop_everything"})

    assert length(Ash.read!(Music.Album)) == 5
    assert remastered() == []
  end
end
