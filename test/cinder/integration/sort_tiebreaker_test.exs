defmodule Cinder.Integration.SortTiebreakerTest do
  @moduledoc """
  A column's `then` tiebreakers, through a mounted collection with its sort in the URL.
  """
  use Cinder.ConnCase, async: false

  import Phoenix.LiveViewTest, only: [render: 1]

  defp sort_only_collection(assigns) do
    ~H"""
    <Cinder.collection resource={Music.Album} url_state={@url_state}>
      <:col :let={album} field="title" sort={[then: ["price"]]}>{album.title}</:col>
      <:col :let={album} field="price" sort>{"$#{album.price}"}</:col>
      <:col :let={album} field="track_count" sort>{album.track_count}</:col>
    </Cinder.collection>
    """
  end

  defp filtered_collection(assigns) do
    ~H"""
    <Cinder.collection resource={Music.Album} url_state={@url_state}>
      <:col :let={album} field="title" filter sort={[then: ["price"]]}>{album.title}</:col>
      <:col :let={album} field="price">{"$#{album.price}"}</:col>
    </Cinder.collection>
    """
  end

  setup do
    artist = generate(artist(name: "Tiebreaker Artist"))

    # Inserted out of price order, so only the tiebreaker puts them in it
    for {price, track_count} <- [{"20", 1}, {"10", 2}, {"30", 3}] do
      generate(
        album(
          title: "Same",
          price: Decimal.new(price),
          track_count: track_count,
          artist_id: artist.id
        )
      )
    end

    on_exit(fn ->
      Ash.bulk_destroy!(Music.Album, :destroy, %{})
      Ash.bulk_destroy!(Music.Artist, :destroy, %{})
    end)

    :ok
  end

  defp assert_order(conn, path, expected) do
    conn
    |> visit(path)
    |> unwrap(fn view ->
      html = render(view)

      assert html =~ ~r/#{Enum.map_join(expected, ".*", &"\\$#{&1}")}/s,
             "expected #{inspect(expected)}"

      html
    end)
  end

  test "breaks ties on a sort-only column", %{conn: conn} do
    path = Cinder.TestLive.Fixture.register(&sort_only_collection/1)

    assert_order(conn, path <> "?sort=title", ["10", "20", "30"])
    assert_order(conn, path <> "?sort=-title", ["30", "20", "10"])
  end

  test "breaks ties on a filterable column", %{conn: conn} do
    path = Cinder.TestLive.Fixture.register(&filtered_collection/1)

    assert_order(conn, path <> "?sort=title", ["10", "20", "30"])
  end

  test "comes after the user's later sorts", %{conn: conn} do
    path = Cinder.TestLive.Fixture.register(&sort_only_collection/1)

    # track_count ties nothing, so price never gets a say
    assert_order(conn, path <> "?sort=title,-track_count", ["30", "10", "20"])
  end

  test "doesn't override a later explicit sort on the same field", %{conn: conn} do
    path = Cinder.TestLive.Fixture.register(&sort_only_collection/1)

    assert_order(conn, path <> "?sort=title,-price", ["30", "20", "10"])
  end
end
