defmodule Cinder.Next.FilterTypesTest do
  @moduledoc """
  The built-in types beyond text, select, multi and number range, each rendering
  from its view-model, filtering, and surviving the URL.
  """
  use Cinder.ConnCase, async: false

  import Phoenix.ConnTest, only: [get: 2]

  import Phoenix.LiveViewTest,
    only: [
      live: 2,
      render_async: 1,
      render_change: 2,
      render_change: 3,
      element: 2,
      with_target: 2,
      assert_patch: 1
    ]

  setup do
    artist = generate(artist(name: "Types Artist"))

    for {title, genre, released, added, remastered?} <- [
          {"Alpha", :rock, ~D[2020-01-10], ~U[2024-03-01 09:00:00Z], true},
          {"Bravo", :jazz, ~D[2021-06-15], ~U[2024-03-02 09:00:00Z], false},
          {"Charlie", :rock, ~D[2022-11-20], ~U[2024-03-02 18:00:00Z], true},
          {"Delta", :pop, ~D[2023-04-05], ~U[2024-03-03 09:00:00Z], false}
        ] do
      generate(
        album(
          title: title,
          genre: genre,
          release_date: released,
          added_at: added,
          is_remastered: remastered?,
          artist_id: artist.id
        )
      )
    end

    on_exit(fn ->
      Ash.bulk_destroy!(Music.Album, :destroy, %{})
      Ash.bulk_destroy!(Music.Artist, :destroy, %{})
    end)

    :ok
  end

  defp titles(html),
    do:
      Regex.scan(~r/Alpha|Bravo|Charlie|Delta/, html)
      |> List.flatten()
      |> Enum.uniq()
      |> Enum.sort()

  defp mount(conn, query \\ "") do
    path =
      Cinder.TestLive.Fixture.register(fn assigns ->
        ~H"""
        <Cinder.Next.collection id="albums" resource={Music.Album} url_state={@url_state}>
          <:col :let={album} field="title">{album.title}</:col>
          <:filter field="release_date" type="date_range" />
          <:filter field="is_remastered" type="boolean" labels={%{true: "Yes", false: "No"}} />
          <:filter
            field="genre"
            type="radio_group"
            options={[{"Rock", :rock}, {"Jazz", :jazz}, {"Pop", :pop}]}
          />
          <:filter field="added_at" type="date" />
        </Cinder.Next.collection>
        """
      end)

    {:ok, view, _html} = live(conn, path <> query)
    render_async(view)
    view
  end

  defp change(view, filters) do
    view |> element("#albums-filters") |> render_change(%{"filters" => filters})
    render_async(view)
  end

  defp filter_markup(html, field) do
    [markup] =
      Regex.run(~r/<(div|fieldset)[^>]*data-field="#{field}".*?<\/\1>/s, html, capture: :first)

    markup
  end

  test "each type renders its own controls", %{conn: conn} do
    html = render_async(mount(conn))

    range = filter_markup(html, "release_date")
    assert range =~ ~r/<label for="albums-filters-filter-release_date-from"/
    assert range =~ ~r/<input[^>]*name="filters\[release_date_from\]"[^>]*type="date"/
    assert range =~ ~r/<input[^>]*name="filters\[release_date_to\]"[^>]*type="date"/

    # Radio groups are labelled by a legend, with one radio per choice
    boolean = filter_markup(html, "is_remastered")
    assert boolean =~ ~r/^<fieldset.*<legend>Is Remastered<\/legend>/s

    assert boolean =~
             ~r/<input[^>]*name="filters\[is_remastered\]"[^>]*type="radio"[^>]*value="true"[^>]*\/> Yes/

    assert boolean =~ ~r/value="false"[^>]*\/> No/

    genre = filter_markup(html, "genre")
    assert genre =~ ~r/^<fieldset/
    assert length(Regex.scan(~r/type="radio"/, genre)) == 3

    assert filter_markup(html, "added_at") =~
             ~r/<input[^>]*name="filters\[added_at\]"[^>]*type="date"/
  end

  # Each on a fresh mount: `render_change` keeps the form's other values
  test "each type filters", %{conn: conn} do
    for {filters, expected} <- [
          {%{"release_date_from" => "2021-01-01", "release_date_to" => "2022-12-31"},
           ["Bravo", "Charlie"]},
          {%{"is_remastered" => "false"}, ["Bravo", "Delta"]},
          {%{"genre" => "rock"}, ["Alpha", "Charlie"]},
          {%{"added_at" => "2024-03-02"}, ["Bravo", "Charlie"]}
        ] do
      assert titles(change(mount(conn), filters)) == expected, inspect(filters)
    end
  end

  test "values survive the URL, and show as chosen", %{conn: conn} do
    view = mount(conn)

    change(view, %{
      "release_date_from" => "2021-01-01",
      "release_date_to" => "",
      "is_remastered" => "true"
    })

    path = assert_patch(view)
    html = render_async(mount(conn, "?" <> URI.parse(path).query))

    assert titles(html) == ["Charlie"]
    assert html =~ ~r/<input[^>]*name="filters\[release_date_from\]"[^>]*value="2021-01-01"/

    assert html =~
             ~r/<input(?=[^>]*name="filters\[is_remastered\]")(?=[^>]*value="true")[^>]*checked/
  end

  test "a checkbox filters by its value when checked, and not at all when it isn't", %{
    conn: conn
  } do
    path =
      Cinder.TestLive.Fixture.register(fn assigns ->
        ~H"""
        <Cinder.Next.collection id="albums" resource={Music.Album}>
          <:col :let={album} field="title">{album.title}</:col>
          <:filter field="is_remastered" type="checkbox" label="Remastered only" />
        </Cinder.Next.collection>
        """
      end)

    {:ok, view, _html} = live(conn, path)
    html = render_async(view)

    assert html =~ ~r/<label for="albums-filters-filter-is_remastered">Remastered only/

    assert html =~
             ~r/<input(?=[^>]*id="albums-filters-filter-is_remastered")(?=[^>]*type="checkbox")(?=[^>]*value="true")[^>]*>/

    html = change(view, %{"is_remastered" => "true"})
    assert titles(html) == ["Alpha", "Charlie"]
    assert html =~ ~r/<input(?=[^>]*type="checkbox")[^>]*checked/

    # Unchecked, a checkbox posts nothing (`render_change` on the form would keep it checked)
    view |> with_target("#albums") |> render_change("filter", %{"filters" => %{}})
    assert titles(render_async(view)) == ["Alpha", "Bravo", "Charlie", "Delta"]
  end
end
