defmodule Cinder.Next.RowActionsTest do
  @moduledoc "`<:row_action>`: per-row buttons and links, in each table row's last cell."
  use Cinder.ConnCase, async: false

  import Phoenix.ConnTest, only: [get: 2]
  import Phoenix.LiveViewTest, only: [live: 2, render_async: 1]

  setup do
    artist = generate(artist(name: "Actions Artist"))
    generate(album(title: "Alpha", artist_id: artist.id))
    generate(album(title: "Bravo", artist_id: artist.id))

    on_exit(fn ->
      Ash.bulk_destroy!(Music.Album, :destroy, %{})
      Ash.bulk_destroy!(Music.Artist, :destroy, %{})
    end)

    :ok
  end

  test "each row's actions sit in its last cell, under a header only screen readers see", %{
    conn: conn
  } do
    path =
      Cinder.TestLive.Fixture.register(fn assigns ->
        ~H"""
        <Cinder.Next.collection id="albums" resource={Music.Album} reorderable>
          <:col :let={album} field="title">{album.title}</:col>
          <:row_action :let={album}><a href={"/albums/#{album.title}"}>View</a></:row_action>
          <:row_action :let={album}><button phx-click="delete" phx-value-title={album.title}>Delete</button></:row_action>
        </Cinder.Next.collection>
        """
      end)

    {:ok, view, _html} = live(conn, path)
    html = render_async(view)

    assert html =~
             ~r/<th class="cinder-actions-cell"><span class="cinder-sr-only">Actions<\/span><\/th>\s*<\/tr>\s*<\/thead>/

    # Every action, in the last cell of its own row
    assert html =~
             ~r/Alpha\s*<\/td><td class="cinder-actions-cell"><a href="\/albums\/Alpha">View<\/a><button[^>]*phx-value-title="Alpha"[^>]*>Delete<\/button><\/td><\/tr>/

    # Not a column of data: the columns control doesn't offer it
    [panel] = Regex.run(~r/<div[^>]*popover="auto".*?<\/div>\s*<\/div>/s, html)
    refute panel =~ "Actions"
  end

  test "a table in a LiveView takes its own, and they widen the full-width cells", %{conn: conn} do
    path =
      Cinder.TestLive.NextFixture.register(
        &Cinder.Next.LiveView.assign_collection(&1, :albums, Music.Album, query: no_albums()),
        fn assigns ->
          ~H"""
          <Cinder.Next.table collection={@albums}>
            <:col :let={album} field="title">{album.title}</:col>
            <:row_action :let={album}><a href="#">Edit {album.title}</a></:row_action>
          </Cinder.Next.table>
          """
        end
      )

    {:ok, view, _html} = live(conn, path)

    # The empty row spans the title column and the actions cell
    assert render_async(view) =~ ~r/<td colspan="2">\s*No results found/
  end

  defp no_albums do
    require Ash.Query
    Ash.Query.filter(Music.Album, title == "Nothing")
  end
end
