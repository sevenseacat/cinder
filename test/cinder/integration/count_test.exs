defmodule Cinder.Integration.CountTest do
  @moduledoc """
  Covers the `count` option of `pagination` on a mounted collection: how the
  footer reads with a synchronous, asynchronous or disabled total count.
  """
  use Cinder.ConnCase, async: false

  import Phoenix.ConnTest, only: [get: 2]
  import Phoenix.LiveViewTest, only: [live: 2]

  defp collection(pagination) do
    fn assigns ->
      assigns = assign(assigns, :pagination, pagination)

      ~H"""
      <Cinder.collection
        resource={Cinder.Integration.Album}
        url_state={@url_state}
        page_size={2}
        pagination={@pagination}
      >
        <:col :let={album} field="title" sort>{album.title}</:col>
      </Cinder.collection>
      """
    end
  end

  setup do
    artist = generate(artist(name: "Count Artist"))

    for title <- ["Alpha", "Bravo", "Charlie", "Delta", "Echo"] do
      generate(album(title: title, artist_id: artist.id))
    end

    on_exit(fn ->
      Ash.bulk_destroy!(Cinder.Integration.Album, :destroy, %{})
      Ash.bulk_destroy!(Cinder.Integration.Artist, :destroy, %{})
    end)

    :ok
  end

  defp footer(conn, pagination) do
    path = Cinder.TestLive.Fixture.register(collection(pagination)) <> "?sort=title"
    {:ok, _view, html} = live(conn, path)
    html
  end

  test "offset pagination counts by default", %{conn: conn} do
    html = footer(conn, :offset)

    assert html =~ "Page 1 of 3"
    assert html =~ "showing 1-2 of 5"
  end

  test "an asynchronous count shows the same footer once it arrives", %{conn: conn} do
    html = footer(conn, count: :async)

    assert html =~ "Page 1 of 3"
    assert html =~ "showing 1-2 of 5"
  end

  test "offset pagination without a count only offers previous and next", %{conn: conn} do
    html = footer(conn, count: false)

    assert html =~ "Alpha"
    assert html =~ "Page 1"
    assert html =~ ~s(title="Next page")
    refute html =~ "Page 1 of"
    refute html =~ "showing"
    refute html =~ ~s(title="Last page")
  end

  test "keyset pagination without a count only offers previous and next", %{conn: conn} do
    html = footer(conn, mode: :keyset, count: false)

    assert html =~ "Alpha"
    assert html =~ "Next"
    refute html =~ ~r/\d+ items/
  end
end
