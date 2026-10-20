defmodule Cinder.Next.ParityTest do
  @moduledoc """
  Spike comparison (7CC-158): `Cinder.Integration.LiveViewTest`'s scenarios, run
  against both `Cinder.collection` and `Cinder.Next.collection` with the same
  steps and assertions. Only the selectors that depend on each shell's markup
  differ.
  """
  use Cinder.ConnCase, async: false

  @implementations %{
    current: %{
      sort_title: "[phx-click=toggle_sort][phx-value-key=title]",
      first_cell: "tr[data-key=row_class]:first-child td:first-child",
      page_2: ~s(button[phx-click=goto_page][phx-value-page="2"][title="Go to page 2"])
    },
    next: %{
      sort_title: ~s([data-part="sort"][phx-value-field="title"]),
      first_cell: ~s(tr[data-part="row"]:first-child td:first-child),
      page_2: ~s(button[data-part="page"][data-kind="page"][phx-value-page="2"])
    }
  }

  defp album_collection(:current) do
    fn assigns ->
      ~H"""
      <Cinder.collection
        resource={Music.Album}
        url_state={@url_state}
        page_size={[default: 25, options: [3, 5, 10, 25]]}
      >
        <:col :let={album} field="title" filter sort search>{album.title}</:col>
        <:col :let={album} field="genre" filter={[type: :select]} sort>{album.genre}</:col>
        <:col :let={album} field="price" sort>{Decimal.to_string(album.price)}</:col>
      </Cinder.collection>
      """
    end
  end

  defp album_collection(:next) do
    fn assigns ->
      ~H"""
      <Cinder.Next.collection resource={Music.Album} url_state={@url_state} page_size={25}>
        <:col :let={album} field="title" filter sort search>{album.title}</:col>
        <:col :let={album} field="genre" filter={[type: :select]} sort>{album.genre}</:col>
        <:col :let={album} field="price" sort>{Decimal.to_string(album.price)}</:col>
      </Cinder.Next.collection>
      """
    end
  end

  setup do
    artist = generate(artist(name: "Test Artist"))

    for {title, genre} <- [
          {"Dirt", :rock},
          {"Facelift", :rock},
          {"Unplugged", :rock},
          {"Jar of Flies", :rock},
          {"Blue Train", :jazz},
          {"A Love Supreme", :jazz},
          {"Giant Steps", :jazz},
          {"Pop Hits Vol 1", :pop},
          {"Pop Hits Vol 2", :pop},
          {"Pop Hits Vol 3", :pop}
        ] do
      generate(album(title: title, genre: genre, artist_id: artist.id))
    end

    on_exit(fn ->
      Ash.bulk_destroy!(Music.Album, :destroy, %{})
      Ash.bulk_destroy!(Music.Artist, :destroy, %{})
    end)

    :ok
  end

  for {impl, selectors} <- @implementations do
    describe "#{impl}" do
      setup do
        %{
          path: Cinder.TestLive.Fixture.register(album_collection(unquote(impl))),
          s: unquote(Macro.escape(selectors))
        }
      end

      test "loads and displays data", %{conn: conn, path: path} do
        conn
        |> visit(path)
        |> assert_has("td", text: "Dirt")
        |> assert_has("td", text: "Blue Train")
      end

      test "clicking a column header sorts data", %{conn: conn, path: path, s: s} do
        conn
        |> visit(path)
        |> unwrap(fn view ->
          view
          |> Phoenix.LiveViewTest.element(s.sort_title)
          |> Phoenix.LiveViewTest.render_click()
        end)
        |> assert_has(s.first_cell, text: "A Love Supreme")
      end

      test "sort state restores from the URL", %{conn: conn, path: path, s: s} do
        conn
        |> visit(path <> "?sort=title")
        |> assert_has(s.first_cell, text: "A Love Supreme")
      end

      test "typing in a text filter narrows results, and clearing it restores them", %{
        conn: conn,
        path: path
      } do
        conn
        |> visit(path)
        |> fill_in("Title", with: "Dirt")
        |> refute_has("td", text: "Blue Train")
        |> fill_in("Title", with: "")
        |> assert_has("td", text: "Blue Train")
      end

      test "choosing a genre filters to that genre", %{conn: conn, path: path} do
        conn
        |> visit(path)
        |> unwrap(fn view ->
          view
          |> Phoenix.LiveViewTest.form("form", %{filters: %{genre: "rock"}})
          |> Phoenix.LiveViewTest.render_change()
        end)
        |> assert_has("td", text: "Dirt")
        |> refute_has("td", text: "Blue Train")
      end

      test "typing in search narrows results", %{conn: conn, path: path} do
        conn
        |> visit(path)
        |> fill_in("Search", with: "Dirt")
        |> assert_has("td", text: "Dirt")
        |> refute_has("td", text: "Blue Train")
      end

      test "filtering resets to page 1", %{conn: conn, path: path} do
        conn
        |> visit(path <> "?page_size=3&sort=title&page=2")
        |> refute_has("td", text: "A Love Supreme")
        |> fill_in("Title", with: "Love")
        |> assert_has("td", text: "A Love Supreme")
      end

      test "navigating between pages shows different data", %{conn: conn, path: path, s: s} do
        conn
        |> visit(path <> "?page_size=3&sort=title")
        |> assert_has("td", text: "Dirt")
        |> refute_has("td", text: "Facelift")
        |> unwrap(fn view ->
          view |> Phoenix.LiveViewTest.element(s.page_2) |> Phoenix.LiveViewTest.render_click()
        end)
        |> assert_has("td", text: "Facelift")
        |> refute_has("td", text: "Dirt")
      end

      test "combined filter and sort state restores from the URL", %{conn: conn, path: path, s: s} do
        conn
        |> visit(path <> "?sort=title&genre=rock")
        |> refute_has("td", text: "Blue Train")
        |> assert_has(s.first_cell, text: "Dirt")
      end
    end
  end
end
