defmodule Cinder.Integration.LiveViewTest do
  @moduledoc """
  End-to-end LiveView integration tests for Cinder collections.

  These tests mount a real LiveView, interact with it (sort, filter, paginate),
  and verify the results — covering flows that render_component tests cannot.

  Data loads synchronously here (see `Cinder.ConnCase`), so a rendered view
  reflects the query result immediately. The async load path is covered
  separately by `Cinder.Integration.AsyncLoadTest`.
  """
  use Cinder.ConnCase, async: false

  # The collection markup under test. The fixture LiveView has no logic of its
  # own — this function supplies the template, so what's exercised is real
  # Cinder, not test scaffolding.
  defp album_collection(assigns) do
    ~H"""
    <Cinder.collection
      resource={Cinder.Integration.Album}
      url_state={@url_state}
      page_size={[default: 25, options: [3, 5, 10, 25]]}
    >
      <:col :let={album} field="title" filter sort search>{album.title}</:col>
      <:col :let={album} field="genre" filter={:select} sort>{album.genre}</:col>
      <:col :let={album} field="price" filter sort>{Decimal.to_string(album.price)}</:col>
      <:col :let={album} field="release_date" filter sort>{to_string(album.release_date)}</:col>
      <:col :let={album} field="is_remastered" filter>{to_string(album.is_remastered)}</:col>
    </Cinder.collection>
    """
  end

  setup do
    artist = generate(artist(name: "Test Artist"))

    generate(
      album(title: "Dirt", genre: :rock, price: Decimal.new("12.99"), artist_id: artist.id)
    )

    generate(
      album(title: "Facelift", genre: :rock, price: Decimal.new("11.99"), artist_id: artist.id)
    )

    generate(
      album(title: "Unplugged", genre: :rock, price: Decimal.new("14.99"), artist_id: artist.id)
    )

    generate(
      album(
        title: "Jar of Flies",
        genre: :rock,
        price: Decimal.new("9.99"),
        artist_id: artist.id
      )
    )

    generate(
      album(
        title: "Blue Train",
        genre: :jazz,
        price: Decimal.new("10.99"),
        artist_id: artist.id
      )
    )

    generate(
      album(
        title: "A Love Supreme",
        genre: :jazz,
        price: Decimal.new("13.99"),
        artist_id: artist.id
      )
    )

    generate(
      album(
        title: "Giant Steps",
        genre: :jazz,
        price: Decimal.new("11.99"),
        artist_id: artist.id
      )
    )

    generate(
      album(
        title: "Pop Hits Vol 1",
        genre: :pop,
        price: Decimal.new("5.99"),
        artist_id: artist.id
      )
    )

    generate(
      album(
        title: "Pop Hits Vol 2",
        genre: :pop,
        price: Decimal.new("5.99"),
        artist_id: artist.id
      )
    )

    generate(
      album(
        title: "Pop Hits Vol 3",
        genre: :pop,
        price: Decimal.new("5.99"),
        artist_id: artist.id
      )
    )

    on_exit(fn ->
      Ash.bulk_destroy!(Cinder.Integration.Album, :destroy, %{})
      Ash.bulk_destroy!(Cinder.Integration.Artist, :destroy, %{})
    end)

    %{path: Cinder.TestLive.Fixture.register(&album_collection/1)}
  end

  describe "initial render" do
    test "collection loads and displays data", %{conn: conn, path: path} do
      conn
      |> visit(path)
      |> assert_has("td", text: "Dirt")
      |> assert_has("td", text: "Blue Train")
      |> assert_has("td", text: "Pop Hits Vol 1")
    end
  end

  describe "sorting" do
    test "clicking a column header sorts data", %{conn: conn, path: path} do
      conn
      |> visit(path)
      |> unwrap(fn view ->
        view
        |> Phoenix.LiveViewTest.element("[phx-click=toggle_sort][phx-value-key=title]")
        |> Phoenix.LiveViewTest.render_click()
      end)
      |> assert_has("tr[data-key=row_class]:first-child td:first-child",
        text: "A Love Supreme"
      )
    end

    test "sort state persists in URL", %{conn: conn, path: path} do
      conn
      |> visit(path <> "?sort=title")
      |> assert_has("tr[data-key=row_class]:first-child td:first-child",
        text: "A Love Supreme"
      )
    end
  end

  describe "text filtering" do
    test "typing in a text filter narrows results", %{conn: conn, path: path} do
      conn
      |> visit(path)
      |> fill_in("Title", with: "Dirt")
      |> assert_has("td", text: "Dirt")
      |> refute_has("td", text: "Blue Train")
    end

    test "clearing a text filter restores results", %{conn: conn, path: path} do
      conn
      |> visit(path)
      |> fill_in("Title", with: "Dirt")
      |> refute_has("td", text: "Blue Train")
      |> fill_in("Title", with: "")
      |> assert_has("td", text: "Blue Train")
    end
  end

  describe "select filtering" do
    test "choosing a genre filters to that genre", %{conn: conn, path: path} do
      conn
      |> visit(path)
      |> unwrap(fn view ->
        # Cinder's select filter uses radio buttons, not a native <select>
        view
        |> Phoenix.LiveViewTest.form("form", %{filters: %{genre: "rock"}})
        |> Phoenix.LiveViewTest.render_change()
      end)
      |> assert_has("td", text: "Dirt")
      |> assert_has("td", text: "Facelift")
      |> refute_has("td", text: "Blue Train")
      |> refute_has("td", text: "Pop Hits Vol 1")
    end
  end

  describe "search" do
    test "typing in search narrows results across searchable columns", %{conn: conn, path: path} do
      conn
      |> visit(path)
      |> fill_in("Search", with: "Dirt")
      |> assert_has("td", text: "Dirt")
      |> refute_has("td", text: "Blue Train")
    end
  end

  describe "pagination" do
    test "filtering resets to page 1", %{conn: conn, path: path} do
      conn
      |> visit(path <> "?page_size=3&sort=title&page=2")
      # We're on page 2 — should NOT have page 1 data
      |> refute_has("td", text: "A Love Supreme")
      |> fill_in("Title", with: "Love")
      # Filter should reset to page 1 and show matching result
      |> assert_has("td", text: "A Love Supreme")
    end

    test "navigating between pages shows different data", %{conn: conn, path: path} do
      conn
      |> visit(path <> "?page_size=3&sort=title")
      |> assert_has("td", text: "A Love Supreme")
      |> assert_has("td", text: "Blue Train")
      |> assert_has("td", text: "Dirt")
      |> refute_has("td", text: "Facelift")
      |> unwrap(fn view ->
        view
        |> Phoenix.LiveViewTest.element(
          "button[phx-click=goto_page][phx-value-page=\"2\"][title=\"Go to page 2\"]"
        )
        |> Phoenix.LiveViewTest.render_click()
      end)
      |> assert_has("td", text: "Facelift")
      |> refute_has("td", text: "Dirt")
    end
  end

  describe "URL state round-trip" do
    test "filter state restores from URL", %{conn: conn, path: path} do
      conn
      |> visit(path <> "?title=Dirt")
      |> assert_has("td", text: "Dirt")
      |> refute_has("td", text: "Blue Train")
    end

    test "sort state restores from URL", %{conn: conn, path: path} do
      conn
      |> visit(path <> "?sort=title")
      |> assert_has("tr[data-key=row_class]:first-child td:first-child",
        text: "A Love Supreme"
      )
    end

    test "combined state restores from URL", %{conn: conn, path: path} do
      conn
      |> visit(path <> "?sort=title&genre=rock")
      |> assert_has("td", text: "Dirt")
      |> refute_has("td", text: "Blue Train")
      |> assert_has("tr[data-key=row_class]:first-child td:first-child", text: "Dirt")
    end
  end
end
