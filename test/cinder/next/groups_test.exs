defmodule Cinder.Next.GroupsTest do
  @moduledoc "Grouping a mounted `Cinder.Next.collection`'s rows, as 7CC-129 designs it."
  use Cinder.ConnCase, async: false

  import Phoenix.ConnTest, only: [get: 2]

  import Phoenix.LiveViewTest,
    only: [live: 2, render_async: 1, render_click: 1, element: 2, assert_patch: 1]

  setup do
    artist = generate(artist(name: "Groups Artist"))

    for {title, genre} <- [
          {"Delta", :jazz},
          {"Charlie", :rock},
          {"Echo", :pop},
          {"Bravo", :jazz},
          {"Alpha", :rock}
        ] do
      generate(album(title: title, genre: genre, artist_id: artist.id))
    end

    on_exit(fn ->
      Ash.bulk_destroy!(Music.Album, :destroy, %{})
      Ash.bulk_destroy!(Music.Artist, :destroy, %{})
    end)

    :ok
  end

  defp mount(conn, opts \\ []) do
    assigns_opts = Map.new(opts)

    path =
      Cinder.TestLive.Fixture.register(fn assigns ->
        assigns = assign(assigns, assigns_opts)

        ~H"""
        <Cinder.Next.collection
          id="albums"
          resource={Music.Album}
          page_size={assigns[:page_size] || 10}
          url_state={assigns[:url] && @url_state}
        >
          <:col :let={album} field="title" sort>{album.title}</:col>
          <:group :let={group} field="genre" sort={assigns[:group_sort] || :asc}>
            {group.value} ({length(group.items)})
          </:group>
        </Cinder.Next.collection>
        """
      end)

    {:ok, view, _html} = live(conn, path)
    render_async(view)
    {view, path}
  end

  # [{"jazz (2)", ["Bravo", "Delta"]}, ...], from the rendered groups
  defp groups(html) do
    ~r/class="cinder-group-label"[^>]*>\s*(\w+ \(\d+\))\s*<\/span>(.*?)(?=class="cinder-group-label"|<\/table>)/s
    |> Regex.scan(html, capture: :all_but_first)
    |> Enum.map(fn [label, rest] ->
      {label, Regex.scan(~r/Alpha|Bravo|Charlie|Delta|Echo/, rest) |> List.flatten()}
    end)
  end

  test "groups each page's rows under headers, kept together by the group sort", %{conn: conn} do
    {view, _path} = mount(conn)

    assert [{"jazz (2)", jazz}, {"pop (1)", ["Echo"]}, {"rock (2)", rock}] =
             groups(render_async(view))

    assert Enum.sort(jazz) == ["Bravo", "Delta"]
    assert Enum.sort(rock) == ["Alpha", "Charlie"]
  end

  test "the user's sorts apply within groups, and the group sort stays out of the URL", %{
    conn: conn
  } do
    {view, _path} = mount(conn, url: true)

    view |> element(~s(.cinder-sort[phx-value-field="title"])) |> render_click()
    patched = assert_patch(view)

    assert patched =~ "sort=title"
    refute patched =~ "genre"

    assert groups(render_async(view)) == [
             {"jazz (2)", ["Bravo", "Delta"]},
             {"pop (1)", ["Echo"]},
             {"rock (2)", ["Alpha", "Charlie"]}
           ]
  end

  test "groups can run in descending order", %{conn: conn} do
    {view, _path} = mount(conn, group_sort: :desc)

    assert Enum.map(groups(render_async(view)), &elem(&1, 0)) == [
             "rock (2)",
             "pop (1)",
             "jazz (2)"
           ]
  end

  test "a group split across pages keeps its ids, so it stays collapsed if it was", %{conn: conn} do
    {view, _path} = mount(conn, page_size: 4)
    page_1 = render_async(view)

    view |> element(~s(.cinder-page[data-kind="next"])) |> render_click()
    page_2 = render_async(view)

    # rock spans both pages: its header repeats, with the same ids
    [rock_id] =
      Regex.run(~r/<tbody(?=[^>]*data-value="rock")[^>]*\sid="(albums-group-\d+)"/, page_1,
        capture: :all_but_first
      )

    assert page_2 =~ ~s(id="#{rock_id}")
    assert page_2 =~ ~s(aria-controls="#{rock_id}-items")
  end
end
