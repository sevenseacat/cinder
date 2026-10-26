defmodule Cinder.Integration.UrlSyncOnMountTest do
  @moduledoc """
  `on_mount Cinder.UrlSync` (or `use Cinder.UrlSync`) on its own syncs a collection with
  the URL, whether or not the LiveView has its own `handle_params/3` and `handle_info/2`.
  """
  use Cinder.ConnCase, async: false

  import Phoenix.ConnTest, only: [get: 2]

  import Phoenix.LiveViewTest,
    only: [live: 2, element: 2, render: 1, render_click: 1, assert_patch: 1]

  setup do
    artist = generate(artist(name: "Sync Artist"))

    for title <- ["Banana", "Apple", "Cherry"] do
      generate(album(title: title, artist_id: artist.id))
    end

    on_exit(fn ->
      Ash.bulk_destroy!(Music.Album, :destroy, %{})
      Ash.bulk_destroy!(Music.Artist, :destroy, %{})
    end)

    path =
      Cinder.TestLive.Fixture.register(fn assigns ->
        ~H"""
        <p id="tab">{assigns[:tab]}</p>
        <Cinder.collection resource={Music.Album} url_state={@url_state}>
          <:col :let={album} field="title" sort>{album.title}</:col>
        </Cinder.collection>
        """
      end)

    %{id: String.replace_prefix(path, "/c/", "")}
  end

  defp first_title(view) do
    [_, title] = Regex.run(~r/<td[^>]*>\s*([A-Za-z]+)/, render(view))
    title
  end

  defp sort_by_title(view) do
    view |> element("[phx-click=toggle_sort][phx-value-key=title]") |> render_click()
    assert_patch(view)
  end

  # `/n`: `on_mount Cinder.UrlSync` alone. `/h`: `use Cinder.UrlSync` behind another
  # hook that halts when there's no `handle_params/3` (it broke the dev app's pages)
  test "a LiveView without handle_params/3 applies the URL and follows sorting", %{
    conn: conn,
    id: id
  } do
    for prefix <- ["/n", "/h"] do
      {:ok, view, _html} = live(conn, "#{prefix}/#{id}?sort=title")
      assert first_title(view) == "Apple", prefix

      assert sort_by_title(view) =~ "sort=-title"
      assert first_title(view) == "Cherry", prefix
    end
  end

  test "a LiveView's own handle_params/3 and handle_info/2 still run", %{conn: conn, id: id} do
    {:ok, view, _html} = live(conn, "/o/#{id}?tab=albums&sort=title")
    assert first_title(view) == "Apple"
    assert view |> element("#tab") |> render() =~ "albums"

    # The custom param survives the collection's patch
    assert sort_by_title(view) =~ "tab=albums"
    assert first_title(view) == "Cherry"

    send(view.pid, {:ping, self()})
    assert_receive :pong
  end

  test "use Cinder.UrlSync before use Phoenix.LiveView is a compile error naming the fix" do
    error =
      assert_raise CompileError, fn ->
        Code.compile_string("""
        defmodule Cinder.Integration.UrlSyncOnMountTest.WrongOrder do
          use Cinder.UrlSync
          use Phoenix.LiveView

          def render(assigns), do: ~H""
        end
        """)
      end

    assert Exception.message(error) =~ "use Cinder.UrlSync"
    assert Exception.message(error) =~ "after"
  end
end
