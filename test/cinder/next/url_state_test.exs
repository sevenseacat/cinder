defmodule Cinder.Next.UrlStateTest do
  @moduledoc "A URL-synced `Cinder.Next.collection`, through `use Cinder.UrlSync` unchanged."
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
    artist = generate(artist(name: "Url Artist"))

    for {title, genre} <- [
          {"Alpha", :rock},
          {"Bravo", :jazz},
          {"Charlie", :rock},
          {"Delta", :jazz},
          {"Echo", :pop}
        ] do
      generate(album(title: title, genre: genre, artist_id: artist.id))
    end

    test_pid = self()
    handler_id = "next-url-state-#{System.unique_integer([:positive])}"

    :telemetry.attach(
      handler_id,
      [:ash, :music, :read, :start],
      fn _event, _measurements, %{resource: Music.Album}, _config ->
        send(test_pid, :album_read)
      end,
      nil
    )

    on_exit(fn ->
      :telemetry.detach(handler_id)
      Ash.bulk_destroy!(Music.Album, :destroy, %{})
      Ash.bulk_destroy!(Music.Artist, :destroy, %{})
    end)

    path =
      Cinder.TestLive.Fixture.register(fn assigns ->
        ~H"""
        <Cinder.Next.collection
          id="albums"
          resource={Music.Album}
          url_state={@url_state}
          page_size={2}
        >
          <:col :let={album} field="title" filter sort>{album.title}</:col>
          <:col field="genre" filter />
        </Cinder.Next.collection>
        """
      end)

    %{path: path}
  end

  defp titles(html), do: Regex.scan(~r/Alpha|Bravo|Charlie|Delta|Echo/, html) |> List.flatten()

  defp flush_reads do
    receive do
      :album_read -> flush_reads()
    after
      50 -> :ok
    end
  end

  defp count_reads(count \\ 0) do
    receive do
      :album_read -> count_reads(count + 1)
    after
      100 -> count
    end
  end

  test "starts from the state in the URL", %{conn: conn, path: path} do
    {:ok, view, _html} = live(conn, path <> "?genre=rock&sort=-title")
    html = render_async(view)

    assert titles(html) == ["Charlie", "Alpha"]
    assert html =~ ~r/<option(?=[^>]*value="rock")[^>]*selected/
    assert html =~ ~s(aria-sort="descending")
  end

  test "changes go out through the URL, and load once when it comes back", %{
    conn: conn,
    path: path
  } do
    {:ok, view, _html} = live(conn, path)
    render_async(view)
    flush_reads()

    view
    |> element("#albums-filters")
    |> render_change(%{"filters" => %{"title" => "", "genre" => "jazz"}})

    assert assert_patch(view) =~ "genre=jazz"
    assert Enum.sort(titles(render_async(view))) == ["Bravo", "Delta"]
    assert count_reads() == 1
  end

  test "sort and page are written to the URL", %{conn: conn, path: path} do
    {:ok, view, _html} = live(conn, path)
    render_async(view)

    view |> element(~s([data-part="sort"][phx-value-field="title"])) |> render_click()
    assert assert_patch(view) =~ "sort=title"

    view |> element(~s([data-part="page"][data-kind="next"])) |> render_click()
    patched = assert_patch(view)
    assert patched =~ "page=2"
    assert titles(render_async(view)) == ["Charlie", "Delta"]
  end

  test "going back to an earlier URL restores its state", %{conn: conn, path: path} do
    {:ok, view, _html} = live(conn, path <> "?genre=jazz")
    render_async(view)

    # What the browser's back button does: handle_params with the older URL
    html = render_patch(view, path)

    assert length(titles(render_async(view))) == 2
    assert render_async(view) =~ "showing 1-2 of 5"
    refute html =~ ~r/<option(?=[^>]*value="jazz")[^>]*selected/
  end
end
