defmodule Cinder.Integration.AsyncLoadTest do
  @moduledoc """
  Covers initial loading and silent refreshes through a mounted LiveView.

  Every other integration test loads data synchronously (see `Cinder.ConnCase`)
  for simplicity. This test opts back into Cinder's default async mode, so the
  disconnected HTTP response only contains data when `initial_load` is `:sync`.
  """
  use Cinder.ConnCase, async: false
  use Mimic
  import Phoenix.ConnTest, only: [get: 2, html_response: 2]
  import ExUnit.CaptureLog, only: [capture_log: 1]

  import Phoenix.LiveViewTest,
    only: [live: 2, element: 2, render_click: 1, render_async: 1, render: 1, has_element?: 2]

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

  defp mount_refresh_collection(conn) do
    path =
      Cinder.TestLive.Fixture.register(fn assigns ->
        ~H"""
        <Cinder.collection id="albums" resource={Cinder.Integration.Album}>
          <:col :let={album} field="title">{album.title}</:col>
        </Cinder.collection>
        """
      end)

    {:ok, view, _html} = live(conn, path)
    render_async(view)
    view
  end

  defp start_paused_refresh(view, read) do
    # Pause the read so the pending UI assertions cannot race its result.
    test_pid = self()
    allow(Ash, test_pid, view.pid)

    expect(Ash, :read, fn query, opts ->
      send(test_pid, {:refresh_started, self()})

      receive do
        :continue_refresh -> read.(query, opts)
      after
        5_000 -> raise "test did not release the refresh query"
      end
    end)

    send(view.pid, {:refresh_table, "albums", silent: true})
    assert_receive {:refresh_started, query_pid}, 1_000
    query_pid
  end

  test "silent refresh keeps rows without an overlay until the new data arrives", %{conn: conn} do
    view = mount_refresh_collection(conn)
    assert render(view) =~ "Async Album"

    old_album =
      Cinder.Integration.Album
      |> Ash.read!()
      |> Enum.find(&(&1.title == "Async Album"))

    Ash.destroy!(old_album)
    generate(album(title: "Replacement Album", artist_id: old_album.artist_id))

    query_pid = start_paused_refresh(view, &call_original(Ash, :read, [&1, &2]))

    try do
      pending_html = render(view)
      assert pending_html =~ "Async Album"
      refute pending_html =~ "Replacement Album"
      refute has_element?(view, ~s([data-key="loading_overlay_class"]))
    after
      send(query_pid, :continue_refresh)
    end

    refreshed_html = render_async(view)
    assert refreshed_html =~ "Replacement Album"
    refute refreshed_html =~ "Async Album"
    assert refreshed_html =~ "Buffered Album"
  end

  test "failed silent refresh logs the error and keeps existing rows without an error indicator",
       %{conn: conn} do
    view = mount_refresh_collection(conn)
    query_pid = start_paused_refresh(view, fn _query, _opts -> {:error, :refresh_failed} end)

    log =
      capture_log(fn ->
        try do
          assert render(view) =~ "Async Album"
          refute has_element?(view, ~s([data-key="loading_overlay_class"]))
        after
          send(query_pid, :continue_refresh)
        end

        html = render_async(view)
        assert html =~ "Async Album"
        assert html =~ "Buffered Album"
        refute has_element?(view, ~s([data-key="error_class"]))
        refute has_element?(view, ~s([data-key="loading_overlay_class"]))
      end)

    assert log =~ "refresh_failed"
  end

  test "silent refresh of an empty collection uses normal loading and error states", %{conn: conn} do
    Ash.bulk_destroy!(Cinder.Integration.Album, :destroy, %{})
    view = mount_refresh_collection(conn)
    assert has_element?(view, ~s([data-key="empty_class"]))
    query_pid = start_paused_refresh(view, fn _query, _opts -> {:error, :refresh_failed} end)

    capture_log(fn ->
      try do
        assert has_element?(view, ~s([data-key="loading_overlay_class"]))
        refute has_element?(view, ~s([data-key="empty_class"]))
      after
        send(query_pid, :continue_refresh)
      end

      render_async(view)
      assert has_element?(view, ~s([data-key="error_class"]))
      refute has_element?(view, ~s([data-key="loading_overlay_class"]))
    end)
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
