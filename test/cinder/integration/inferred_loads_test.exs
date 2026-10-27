defmodule Cinder.Integration.InferredLoadsTest do
  @moduledoc """
  A collection loads what its columns' fields need (relationships, calculations,
  aggregates) without `query_opts`, alongside any loads it's given.
  """
  use Cinder.ConnCase, async: false

  setup do
    artist = generate(artist(name: "Alice In Chains"))
    generate(album(title: "Dirt", artist_id: artist.id))

    on_exit(fn ->
      Ash.bulk_destroy!(Music.Album, :destroy, %{})
      Ash.bulk_destroy!(Music.Artist, :destroy, %{})
    end)
  end

  defp visit_collection(conn, render) do
    visit(conn, Cinder.TestLive.Fixture.register(render))
  end

  test "column fields load with no query_opts", %{conn: conn} do
    conn
    |> visit_collection(fn assigns ->
      ~H"""
      <Cinder.collection resource={Music.Album}>
        <:col :let={album} field="title_lower">[{album.title_lower}]</:col>
        <:col :let={album} field="artist.name">[{album.artist.name}]</:col>
        <:col :let={album} field="artist.album_count">[{album.artist.album_count}]</:col>
      </Cinder.collection>
      """
    end)
    |> assert_has("td", text: "[dirt]")
    |> assert_has("td", text: "[Alice In Chains]")
    |> assert_has("td", text: "[1]")
  end

  test "explicit loads, and a query's own loads, are kept alongside", %{conn: conn} do
    conn
    |> visit_collection(fn assigns ->
      ~H"""
      <Cinder.collection
        query={Ash.Query.load(Music.Album, :title_lower)}
        query_opts={[load: [artist: [:name_lower]]]}
      >
        <:col :let={album} field="artist.album_count">
          [{album.title_lower}|{album.artist.name_lower}|{album.artist.album_count}]
        </:col>
      </Cinder.collection>
      """
    end)
    |> assert_has("td", text: "[dirt|alice in chains|1]")
  end

  test "a relationship loaded with a query keeps it, from query_opts or the collection's query",
       %{conn: conn} do
    artist_query = Ash.Query.load(Music.Artist, :name_lower)

    in_query_opts = fn assigns ->
      assigns = assign(assigns, :artist_query, artist_query)

      ~H"""
      <Cinder.collection resource={Music.Album} query_opts={[load: [artist: @artist_query]]}>
        <:col :let={album} field="artist.album_count">
          [{album.artist.name_lower}|{album.artist.album_count}]
        </:col>
      </Cinder.collection>
      """
    end

    in_query = fn assigns ->
      assigns = assign(assigns, :query, Ash.Query.load(Music.Album, artist: artist_query))

      ~H"""
      <Cinder.collection query={@query}>
        <:col :let={album} field="artist.album_count">
          [{album.artist.name_lower}|{album.artist.album_count}]
        </:col>
      </Cinder.collection>
      """
    end

    for render <- [in_query_opts, in_query] do
      conn
      |> visit_collection(render)
      |> assert_has("td", text: "[alice in chains|1]")
    end
  end

  test "a filter-only slot's field isn't loaded", %{conn: conn} do
    conn
    |> visit_collection(fn assigns ->
      ~H"""
      <Cinder.collection resource={Music.Album}>
        <:col :let={album} field="title">[{Ash.Resource.loaded?(album, :artist)}]</:col>
        <:filter field="artist.name" />
      </Cinder.collection>
      """
    end)
    |> assert_has("td", text: "[false]")
  end
end
