defmodule Cinder.Next.CollectionTest do
  # The Music records are shared ETS data
  use Cinder.ConnCase, async: false

  require Ash.Query

  import Phoenix.LiveViewTest, only: [element: 2, render_change: 2, render_component: 2]

  alias Cinder.TestLive.Fixture

  setup do
    artist = generate(artist(name: "Next Artist"))

    for {title, genre} <- [{"Blue", :jazz}, {"Abbey", :rock}] do
      generate(album(title: title, genre: genre, artist_id: artist.id))
    end

    on_exit(fn ->
      Ash.bulk_destroy!(Music.Album, :destroy, %{})
      Ash.bulk_destroy!(Music.Artist, :destroy, %{})
    end)
  end

  # `required: true` only warns at compile time, so without this the error is a
  # `KeyError` on `:id`
  test "a collection without an id is an error that says so" do
    field = %{__slot__: :field, name: "title", inner_block: fn _changed, album -> album.title end}

    assert_raise ArgumentError,
                 "<Cinder.Next.collection> needs an `id`, unique on the page",
                 fn ->
                   render_component(&Cinder.Next.collection/1,
                     resource: Music.Album,
                     field: [field]
                   )
                 end
  end

  test "shows the records in a table, a column per <:field>", %{conn: conn} do
    path =
      Fixture.register(fn assigns ->
        ~H"""
        <Cinder.Next.collection id="albums" resource={Music.Album}>
          <:field :let={album} name="title">{album.title}</:field>
          <:field :let={album} name="artist.name" label="Band">{album.artist.name}</:field>
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
          <:field :let={album} name="title" sort>{album.title}</:field>
          <:field :let={album} name="artist.name">{album.artist.name}</:field>
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

  describe "filtering" do
    defp filterable do
      Fixture.register(fn assigns ->
        ~H"""
        <Cinder.Next.collection id="albums" resource={Music.Album}>
          <:field :let={album} name="title" filter>{album.title}</:field>
          <:field :let={album} name="genre" filter>{album.genre}</:field>
          <:field :let={album} name="artist.name">{album.artist.name}</:field>
        </Cinder.Next.collection>
        """
      end)
    end

    test "typing in a text filter shows only the records that match", %{conn: conn} do
      conn
      |> visit(filterable())
      |> fill_in("Title", with: "ab")
      |> assert_has("#albums tbody tr", count: 1)
      |> assert_has("#albums td", text: "Abbey")
      |> fill_in("Title", with: "")
      |> assert_has("#albums tbody tr", count: 2)
    end

    test "choosing in a select filter shows only the records that match", %{conn: conn} do
      conn
      |> visit(filterable())
      |> choose("Jazz")
      |> assert_has("#albums tbody tr", count: 1)
      |> assert_has("#albums td", text: "Blue")
    end

    test "a filter's label and options show in its control", %{conn: conn} do
      path =
        Fixture.register(fn assigns ->
          ~H"""
          <Cinder.Next.collection id="albums" resource={Music.Album}>
            <:field :let={album} name="genre" filter={[label: "Style", prompt: "Any"]}>
              {album.genre}
            </:field>
          </Cinder.Next.collection>
          """
        end)

      conn
      |> visit(path)
      |> assert_has("#albums th", text: "Genre")
      |> assert_has("#albums-filters label", text: "Style")
      |> assert_has("#albums-filters button", text: "Any")
    end

    test "a field that isn't a column filters, with no heading or cells", %{conn: conn} do
      path =
        Fixture.register(fn assigns ->
          ~H"""
          <Cinder.Next.collection id="albums" resource={Music.Album}>
            <:field :let={album} name="title">{album.title}</:field>
            <:field name="genre" filter column={false} />
          </Cinder.Next.collection>
          """
        end)

      conn
      |> visit(path)
      |> assert_has("#albums th", count: 1)
      |> assert_has("#albums tbody tr:first-child td", count: 1)
      |> assert_has("#albums-filters label", text: "Genre")
      |> choose("Jazz")
      |> assert_has("#albums tbody tr", count: 1)
      |> assert_has("#albums td", text: "Blue")
    end

    test "a filter on a field that isn't filterable (a tampered event) is ignored",
         %{conn: conn} do
      conn
      |> visit(filterable())
      |> unwrap(fn view ->
        view
        |> element("#albums-filters")
        |> render_change(%{"filters" => %{"title" => "ab", "artist.name" => "nobody"}})
      end)
      |> assert_has("#albums tbody tr", count: 1)
      |> assert_has("#albums td", text: "Abbey")
    end
  end

  describe "searching" do
    setup do
      miles = generate(artist(name: "Miles Davis"))
      generate(album(title: "Kind of Blue", genre: :jazz, artist_id: miles.id))
      :ok
    end

    defp searchable(search \\ []) do
      Fixture.register(fn assigns ->
        assigns = assign(assigns, :search, search)

        ~H"""
        <Cinder.Next.collection id="albums" resource={Music.Album} search={@search}>
          <:field :let={album} name="title" search>{album.title}</:field>
          <:field name="artist.name" search column={false} />
        </Cinder.Next.collection>
        """
      end)
    end

    test "typing in the search box shows the records matching any searchable field, in any case",
         %{conn: conn} do
      conn
      |> visit(searchable())
      |> assert_has("#albums-filters label", text: "Search")
      |> assert_has("#albums-filters input[type=search][placeholder='Search...']")
      |> fill_in("Search", with: "BLUE")
      |> assert_has("#albums tbody tr", count: 2)
      |> fill_in("Search", with: "miles")
      |> assert_has("#albums tbody tr", count: 1)
      |> assert_has("#albums td", text: "Kind of Blue")
      |> fill_in("Search", with: "")
      |> assert_has("#albums tbody tr", count: 3)
    end

    test "without a searchable field there's no search box", %{conn: conn} do
      conn
      |> visit(filterable())
      |> refute_has("#albums-filters input[type=search]")
    end

    test "the search box's label and placeholder", %{conn: conn} do
      conn
      |> visit(searchable(label: "Find", placeholder: "Title or artist"))
      |> assert_has("#albums-filters label", text: "Find")
      |> assert_has("#albums-filters input[type=search][placeholder='Title or artist']")
    end

    test "a custom search function's query is the one read", %{conn: conn} do
      # Only an exact artist name, which the default search wouldn't do
      search_fn = fn query, fields, text ->
        %{expr: artist} = Enum.find(fields, &(&1.name == "artist.name"))
        Ash.Query.filter(query, ^artist == ^text)
      end

      conn
      |> visit(searchable(fn: search_fn))
      |> fill_in("Search", with: "miles")
      |> refute_has("#albums tbody tr")
      |> fill_in("Search", with: "Miles Davis")
      |> assert_has("#albums tbody tr", count: 1)
      |> assert_has("#albums td", text: "Kind of Blue")
    end
  end

  test "reads as the actor given", %{conn: conn} do
    path =
      Fixture.register(fn assigns ->
        ~H"""
        <Cinder.Next.collection id="albums" resource={Music.Album} actor={%{name: "Rebecca"}}>
          <:field :let={album} name="viewer">{album.viewer}</:field>
        </Cinder.Next.collection>
        """
      end)

    conn
    |> visit(path)
    |> assert_has("#albums td", text: "Rebecca", count: 2)
  end
end
