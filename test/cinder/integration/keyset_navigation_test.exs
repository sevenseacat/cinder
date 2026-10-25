defmodule Cinder.Integration.KeysetNavigationTest do
  @moduledoc """
  Clicking through a keyset-paginated collection. With no `default_page_type`
  configured (as in the test app), Ash returns the first page as an
  `Ash.Page.Offset`, so the cursors for "Next page" have to come from its
  records' keyset metadata.
  """
  use Cinder.ConnCase, async: false

  import Phoenix.ConnTest, only: [get: 2]
  import Phoenix.LiveViewTest, only: [live: 2, render_async: 1, render_click: 1, element: 2]

  setup do
    artist = generate(artist(name: "Keyset Artist"))

    for title <- ["Alpha", "Bravo", "Charlie", "Delta", "Echo"] do
      generate(album(title: title, artist_id: artist.id))
    end

    on_exit(fn ->
      Ash.bulk_destroy!(Music.Album, :destroy, %{})
      Ash.bulk_destroy!(Music.Artist, :destroy, %{})
    end)

    :ok
  end

  defp collection(url_synced?) do
    query = Music.Album |> Ash.Query.for_read(:paginated) |> Ash.Query.sort(:title)

    fn assigns ->
      assigns = assign(assigns, query: query, url_synced?: url_synced?)

      ~H"""
      <Cinder.collection
        query={@query}
        url_state={@url_synced? && @url_state}
        pagination={[mode: :keyset]}
        page_size={2}
      >
        <:col :let={album} field="title">{album.title}</:col>
      </Cinder.collection>
      """
    end
  end

  defp titles(html) do
    Regex.scan(~r/Alpha|Bravo|Charlie|Delta|Echo/, html) |> List.flatten()
  end

  defp click(view, title) do
    view |> element(~s(button[title="#{title}"])) |> render_click()
    render_async(view)
  end

  for url_synced? <- [false, true] do
    test "next and previous page move through the records (url synced: #{url_synced?})", %{
      conn: conn
    } do
      path = Cinder.TestLive.Fixture.register(collection(unquote(url_synced?)))
      {:ok, view, _html} = live(conn, path)

      assert titles(render_async(view)) == ["Alpha", "Bravo"]
      assert titles(click(view, "Next page")) == ["Charlie", "Delta"]
      assert titles(click(view, "Previous page")) == ["Alpha", "Bravo"]
    end
  end
end
