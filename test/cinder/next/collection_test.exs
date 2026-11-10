defmodule Cinder.Next.CollectionTest do
  # The Music records are shared ETS data
  use Cinder.ConnCase, async: false

  require Ash.Query

  import Phoenix.LiveViewTest,
    only: [
      element: 2,
      element: 3,
      render: 1,
      render_change: 2,
      render_click: 1,
      render_click: 2,
      render_click: 3,
      render_component: 2,
      render_patch: 2,
      with_target: 2
    ]

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

  describe "paging" do
    # With the two albums from the main setup, five, in pages of two
    setup do
      for title <- ["Cold", "Dark", "Echo"], do: generate(album(title: title))
      :ok
    end

    defp paged(query \\ Ash.Query.sort(Music.Album, :title), pagination \\ [size: 2]) do
      Fixture.register(fn assigns ->
        assigns = assign(assigns, query: query, pagination: pagination)

        ~H"""
        <Cinder.Next.collection id="albums" query={@query} pagination={@pagination}>
          <:field :let={album} name="title" sort filter search>{album.title}</:field>
        </Cinder.Next.collection>
        """
      end)
    end

    # Synced to the URL, the rows change when the URL patch comes back, so `timeout`
    # waits for it
    defp titles(session, titles, opts \\ []) do
      titles
      |> Enum.reduce(session, &assert_has(&2, "#albums td", [text: &1] ++ opts))
      |> assert_has("#albums tbody tr", count: length(titles))
    end

    test "the previous and next pages, and where you are", %{conn: conn} do
      conn
      |> visit(paged())
      |> assert_has("#albums nav[aria-label=Pagination]", text: "Page 1 of 3")
      |> titles(["Abbey", "Blue"])
      |> assert_has("#albums nav button[disabled]", text: "Previous page")
      |> click_button("#albums nav button", "Next page")
      |> assert_has("#albums nav", text: "Page 2 of 3")
      |> titles(["Cold", "Dark"])
      |> click_button("#albums nav button", "Next page")
      |> assert_has("#albums nav", text: "Page 3 of 3")
      |> titles(["Echo"])
      |> assert_has("#albums nav button[disabled]", text: "Next page")
      |> click_button("#albums nav button", "Previous page")
      |> titles(["Cold", "Dark"])
    end

    test "back to the first page when the sort, the filters or the search change",
         %{conn: conn} do
      conn
      |> visit(paged())
      |> click_button("#albums nav button", "Next page")
      # Already sorted by title, so now the other way
      |> click_button("#albums th button", "Title")
      |> assert_has("#albums nav", text: "Page 1 of 3")
      |> titles(["Echo", "Dark"])
      |> click_button("#albums nav button", "Next page")
      # Abbey, Blue and Echo
      |> fill_in("Search", with: "e")
      |> assert_has("#albums nav", text: "Page 1 of 2")
      |> titles(["Echo", "Blue"])
      |> click_button("#albums nav button", "Next page")
      |> fill_in("Title", with: "e")
      |> assert_has("#albums nav", text: "Page 1 of 2")
    end

    test "when the parent changes the declarations, the page stays if the records would be the same",
         %{conn: conn} do
      path =
        Fixture.register(fn assigns ->
          ~H"""
          <Cinder.Next.collection
            id="albums"
            query={assigns[:query] || Ash.Query.sort(Music.Album, :title)}
            pagination={[size: 2]}
          >
            <:field :let={album} name="title" label={assigns[:label]}>{album.title}</:field>
          </Cinder.Next.collection>
          """
        end)

      session = conn |> visit(path) |> click_button("#albums nav button", "Next page")

      parent = fn change ->
        unwrap(session, fn view ->
          Fixture.run(view, change)
          render(view)
        end)
      end

      parent.(&assign(&1, :label, "Name"))
      |> assert_has("#albums th", text: "Name")
      |> assert_has("#albums nav", text: "Page 2 of 3")

      parent.(&assign(&1, :query, Ash.Query.sort(Music.Album, title: :desc)))
      |> assert_has("#albums nav", text: "Page 1 of 3")
      |> titles(["Echo", "Dark"])
    end

    test "no controls when everything fits on one page", %{conn: conn} do
      conn
      |> visit(paged(Ash.Query.sort(Music.Album, :title), size: 5))
      |> titles(["Abbey", "Blue", "Cold", "Dark", "Echo"])
      |> refute_has("#albums nav")
    end

    test "an action that doesn't paginate shows every record", %{conn: conn} do
      conn
      |> visit(paged(Ash.Query.for_read(Music.Album, :by_context), []))
      |> titles(["Abbey", "Blue", "Cold", "Dark", "Echo"])
      |> refute_has("#albums nav")
    end

    test "an action that can't count shows the page without a total", %{conn: conn} do
      query = Music.Album |> Ash.Query.for_read(:uncountable) |> Ash.Query.sort(:title)

      conn
      |> visit(paged(query))
      |> assert_has("#albums nav", text: "Page 1")
      |> refute_has("#albums nav", text: "of")
      |> click_button("#albums nav button", "Next page")
      |> titles(["Cold", "Dark"])
    end

    test "a page that isn't a positive number (a tampered event) is ignored", %{conn: conn} do
      conn
      |> visit(paged())
      |> unwrap(fn view ->
        next = element(view, "#albums nav button", "Next page")
        ["0", "-1", "two"] |> Enum.map(&render_click(next, %{"page" => &1})) |> List.last()
      end)
      |> assert_has("#albums nav", text: "Page 1 of 3")
    end

    test "by keyset, the previous and next pages, with no page number", %{conn: conn} do
      conn
      |> visit(paged(Ash.Query.sort(Music.Album, :title), mode: :keyset, size: 2))
      |> titles(["Abbey", "Blue"])
      |> refute_has("#albums nav span")
      |> assert_has("#albums nav button[disabled]", text: "Previous page")
      |> click_button("#albums nav button", "Next page")
      |> titles(["Cold", "Dark"])
      |> click_button("#albums nav button", "Next page")
      |> titles(["Echo"])
      |> assert_has("#albums nav button[disabled]", text: "Next page")
      |> click_button("#albums nav button", "Previous page")
      |> titles(["Cold", "Dark"])
      |> click_button("#albums nav button", "Previous page")
      |> titles(["Abbey", "Blue"])
      |> assert_has("#albums nav button[disabled]", text: "Previous page")
    end

    test "by keyset, back to the first page when the sort or the filters change",
         %{conn: conn} do
      conn
      |> visit(paged(Ash.Query.sort(Music.Album, :title), mode: :keyset, size: 2))
      |> click_button("#albums nav button", "Next page")
      |> click_button("#albums th button", "Title")
      |> titles(["Echo", "Dark"])
      |> assert_has("#albums nav button[disabled]", text: "Previous page")
      |> click_button("#albums nav button", "Next page")
      # Abbey, Blue and Echo
      |> fill_in("Title", with: "e")
      |> titles(["Echo", "Blue"])
      |> assert_has("#albums nav button[disabled]", text: "Previous page")
    end

    test "an action that only pages by keyset does so without being told", %{conn: conn} do
      query = Music.Album |> Ash.Query.for_read(:keyset_only) |> Ash.Query.sort(:title)

      conn
      |> visit(paged(query))
      |> titles(["Abbey", "Blue"])
      |> click_button("#albums nav button", "Next page")
      |> titles(["Cold", "Dark"])
    end

    test "each mode ignores the other's events (tampered ones)", %{conn: conn} do
      conn
      |> visit(paged(Ash.Query.sort(Music.Album, :title), mode: :keyset, size: 2))
      |> unwrap(&(&1 |> with_target("#albums") |> render_click("page", %{"page" => "2"})))
      |> titles(["Abbey", "Blue"])

      conn
      |> visit(paged())
      |> unwrap(&(&1 |> with_target("#albums") |> render_click("next_page", %{})))
      |> assert_has("#albums nav", text: "Page 1 of 3")
    end
  end

  describe "URL sync" do
    # With the two albums from the main setup, five, in pages of two
    setup do
      for {title, genre} <- [{"Cold", :rock}, {"Dark", :jazz}, {"Echo", :rock}] do
        generate(album(title: title, genre: genre))
      end

      :ok
    end

    defp synced(pagination \\ [size: 2]) do
      Fixture.register(fn assigns ->
        assigns = assign(assigns, pagination: pagination)

        ~H"""
        <Cinder.Next.collection
          id="albums"
          query={Ash.Query.sort(Music.Album, :title)}
          pagination={@pagination}
          url_state={@url_state}
        >
          <:field :let={album} name="title" sort filter search>{album.title}</:field>
          <:field name="genre" filter column={false} />
        </Cinder.Next.collection>
        """
      end)
    end

    test "what the user does goes in the URL", %{conn: conn} do
      path = synced()

      conn
      |> visit(path)
      |> click_button("#albums th button", "Title")
      |> assert_path(path, query_params: %{sort: "-title"}, timeout: 500)
      |> click_button("#albums nav button", "Next page")
      |> assert_path(path, query_params: %{sort: "-title", page: "2"}, timeout: 500)
      |> fill_in("Search", with: "e")
      |> assert_path(path, query_params: %{sort: "-title", search: "e"}, timeout: 500)
      # Of Echo, Blue and Abbey
      |> fill_in("Title", with: "b")
      |> assert_path(path, query_params: %{sort: "-title", search: "e", title: "b"}, timeout: 500)
      |> titles(["Blue", "Abbey"], timeout: 500)
    end

    test "visiting a URL shows what it says", %{conn: conn} do
      conn
      |> visit(synced() <> "?sort=-title&page=2&genre=rock")
      |> assert_has("#albums nav", text: "Page 2 of 2")
      |> titles(["Abbey"], timeout: 500)
      |> assert_has("#albums th[aria-sort=descending]", text: "Title")
    end

    test "exclusive, a URL's sorts after the first are ignored", %{conn: conn} do
      path =
        Fixture.register(fn assigns ->
          ~H"""
          <Cinder.Next.collection
            id="albums"
            resource={Music.Album}
            sort={[mode: :exclusive]}
            url_state={@url_state}
          >
            <:field :let={album} name="genre" sort>{album.genre}</:field>
            <:field :let={album} name="title" sort>{album.title}</:field>
          </Cinder.Next.collection>
          """
        end)

      conn
      |> visit(path <> "?sort=-genre,title")
      |> assert_has("#albums th[aria-sort=descending]", text: "Genre")
      |> assert_has("#albums th[aria-sort=none]", text: "Title")
    end

    test "going back to the default takes it out of the URL", %{conn: conn} do
      path = synced()

      conn
      |> visit(path)
      |> fill_in("Search", with: "e")
      |> click_button("#albums nav button", "Next page")
      |> assert_path(path, query_params: %{search: "e", page: "2"}, timeout: 500)
      |> click_button("#albums nav button", "Previous page")
      |> assert_path(path, query_params: %{search: "e"}, timeout: 500)
      |> fill_in("Title", with: "b")
      |> assert_path(path, query_params: %{search: "e", title: "b"}, timeout: 500)
      |> fill_in("Title", with: "")
      |> assert_path(path, query_params: %{search: "e"}, timeout: 500)
      |> fill_in("Search", with: "")
      |> assert_path(path, query_params: %{}, timeout: 500)
    end

    # Without `sort`, the URL has the default sort, so unsorted has to be in it
    test "sorting to unsorted, when the default sorts, stays unsorted on a reload", %{conn: conn} do
      path = synced()

      conn
      |> visit(path)
      |> click_button("#albums th button", "Title")
      |> assert_path(path, query_params: %{sort: "-title"}, timeout: 500)
      |> click_button("#albums th button", "Title")
      |> assert_path(path, query_params: %{sort: ""}, timeout: 500)
      |> reload_page()
      |> assert_has("#albums th[aria-sort=none]", text: "Title")
    end

    test "the app's own params stay", %{conn: conn} do
      path = synced()

      conn
      |> visit(path <> "?tab=albums")
      |> click_button("#albums nav button", "Next page")
      |> assert_path(path, query_params: %{tab: "albums", page: "2"}, timeout: 500)
    end

    test "a URL change from elsewhere (the back button) is shown", %{conn: conn} do
      path = synced()

      conn
      |> visit(path)
      |> click_button("#albums nav button", "Next page")
      |> unwrap(&render_patch(&1, path <> "?sort=-title"))
      |> assert_has("#albums nav", text: "Page 1 of 3")
      |> titles(["Echo", "Dark"], timeout: 500)
    end

    test "params the collection can't use are ignored", %{conn: conn} do
      conn
      |> visit(synced() <> "?sort=-nope&page=two&genre=polka")
      |> assert_has("#albums nav", text: "Page 1 of 3")
      |> titles(["Abbey", "Blue"], timeout: 500)
    end

    # The cursor's value is Ash's, so the URL is only checked for having it
    test "by keyset, the page goes in the URL, and a reload shows it", %{conn: conn} do
      path = synced(mode: :keyset, size: 2)

      conn
      |> visit(path)
      |> click_button("#albums nav button", "Next page")
      |> refute_path(path, query_params: %{}, timeout: 500)
      |> reload_page()
      |> titles(["Cold", "Dark"])
      |> click_button("#albums nav button", "Previous page")
      |> refute_path(path, query_params: %{}, timeout: 500)
      |> reload_page()
      |> titles(["Abbey", "Blue"])
    end

    # The engine logs the failed read
    @tag :capture_log
    test "a cursor that isn't one shows the first page", %{conn: conn} do
      conn
      |> visit(synced(mode: :keyset, size: 2) <> "?after=not-a-cursor")
      |> titles(["Abbey", "Blue"], timeout: 500)
    end

    test "when the parent changes the declarations and the page resets, so does the URL",
         %{conn: conn} do
      path =
        Fixture.register(fn assigns ->
          ~H"""
          <Cinder.Next.collection
            id="albums"
            query={assigns[:query] || Ash.Query.sort(Music.Album, :title)}
            pagination={[size: 2]}
            url_state={@url_state}
          >
            <:field :let={album} name="title">{album.title}</:field>
          </Cinder.Next.collection>
          """
        end)

      conn
      |> visit(path)
      |> click_button("#albums nav button", "Next page")
      |> assert_path(path, query_params: %{page: "2"}, timeout: 500)
      |> unwrap(fn view ->
        Fixture.run(view, &assign(&1, :query, Ash.Query.sort(Music.Album, title: :desc)))
        render(view)
      end)
      |> assert_path(path, query_params: %{}, timeout: 500)
      |> titles(["Echo", "Dark"], timeout: 500)
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

  describe "read action arguments" do
    defp by_genre(input \\ []) do
      Fixture.register(fn assigns ->
        assigns = assign(assigns, input: input)

        ~H"""
        <Cinder.Next.collection id="albums" resource={Music.Album} action={:by_genre} url_state={@url_state}>
          <:field :let={album} name="title">{album.title}</:field>
          <:argument name="genre" input={@input} />
        </Cinder.Next.collection>
        """
      end)
    end

    # A form doesn't say a field is required before it's used
    test "nothing is read until a required argument has a value, and no error shows",
         %{conn: conn} do
      conn
      |> visit(by_genre())
      |> assert_has("#albums-filters label", text: "Genre")
      |> refute_has("#albums tbody tr")
      |> refute_has("#albums", text: "required")
      |> choose("Jazz")
      |> assert_has("#albums tbody tr", count: 1)
      |> assert_has("#albums td", text: "Blue")
    end

    # `QueryBuilder` logs every failed read, even one the user just needs to fix
    @tag :capture_log
    test "a value the action can't use shows its message under the input, and no records",
         %{conn: conn} do
      conn
      |> visit(by_genre(type: :text))
      |> fill_in("Genre", with: "polka")
      |> assert_has("#albums-filters", text: "is invalid")
      |> refute_has("#albums tbody tr")
      |> fill_in("Genre", with: "rock")
      |> refute_has("#albums-filters", text: "is invalid")
      |> assert_has("#albums td", text: "Abbey")
    end

    test "an argument's value goes in the URL, and comes back from it", %{conn: conn} do
      path = by_genre()

      conn
      |> visit(path)
      |> choose("Jazz")
      |> assert_path(path, query_params: %{genre: "jazz"}, timeout: 500)

      conn
      |> visit(path <> "?genre=rock")
      |> assert_has("#albums tbody tr", count: 1)
      |> assert_has("#albums td", text: "Abbey")
    end

    test "an argument with a `param` goes by it in the URL", %{conn: conn} do
      path =
        Fixture.register(fn assigns ->
          ~H"""
          <Cinder.Next.collection id="albums" resource={Music.Album} action={:by_genre} url_state={@url_state}>
            <:field :let={album} name="title">{album.title}</:field>
            <:argument name="genre" param="style" />
          </Cinder.Next.collection>
          """
        end)

      conn
      |> visit(path)
      |> choose("Jazz")
      |> assert_path(path, query_params: %{style: "jazz"}, timeout: 500)
      |> assert_has("#albums td", text: "Blue")

      conn
      |> visit(path <> "?style=rock")
      |> assert_has("#albums td", text: "Abbey")
    end
  end

  describe "selection" do
    defp album_id(title) do
      Music.Album |> Ash.Query.filter(title == ^title) |> Ash.read_one!() |> Map.fetch!(:id)
    end

    # Phoenix renders a `true` boolean attribute bare, so this finds the checked boxes
    @checked "#albums tbody input[type=checkbox][checked]"

    defp checked(session, 0), do: refute_has(session, @checked)
    defp checked(session, count), do: assert_has(session, @checked, count: count)

    defp click_box(session, selector) do
      unwrap(session, fn view -> view |> element(selector) |> render_click() end)
    end

    # The parent hears of changes only when the test does: without a `handle_info`
    # clause for the message, the fixture crashes, as a real parent would
    defp selectable(selectable, opts \\ []) do
      on_change = if opts[:forward_to], do: :picked

      Fixture.register(
        fn assigns ->
          assigns = assign(assigns, selectable: selectable, on_change: on_change)

          ~H"""
          <Cinder.Next.collection
            id="albums"
            query={Ash.Query.sort(Music.Album, :title)}
            actor={assigns[:actor]}
            selectable={@selectable}
            on_selection_change={@on_change}
          >
            <:field :let={album} name="title">{album.title}</:field>
            <:field name="genre" filter column={false} />
          </Cinder.Next.collection>
          """
        end,
        opts
      )
    end

    test "a record's box selects it, and the heading's selects or clears the page",
         %{conn: conn} do
      conn
      |> visit(selectable(true))
      |> assert_has("#albums th input[type=checkbox][aria-label='Select all on this page']")
      |> assert_has("#albums tbody input[type=checkbox][aria-label='Select row']", count: 2)
      |> click_box("#albums-select-#{album_id("Blue")}")
      |> checked(1)
      |> assert_has("#albums-select-#{album_id("Blue")}[checked]")
      |> refute_has("#albums th input[checked]")
      |> click_box("#albums th input")
      |> checked(2)
      |> assert_has("#albums th input[checked]")
      |> click_box("#albums th input")
      |> checked(0)
    end

    test "a record that can't be selected has a disabled box, and a forged event for it is ignored",
         %{conn: conn} do
      abbey = album_id("Abbey")
      blue = album_id("Blue")

      conn
      |> visit(selectable(&(&1.genre == :jazz)))
      |> assert_has("#albums-select-#{abbey}[disabled]")
      # Blue's box, sending Abbey's id
      |> unwrap(fn view ->
        view |> element("#albums-select-#{blue}") |> render_click(%{"id" => abbey})
      end)
      |> checked(0)
      |> click_box("#albums th input")
      |> checked(1)
      |> assert_has("#albums-select-#{blue}[checked]")
    end

    # As TanStack Table does: a filter hides selected records, it doesn't unselect them
    test "the selection stays when filtering, and is cleared when the actor changes",
         %{conn: conn} do
      blue = album_id("Blue")

      conn
      |> visit(selectable(true))
      |> click_box("#albums-select-#{blue}")
      |> choose("Rock")
      |> checked(0)
      |> choose("Jazz")
      |> assert_has("#albums-select-#{blue}[checked]")
      |> unwrap(fn view ->
        Fixture.run(view, &assign(&1, :actor, %{name: "Someone"}))
        render(view)
      end)
      |> checked(0)
    end

    test "the parent hears of each change, and only of changes", %{conn: conn} do
      blue = album_id("Blue")
      session = visit(conn, selectable(true, forward_to: self()))

      # Mounting changes nothing
      refute_received {:picked, _payload}
      click_box(session, "#albums-select-#{blue}")

      expected = %{selected_ids: MapSet.new([blue]), selected_count: 1, component_id: "albums"}
      assert_receive {:picked, ^expected}
    end
  end
end
