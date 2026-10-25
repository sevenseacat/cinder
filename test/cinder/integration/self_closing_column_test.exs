defmodule Cinder.Integration.SelfClosingColumnTest do
  @moduledoc """
  A `<:col field="..." />` with no content renders its field's value in a table, in
  every field notation a column accepts.
  """
  use Cinder.ConnCase, async: false

  setup do
    artist = generate(artist(name: "Column Artist"))

    generate(
      album(
        title: "Aaa",
        genre: :jazz,
        price: Decimal.new("12.50"),
        release_date: ~D[1999-05-04],
        details: %Music.AlbumDetails{label: "Blue Note", catalog_number: "BN-1"},
        artist_id: artist.id
      )
    )

    on_exit(fn ->
      Ash.bulk_destroy!(Music.Album, :destroy, %{})
      Ash.bulk_destroy!(Music.Artist, :destroy, %{})
    end)

    :ok
  end

  # Regression: a column with no content crashed the table (`expected a function,
  # got: nil`), because the renderer never used the field-value fallback
  test "renders direct, relationship and embedded fields, and non-string values as text", %{
    conn: conn
  } do
    path =
      Cinder.TestLive.Fixture.register(fn assigns ->
        ~H"""
        <Cinder.collection resource={Music.Album} query_opts={[load: [:artist]]}>
          <:col field="title" sort />
          <:col field="artist.name" />
          <:col field="details__label" />
          <:col field="release_date" />
          <:col field="price" />
          <:col field="genre" />
          <:col :let={album} field="track_count" label="Tracks">{album.track_count} tracks</:col>
        </Cinder.collection>
        """
      end)

    conn
    |> visit(path)
    |> assert_has("td", text: "Aaa")
    |> assert_has("td", text: "Column Artist")
    |> assert_has("td", text: "Blue Note")
    |> assert_has("td", text: "1999-05-04")
    |> assert_has("td", text: "12.50")
    |> assert_has("td", text: "jazz")
    # A column with content renders that, as before
    |> assert_has("td", text: "10 tracks")
  end
end
