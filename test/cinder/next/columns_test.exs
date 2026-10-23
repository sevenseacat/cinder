defmodule Cinder.Next.ColumnsTest do
  @moduledoc "Choosing and reordering a table's columns, in a component and in a LiveView."
  use Cinder.ConnCase, async: false

  import Phoenix.ConnTest, only: [get: 2]

  import Phoenix.LiveViewTest,
    only: [live: 2, render_async: 1, render_click: 1, element: 2, refute_patched: 1]

  setup do
    artist = generate(artist(name: "Columns Artist"))
    generate(album(title: "Alpha", genre: :rock, track_count: 9, artist_id: artist.id))

    on_exit(fn ->
      Ash.bulk_destroy!(Music.Album, :destroy, %{})
      Ash.bulk_destroy!(Music.Artist, :destroy, %{})
    end)

    :ok
  end

  defp headers(html) do
    [thead] = Regex.run(~r/<thead>.*<\/thead>/s, html)

    Regex.scan(~r/data-field="([^"]+)"/, thead, capture: :all_but_first)
    |> List.flatten()
  end

  defp mount(conn, prefs \\ nil) do
    test = self()

    path =
      Cinder.TestLive.Fixture.register(fn assigns ->
        assigns = assign(assigns, prefs: prefs, test: test)

        ~H"""
        <Cinder.Next.collection
          id="albums"
          resource={Music.Album}
          url_state={@url_state}
          reorderable
          column_prefs={@prefs}
          on_columns_change={&send(@test, {:columns, &1})}
        >
          <:col :let={album} field="title">{album.title}</:col>
          <:col :let={album} field="genre">{album.genre}</:col>
          <:col :let={album} field="track_count" label="Tracks" hidden>{album.track_count}</:col>
        </Cinder.Next.collection>
        """
      end)

    {:ok, view, _html} = live(conn, path)
    render_async(view)
    view
  end

  test "a hidden column is offered, not shown, until it's chosen", %{conn: conn} do
    view = mount(conn)
    html = render_async(view)

    assert headers(html) == ["title", "genre"]
    refute html =~ "<td class=\"cinder-cell\" data-field=\"track_count\""

    # The control: a popover of the table's columns, above it
    assert html =~ ~r/<caption class="cinder-table-caption">.*>Columns<\/button>/s

    assert html =~
             ~r/<input(?=[^>]*id="albums-filters-columns-2")(?=[^>]*type="checkbox")[^>]*>\s*Tracks/

    refute html =~ ~r/<input(?=[^>]*id="albums-filters-columns-2")[^>]*checked/

    html = view |> element("#albums-filters-columns-2") |> render_click()

    assert headers(html) == ["title", "genre", "track_count"]
    assert html =~ ~r/data-field="track_count">\s*9/
    assert_received {:columns, %{order: nil, visible: %{"track_count" => true}}}
  end

  test "moving a column reorders the table, without loading or touching the URL", %{conn: conn} do
    view = mount(conn)

    html = view |> element(~s(button[aria-label="Move Genre up"])) |> render_click()

    assert headers(html) == ["genre", "title"]

    assert html =~
             ~r/<td class="cinder-cell" data-field="genre">.*<td class="cinder-cell" data-field="title">/s

    assert_received {:columns, %{order: ["genre", "title", "track_count"]}}
    refute_patched(view)
  end

  test "saved choices are where it starts", %{conn: conn} do
    html =
      render_async(
        mount(conn, %{order: ["track_count"], visible: %{"track_count" => true, "genre" => false}})
      )

    assert headers(html) == ["track_count", "title"]
  end

  test "in a LiveView, the table's own columns are the ones chosen from", %{conn: conn} do
    path =
      Cinder.TestLive.NextFixture.register(
        &Cinder.Next.LiveView.assign_collection(&1, :albums, Music.Album, reorderable: true),
        fn assigns ->
          ~H"""
          <Cinder.Next.table collection={@albums}>
            <:col :let={album} field="title">{album.title}</:col>
            <:col :let={album} field="genre" hidden>{album.genre}</:col>
          </Cinder.Next.table>
          """
        end
      )

    {:ok, view, _html} = live(conn, path)
    assert headers(render_async(view)) == ["title"]

    html = view |> element(~s(input[phx-value-field="genre"])) |> render_click()
    assert headers(html) == ["title", "genre"]
    assert html =~ ~s(phx-click="cinder:albums:set_column")
  end

  test "without `reorderable`, there's no control", %{conn: conn} do
    path =
      Cinder.TestLive.Fixture.register(fn assigns ->
        ~H"""
        <Cinder.Next.collection id="albums" resource={Music.Album}>
          <:col :let={album} field="title">{album.title}</:col>
          <:col :let={album} field="genre" hidden>{album.genre}</:col>
        </Cinder.Next.collection>
        """
      end)

    {:ok, view, _html} = live(conn, path)
    html = render_async(view)

    refute html =~ "cinder-table-caption"
    assert headers(html) == ["title"]
  end
end
