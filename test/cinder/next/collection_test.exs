defmodule Cinder.Next.CollectionTest do
  # The Music records are shared ETS data
  use Cinder.ConnCase, async: false

  import Phoenix.LiveViewTest, only: [render_component: 2]

  alias Cinder.TestLive.Fixture

  setup do
    artist = generate(artist(name: "Next Artist"))

    for title <- ["Blue", "Abbey"] do
      generate(album(title: title, artist_id: artist.id))
    end

    on_exit(fn ->
      Ash.bulk_destroy!(Music.Album, :destroy, %{})
      Ash.bulk_destroy!(Music.Artist, :destroy, %{})
    end)
  end

  # `required: true` only warns at compile time, so without this the error is a
  # `KeyError` on `:id`
  test "a collection without an id is an error that says so" do
    col = %{__slot__: :col, field: "title", inner_block: fn _changed, album -> album.title end}

    assert_raise ArgumentError,
                 "<Cinder.Next.collection> needs an `id`, unique on the page",
                 fn ->
                   render_component(&Cinder.Next.collection/1,
                     resource: Music.Album,
                     col: [col]
                   )
                 end
  end

  test "shows the records in a table, a column per <:col>", %{conn: conn} do
    path =
      Fixture.register(fn assigns ->
        ~H"""
        <Cinder.Next.collection id="albums" resource={Music.Album}>
          <:col :let={album} field="title">{album.title}</:col>
          <:col :let={album} field="artist.name" label="Band">{album.artist.name}</:col>
        </Cinder.Next.collection>
        """
      end)

    conn
    |> visit(path)
    |> assert_has("#albums th", text: "Title")
    |> assert_has("#albums th", text: "Band")
    |> assert_has("#albums tbody tr", count: 2)
    |> assert_has("#albums td", text: "Blue")
    |> assert_has("#albums td", text: "Abbey")
    |> assert_has("#albums td", text: "Next Artist")
  end

  describe "sorting" do
    defp sortable do
      Fixture.register(fn assigns ->
        ~H"""
        <Cinder.Next.collection id="albums" resource={Music.Album}>
          <:col :let={album} field="title" sort>{album.title}</:col>
          <:col :let={album} field="artist.name">{album.artist.name}</:col>
        </Cinder.Next.collection>
        """
      end)
    end

    test "clicking a sortable heading sorts by it, then the other way, then not at all",
         %{conn: conn} do
      session = visit(conn, sortable())

      session
      |> refute_has("#albums th button", text: "Artist > Name")
      |> assert_has("#albums th[aria-sort=none]", text: "Title")
      |> click_button("#albums th button", "Title")
      |> assert_has("#albums th[aria-sort=ascending]", text: "Title ▲")
      |> assert_has("#albums tbody tr:first-child td", text: "Abbey")
      |> click_button("#albums th button", "Title")
      |> assert_has("#albums th[aria-sort=descending]", text: "Title ▼")
      |> assert_has("#albums tbody tr:first-child td", text: "Blue")
      |> click_button("#albums th button", "Title")
      |> assert_has("#albums th[aria-sort=none]", text: "Title")
    end
  end

  test "reads as the actor given", %{conn: conn} do
    path =
      Fixture.register(fn assigns ->
        ~H"""
        <Cinder.Next.collection id="albums" resource={Music.Album} actor={%{name: "Rebecca"}}>
          <:col :let={album} field="viewer">{album.viewer}</:col>
        </Cinder.Next.collection>
        """
      end)

    conn
    |> visit(path)
    |> assert_has("#albums td", text: "Rebecca", count: 2)
  end
end
