defmodule Cinder.Integration.AsyncLoadTest do
  @moduledoc """
  Covers the async data-loading path end-to-end.

  Every other integration test loads data synchronously (see `Cinder.ConnCase`)
  for simplicity. This test opts back into Cinder's default `start_async` loading
  to prove the full async cycle works: the view mounts, the async query runs in a
  separate task, replies, and the rows appear on re-render.
  """
  use Cinder.ConnCase, async: false

  # Opt back into async loading for this test (ConnCase's setup disabled it).
  setup {Cinder.TestHelpers, :enable_async_loading}

  defp album_collection(assigns) do
    ~H"""
    <Cinder.collection resource={Cinder.Integration.Album} url_state={@url_state}>
      <:col :let={album} field="title" sort>{album.title}</:col>
    </Cinder.collection>
    """
  end

  setup do
    artist = generate(artist(name: "Async Artist"))
    generate(album(title: "Async Album", genre: :rock, artist_id: artist.id))

    on_exit(fn ->
      Ash.bulk_destroy!(Cinder.Integration.Album, :destroy, %{})
      Ash.bulk_destroy!(Cinder.Integration.Artist, :destroy, %{})
    end)

    %{path: Cinder.TestLive.Fixture.register(&album_collection/1)}
  end

  test "rows appear after the async query resolves", %{conn: conn, path: path} do
    conn
    |> visit(path)
    # The data is not present on the first synchronous render; it arrives only
    # after the start_async task replies, so we wait for it with a timeout.
    |> assert_has("td", text: "Async Album", timeout: 1000)
  end
end
