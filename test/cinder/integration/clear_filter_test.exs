defmodule Cinder.Integration.ClearFilterTest do
  @moduledoc """
  Covers the filter clear buttons through a mounted LiveView.

  Runs with async loading, so a reload shows up as the loading overlay in the
  rendered HTML.
  """
  use Cinder.ConnCase, async: false
  import Phoenix.ConnTest, only: [get: 2]

  import Phoenix.LiveViewTest,
    only: [
      live: 2,
      element: 2,
      render_change: 2,
      render_click: 1,
      render_async: 1,
      has_element?: 2
    ]

  setup {Cinder.TestHelpers, :enable_async_loading}

  @loading_overlay ~s(data-key="loading_overlay_class")
  @release_date_clear ~s([data-cinder-filter="release_date"] > button[data-cinder-clear])

  defp album_collection(assigns) do
    ~H"""
    <Cinder.collection resource={Cinder.Integration.Album} initial_load={:sync}>
      <:col :let={album} field="title" filter>{album.title}</:col>
      <:col :let={album} field="release_date" filter>{album.release_date}</:col>
    </Cinder.collection>
    """
  end

  setup do
    artist = generate(artist(name: "Clear Artist"))
    generate(album(title: "Clear Album", release_date: ~D[2020-05-01], artist_id: artist.id))

    on_exit(fn ->
      Ash.bulk_destroy!(Cinder.Integration.Album, :destroy, %{})
      Ash.bulk_destroy!(Cinder.Integration.Artist, :destroy, %{})
    end)

    %{path: Cinder.TestLive.Fixture.register(&album_collection/1)}
  end

  test "renders the partial input hook around the filters", %{conn: conn, path: path} do
    {:ok, view, _html} = live(conn, path)

    assert has_element?(
             view,
             ~s([phx-hook="Cinder.FilterManager.PartialInputs"] #{@release_date_clear})
           )
  end

  test "clearing filters that hold no value skips the reload", %{conn: conn, path: path} do
    {:ok, view, _html} = live(conn, path)

    # The browser reports a partially entered date as empty, so the server has nothing to clear
    refute view |> element(@release_date_clear) |> render_click() =~ @loading_overlay

    refute view |> element(~s(button[phx-click="clear_all_filters"])) |> render_click() =~
             @loading_overlay
  end

  test "clearing a filter that holds a value triggers a reload", %{conn: conn, path: path} do
    {:ok, view, _html} = live(conn, path)

    view
    |> element("form[phx-change=filter_change]")
    |> render_change(%{"filters" => %{"release_date_from" => "2020-01-01"}})

    render_async(view)

    assert view |> element(@release_date_clear) |> render_click() =~ @loading_overlay
  end
end
