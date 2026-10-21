defmodule Cinder.Next.LayoutsTest do
  @moduledoc "Region slots, custom layouts and component attrs on a mounted `Cinder.Next.collection`."
  use Cinder.ConnCase, async: false

  import Phoenix.ConnTest, only: [get: 2]

  import Phoenix.LiveViewTest,
    only: [
      live: 2,
      render_async: 1,
      render_change: 2,
      render_click: 1,
      element: 2,
      assert_patch: 1
    ]

  setup do
    artist = generate(artist(name: "Layout Artist"))

    for {title, genre} <- [
          {"Alpha", :rock},
          {"Bravo", :jazz},
          {"Charlie", :rock},
          {"Delta", :jazz},
          {"Echo", :pop}
        ] do
      generate(album(title: title, genre: genre, artist_id: artist.id))
    end

    on_exit(fn ->
      Ash.bulk_destroy!(Music.Album, :destroy, %{})
      Ash.bulk_destroy!(Music.Artist, :destroy, %{})
    end)

    :ok
  end

  defp titles(html), do: Regex.scan(~r/Alpha|Bravo|Charlie|Delta|Echo/, html) |> List.flatten()

  defp mount(conn, render_fun, query \\ "") do
    {:ok, view, _html} = live(conn, Cinder.TestLive.Fixture.register(render_fun) <> query)
    render_async(view)
    view
  end

  defp change(view, params) do
    view |> element("#albums-filters") |> render_change(params)
    render_async(view)
  end

  test "a :toolbar slot replaces only that region: a heading beside the search box", %{conn: conn} do
    view =
      mount(conn, fn assigns ->
        ~H"""
        <Cinder.Next.collection id="albums" resource={Music.Album} page_size={5}>
          <:col :let={album} field="title" search sort>{album.title}</:col>
          <:toolbar :let={c}>
            <div id="section-header">
              <h2>Albums</h2>
              <Cinder.Next.search search={c.search} />
            </div>
          </:toolbar>
        </Cinder.Next.collection>
        """
      end)

    html = render_async(view)
    assert html =~ ~r/id="section-header".*<h2>Albums<\/h2>.*name="search"/s
    # The rest of the default layout is still there
    assert html =~ ~s(data-part="table")

    assert titles(change(view, %{"search" => "echo"})) == ["Echo"]
  end

  defp sidebar_layout(url_synced?) do
    fn assigns ->
      assigns = assign(assigns, :url_synced?, url_synced?)

      ~H"""
      <Cinder.Next.collection
        id="albums"
        resource={Music.Album}
        layout="custom"
        url_state={@url_synced? && @url_state}
        page_size={2}
        :let={c}
      >
        <:col :let={album} field="title" sort search>{album.title}</:col>
        <:filter field="genre" />

        <form {c.form_attrs} class="sidebar">
          <Cinder.Next.filter :for={f <- c.filters} filter={f} />
        </form>
        <%!-- Outside the form, joining it through `form=` --%>
        <Cinder.Next.search search={c.search} />
        <main>
          <Cinder.Next.pagination collection={c} id="top-pagination" />
          <Cinder.Next.table collection={c} />
          <Cinder.Next.pagination collection={c} id="bottom-pagination" />
        </main>
      </Cinder.Next.collection>
      """
    end
  end

  test "a custom layout puts filters in a sidebar and pagination top and bottom", %{conn: conn} do
    view = mount(conn, sidebar_layout(false))
    html = render_async(view)

    # The layout places the form: filters inside it, search outside it through `form=`
    assert html =~ ~r/<form[^>]*id="albums-filters"[^>]*>.*name="filters\[genre\]".*<\/form>/s

    assert html =~
             ~r/<\/form>.*name="search"[^>]*form="albums-filters"|<\/form>.*form="albums-filters"[^>]*name="search"/s

    assert length(Regex.scan(~r/data-part="pagination"/, html)) == 2

    view |> element(~s(#top-pagination [data-kind="next"])) |> render_click()
    html = render_async(view)
    assert html =~ ~r/id="bottom-pagination".*aria-current="page"[^>]*>2</s

    assert Enum.sort(titles(change(view, %{"filters" => %{"genre" => "jazz"}}))) ==
             ["Bravo", "Delta"]
  end

  # Feature 006 crashed after push_patch when slots reached the LiveComponent as
  # top-level assigns. The inner block travels inside the config instead.
  test "a URL-synced custom layout survives repeated patches", %{conn: conn} do
    view = mount(conn, sidebar_layout(true))

    change(view, %{"filters" => %{"genre" => "rock"}})
    assert assert_patch(view) =~ "genre=rock"

    view |> element(~s(th [data-part="sort"])) |> render_click()
    assert assert_patch(view) =~ "sort=title"

    change(view, %{"filters" => %{"genre" => ""}})
    assert_patch(view)

    view |> element(~s(#bottom-pagination [data-kind="next"])) |> render_click()
    assert assert_patch(view) =~ "page=2"

    assert titles(render_async(view)) == ["Charlie", "Delta"]
  end

  test "components take a class and attributes, but keep the ones Cinder depends on", %{
    conn: conn
  } do
    view =
      mount(conn, fn assigns ->
        ~H"""
        <Cinder.Next.collection id="albums" resource={Music.Album} layout="custom" :let={c}>
          <:col :let={album} field="title">{album.title}</:col>
          <Cinder.Next.table collection={c} class="striped" data-density="compact" data-part="nope" />
        </Cinder.Next.collection>
        """
      end)

    [table] = Regex.run(~r/<table[^>]*>/, render_async(view))

    assert table =~ ~s(class="striped")
    assert table =~ ~s(data-density="compact")
    assert table =~ ~s(data-part="table")
  end

  # Regression: a :pagination slot rendered while there was no page yet (still
  # loading, or the load failed) crashed reading fields off a nil pagination
  @tag :capture_log
  test "a :pagination slot isn't rendered while there's no pagination to show", %{conn: conn} do
    view =
      mount(conn, fn assigns ->
        ~H"""
        <Cinder.Next.collection id="albums" resource={Music.Album} action={:failing}>
          <:col :let={album} field="title">{album.title}</:col>
          <:pagination :let={c}>
            <span id="custom-pagination">Page {c.pagination.page}</span>
          </:pagination>
        </Cinder.Next.collection>
        """
      end)

    html = render_async(view)

    assert html =~ ~s(data-part="error")
    refute html =~ "custom-pagination"
  end
end
