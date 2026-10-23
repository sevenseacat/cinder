defmodule Cinder.Next.DslTest do
  @moduledoc "A collection declared in a module with `Cinder.Next.Dsl`, kept in a LiveView."
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

  require Ash.Query

  setup do
    artist = generate(artist(name: "DSL Artist"))

    for {title, genre} <- [
          {"Alpha", :rock},
          {"Bravo", :jazz},
          {"Charlie", :rock},
          {"Delta", :pop}
        ] do
      generate(album(title: title, genre: genre, artist_id: artist.id))
    end

    on_exit(fn ->
      Ash.bulk_destroy!(Music.Album, :destroy, %{})
      Ash.bulk_destroy!(Music.Artist, :destroy, %{})
    end)

    :ok
  end

  defp titles(html),
    do: Regex.scan(~r/<h3>(\w+)<\/h3>/, html, capture: :all_but_first) |> List.flatten()

  defp mount(conn, opts) do
    path =
      Cinder.TestLive.NextFixture.register(
        &Cinder.Next.LiveView.assign_collection(&1, :albums, Cinder.TestCollections.Albums, opts),
        fn assigns ->
          ~H"""
          <form {@albums.form_attrs}>
            <Cinder.Next.filter :for={f <- @albums.filters} filter={f} />
          </form>
          <Cinder.Next.table collection={@albums}>
            <:col :let={album} field="title"><h3>{album.title}</h3></:col>
          </Cinder.Next.table>
          """
        end
      )

    {:ok, view, _html} = live(conn, path)
    render_async(view)
    view
  end

  test "behaves like the same collection declared in a keyword list", %{conn: conn} do
    view = mount(conn, url: true)
    html = render_async(view)

    # Its page size, its filters in order (with their options), its sorts
    assert length(titles(html)) == 2
    assert html =~ ~r/name="filters\[genre\]".*>Any genre<.*>Tracks</s
    assert html =~ ~s(class="cinder-table-caption")

    view |> element("#albums-filters") |> render_change(%{"filters" => %{"genre" => "rock"}})
    assert assert_patch(view) =~ "genre=rock"
    assert Enum.sort(titles(render_async(view))) == ["Alpha", "Charlie"]

    view |> element(~s(th .cinder-sort)) |> render_click()
    assert assert_patch(view) =~ "sort=title"
  end

  test "what the page gives overrides what's declared, including the query", %{conn: conn} do
    rock = Ash.Query.filter(Music.Album, genre == :rock)
    html = render_async(mount(conn, page_size: 3, query: rock))

    assert Enum.sort(titles(html)) == ["Alpha", "Charlie"]
  end

  test "its declarations are assign_collection's options" do
    assert [
             resource: Music.Album,
             page_size: 2,
             search: [fields: ["title"]],
             reorderable: true,
             filters: [
               genre: [type: :select, prompt: "Any genre"],
               track_count: [label: "Tracks", type: :number_range]
             ],
             arguments: [],
             sorts: [title: [], release_date: [label: "Released"]],
             bulk_actions: [remaster: [action: :remaster]]
           ] = Cinder.Next.Dsl.options(Cinder.TestCollections.Albums)
  end

  describe "mistakes are compile errors" do
    defp compile(body) do
      Code.compile_string("""
      defmodule Cinder.Next.DslTest.Bad#{System.unique_integer([:positive])} do
        use Cinder.Next.Dsl

        collection do
          resource Music.Album
          #{body}
        end
      end
      """)
    end

    test "an option of the wrong shape, from the shared schemas" do
      assert_raise Spark.Error.DslError, ~r/unknown filter type :selectt/, fn ->
        compile("filters do\n filter :genre, :selectt\n end")
      end
    end

    test "a declaration that doesn't fit the resource, from building the collection" do
      assert_raise Spark.Error.DslError, ~r/:read action has no argument "max_tracks"/, fn ->
        compile("action :read\n arguments do\n argument :max_tracks\n end")
      end
    end
  end
end
