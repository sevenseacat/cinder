defmodule Cinder.Next.LiveViewTest do
  @moduledoc "A collection kept in a LiveView's assigns, through `use Cinder.Next.LiveView`."
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
      render_patch: 2,
      element: 2,
      assert_patch: 1,
      refute_patched: 1
    ]

  setup %{conn: conn} do
    artist = generate(artist(name: "LiveView Artist"))

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

    {:ok, view, _html} = live(conn, "/next-live")
    render_async(view)
    %{view: view}
  end

  defp titles(html),
    do: Regex.scan(~r/<h3>(\w+)<\/h3>/, html, capture: :all_but_first) |> List.flatten()

  test "the template renders the collection from its assign", %{view: view} do
    html = render(view)

    assert titles(html) == ["Alpha", "Bravo"]
    # Events are named for the collection, with no component to target
    assert html =~ ~s(phx-click="cinder:albums:go_to_page")
    refute html =~ "phx-target"
  end

  test "its events go through the URL, and browser back returns", %{view: view} do
    view |> element(~s(#top [data-kind="next"])) |> render_click()
    assert assert_patch(view) =~ "page=2"
    assert titles(render_async(view)) == ["Charlie", "Delta"]

    view |> element("#albums-filters") |> render_change(%{"filters" => %{"genre" => "rock"}})
    assert assert_patch(view) =~ "genre=rock"
    assert titles(render_async(view)) == ["Alpha", "Charlie"]

    render_patch(view, "/next-live")
    assert titles(render_async(view)) == ["Alpha", "Bravo"]
  end

  test "without the URL, events load straight away and the URL stays put", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/next-live/plain")
    assert titles(render_async(view)) == ["Alpha", "Bravo"]

    view |> element(~s(#top [data-kind="next"])) |> render_click()
    assert titles(render_async(view)) == ["Charlie", "Delta"]
    refute_patched(view)
  end

  # The suite loads synchronously (`disable_async?`), so this is the one place the
  # hook's `start_async`/`handle_async` path runs
  test "loads asynchronously when reads aren't synchronous", %{conn: conn} do
    Application.put_env(:ash, :disable_async?, false)
    on_exit(fn -> Application.put_env(:ash, :disable_async?, true) end)

    {:ok, view, _html} = live(conn, "/next-live/plain")
    assert titles(render_async(view)) == ["Alpha", "Bravo"]

    view |> element(~s(#top [data-kind="next"])) |> render_click()
    assert titles(render_async(view)) == ["Charlie", "Delta"]
  end

  # The first load, without the required argument, logs Ash's error
  @tag :capture_log
  test "takes a read action's arguments as a keyword list, like `<:argument>`", %{conn: conn} do
    for {album, tracks} <-
          Enum.zip(Enum.sort_by(Ash.read!(Music.Album), & &1.title), [8, 10, 12, 14, 16]) do
      Ash.Seed.update!(album, %{track_count: tracks})
    end

    path =
      Cinder.TestLive.NextFixture.register(
        &Cinder.Next.LiveView.assign_collection(&1, :albums, Music.Album,
          action: :with_min_tracks,
          arguments: [min_tracks: [label: "Min. tracks"]]
        ),
        fn assigns ->
          ~H"""
          <form {@albums.form_attrs}>
            <Cinder.Next.filter :for={f <- @albums.filters} filter={f} />
          </form>
          <Cinder.Next.table collection={@albums}>
            <:col :let={album} field="title"><h3>{album.title}</h3></:col>
          </Cinder.Next.table>
          """
        end
      )

    {:ok, view, _html} = live(conn, path)
    assert render_async(view) =~ "Min. tracks"

    view
    |> element("#albums-filters")
    |> render_change(%{"filters" => %{"min_tracks" => "12"}})

    assert Enum.sort(titles(render_async(view))) == ["Charlie", "Delta", "Echo"]
  end

  test "the LiveView's own events still arrive, and unknown collection events do nothing", %{
    view: view
  } do
    assert view |> element("#ping") |> render_click() =~ "Ping (1)"

    render_click(view, "cinder:albums:drop_tables", %{})
    render_click(view, "cinder:nope:sort", %{"field" => "title"})
    assert titles(render(view)) == ["Alpha", "Bravo"]
  end

  test "selection and a bulk action work the same as in the component", %{view: view} do
    view |> element(~s(li:first-child .cinder-select)) |> render_click()
    view |> element(~s([data-action="remaster"])) |> render_click()
    render_async(view)

    assert [%{title: "Alpha"}] = Music.Album |> Ash.read!() |> Enum.filter(& &1.is_remastered)
  end
end
