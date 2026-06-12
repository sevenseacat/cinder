defmodule Cinder.Integration.DefaultFilterTest do
  @moduledoc """
  End-to-end coverage for the `default:` filter option wiring in
  `Cinder.LiveComponent`.

  These mount a real LiveView whose `release_date` column declares a default
  date filter, then assert that the default is:

    * seeded on initial mount,
    * not allowed to override state restored from the URL, and
    * re-applied when the user clears filters.

  The pure seeding logic lives in `Cinder.FilterManager.apply_defaults/2` and is
  unit-tested separately; this exercises the component plumbing around it.
  """
  use Cinder.ConnCase, async: false

  @default_date ~D[2020-01-01]

  # A collection whose date column defaults to @default_date.
  defp dated_collection(assigns) do
    ~H"""
    <Cinder.collection resource={Cinder.Integration.Album} url_state={@url_state}>
      <:col :let={album} field="title" sort>{album.title}</:col>
      <:col :let={album} field="release_date" filter={[type: :date, default: ~D[2020-01-01]]}>
        {to_string(album.release_date)}
      </:col>
    </Cinder.collection>
    """
  end

  setup do
    artist = generate(artist(name: "Test Artist"))

    on_default =
      generate(album(title: "On Default", release_date: @default_date, artist_id: artist.id))

    before_default =
      generate(album(title: "Before Default", release_date: ~D[2019-06-15], artist_id: artist.id))

    after_default =
      generate(album(title: "After Default", release_date: ~D[2021-03-20], artist_id: artist.id))

    on_exit(fn ->
      Ash.bulk_destroy!(Cinder.Integration.Album, :destroy, %{})
      Ash.bulk_destroy!(Cinder.Integration.Artist, :destroy, %{})
    end)

    %{
      path: Cinder.TestLive.Fixture.register(&dated_collection/1),
      on_default: on_default,
      before_default: before_default,
      after_default: after_default
    }
  end

  test "the default filter is seeded on initial mount", %{conn: conn, path: path} do
    conn
    |> visit(path)
    |> assert_has("td", text: "On Default")
    |> refute_has("td", text: "Before Default")
    |> refute_has("td", text: "After Default")
  end

  test "state restored from the URL takes precedence over the default", %{conn: conn, path: path} do
    conn
    |> visit(path <> "?release_date=2019-06-15")
    |> assert_has("td", text: "Before Default")
    |> refute_has("td", text: "On Default")
    |> refute_has("td", text: "After Default")
  end

  test "clearing all filters re-applies the default", %{conn: conn, path: path} do
    conn
    # Start from a non-default date restored from the URL...
    |> visit(path <> "?release_date=2021-03-20")
    |> assert_has("td", text: "After Default")
    |> refute_has("td", text: "On Default")
    # ...then clear all filters and confirm the default comes back rather than
    # showing every row.
    |> unwrap(fn view ->
      view
      |> Phoenix.LiveViewTest.element("[phx-click=clear_all_filters]")
      |> Phoenix.LiveViewTest.render_click()
    end)
    |> assert_has("td", text: "On Default")
    |> refute_has("td", text: "After Default")
    |> refute_has("td", text: "Before Default")
  end
end
