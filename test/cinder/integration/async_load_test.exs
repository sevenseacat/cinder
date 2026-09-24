defmodule Cinder.Integration.AsyncLoadTest do
  @moduledoc """
  Covers `initial_load` — whether a collection's first query runs before or after
  the page renders.

  Every other integration test loads data synchronously (see `Cinder.ConnCase`)
  for simplicity. This test opts back into Cinder's default async mode, so the
  disconnected HTTP response only contains data when `initial_load` is `:sync`.
  """
  use Cinder.ConnCase, async: false
  import Phoenix.ConnTest, only: [get: 2, html_response: 2]
  import Phoenix.LiveViewTest, only: [live: 2, element: 2, render_click: 1, render_async: 1]

  # Opt back into async loading for this test (ConnCase's setup disabled it).
  setup {Cinder.TestHelpers, :enable_async_loading}

  defp put_default_initial_load(mode) do
    original = Application.fetch_env(:cinder, :default_initial_load)
    Application.put_env(:cinder, :default_initial_load, mode)

    on_exit(fn ->
      case original do
        {:ok, value} -> Application.put_env(:cinder, :default_initial_load, value)
        :error -> Application.delete_env(:cinder, :default_initial_load)
      end
    end)
  end

  defp sync_album_collection(assigns) do
    ~H"""
    <Cinder.collection
      resource={Cinder.Integration.Album}
      url_state={@url_state}
      initial_load={:sync}
    >
      <:col :let={album} field="title" filter sort>{album.title}</:col>
    </Cinder.collection>
    """
  end

  # Deliberately uses the string form of the mode, so it stays covered.
  defp sync_no_url_album_collection(assigns) do
    ~H"""
    <Cinder.collection resource={Cinder.Integration.Album} initial_load="sync">
      <:col :let={album} field="title" filter sort>{album.title}</:col>
    </Cinder.collection>
    """
  end

  defp default_album_collection(assigns) do
    ~H"""
    <Cinder.collection resource={Cinder.Integration.Album} url_state={@url_state}>
      <:col :let={album} field="title" filter sort>{album.title}</:col>
    </Cinder.collection>
    """
  end

  defp async_album_collection(assigns) do
    ~H"""
    <Cinder.collection
      resource={Cinder.Integration.Album}
      url_state={@url_state}
      initial_load={:async}
    >
      <:col :let={album} field="title" filter sort>{album.title}</:col>
    </Cinder.collection>
    """
  end

  setup do
    artist = generate(artist(name: "Async Artist"))
    generate(album(title: "Async Album", genre: :rock, artist_id: artist.id))
    generate(album(title: "Buffered Album", genre: :rock, artist_id: artist.id))

    on_exit(fn ->
      Ash.bulk_destroy!(Cinder.Integration.Album, :destroy, %{})
      Ash.bulk_destroy!(Cinder.Integration.Artist, :destroy, %{})
    end)

    %{
      sync_path: Cinder.TestLive.Fixture.register(&sync_album_collection/1),
      sync_no_url_path: Cinder.TestLive.Fixture.register(&sync_no_url_album_collection/1),
      default_path: Cinder.TestLive.Fixture.register(&default_album_collection/1),
      async_path: Cinder.TestLive.Fixture.register(&async_album_collection/1)
    }
  end

  test "initial_load={:sync} puts data in the initial HTTP response", %{
    conn: conn,
    sync_path: path
  } do
    html =
      conn
      |> get(path)
      |> html_response(200)

    assert html =~ "Async Album"
  end

  test "the initial load is async by default", %{conn: conn, default_path: path} do
    html =
      conn
      |> get(path)
      |> html_response(200)

    refute html =~ "Async Album"
  end

  test "the default async load still delivers collection data", %{conn: conn, default_path: path} do
    conn
    |> visit(path)
    |> assert_has("td", text: "Async Album", timeout: 1000)
  end

  test "a synchronous initial load applies filters and sort from the URL", %{
    conn: conn,
    sync_path: path
  } do
    html =
      conn
      |> get(path <> "?title=Buffered")
      |> html_response(200)

    assert html =~ "Buffered Album"
    refute html =~ "Async Album"

    descending =
      conn
      |> get(path <> "?sort=-title")
      |> html_response(200)

    assert buffered_first?(descending)
  end

  test "only the first load of a synchronous collection blocks", %{
    conn: conn,
    sync_no_url_path: path
  } do
    # No url_state here: with URL sync on, sorting only flags a reload and waits for
    # the patch, so the click's own render never carries new data either way.
    {:ok, view, html} = live(conn, path)

    # The first load was synchronous, so the rows are already here.
    assert html =~ "Async Album"

    sort = fn -> view |> element(~s|div[phx-value-key="title"]|) |> render_click() end

    # Sort ascending, which matches the insertion order the rows already have.
    sort.()
    render_async(view)

    # Sorting again is a later load and must not block, so the render replying to
    # the click still shows ascending — descending arrives with the async reply.
    refute buffered_first?(sort.())
    assert buffered_first?(render_async(view))
  end

  defp buffered_first?(html) do
    {buffered, _} = :binary.match(html, "Buffered Album")
    {async, _} = :binary.match(html, "Async Album")
    buffered < async
  end

  test "the initial load mode can be set globally", %{conn: conn, default_path: path} do
    put_default_initial_load(:sync)

    html =
      conn
      |> get(path)
      |> html_response(200)

    assert html =~ "Async Album"
  end

  test "an unrecognised mode warns and falls back to async", %{conn: conn} do
    path =
      Cinder.TestLive.Fixture.register(fn assigns ->
        ~H"""
        <Cinder.collection resource={Cinder.Integration.Album} initial_load={:synk}>
          <:col :let={album} field="title">{album.title}</:col>
        </Cinder.collection>
        """
      end)

    log =
      ExUnit.CaptureLog.capture_log(fn ->
        refute conn |> get(path) |> html_response(200) =~ "Async Album"
      end)

    assert log =~ "Unknown initial_load :synk, falling back to :async"
  end

  test "a collection value overrides the global default", %{conn: conn, async_path: path} do
    put_default_initial_load(:sync)

    html =
      conn
      |> get(path)
      |> html_response(200)

    refute html =~ "Async Album"
  end
end
