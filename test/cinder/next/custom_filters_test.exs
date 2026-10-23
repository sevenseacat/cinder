defmodule Cinder.Next.CustomFiltersTest do
  @moduledoc """
  Custom filter types in the new shell: registered in config, processed and
  queried by the engine unchanged, rendered from the view-model by their own
  `view/2` and `control/1` (or as a plain input without them), with their own
  options checked by their `options_schema/0`.
  """
  use Cinder.ConnCase, async: false

  import Phoenix.ConnTest, only: [get: 2]

  import Phoenix.LiveViewTest,
    only: [live: 2, render_async: 1, render_change: 2, element: 2]

  alias Cinder.TestFilters.{Bare, CustomSelect, Slider}

  setup do
    previous = Application.get_env(:cinder, :filters)

    Application.put_env(:cinder, :filters,
      slider: Slider,
      custom_select: CustomSelect,
      bare: Bare
    )

    on_exit(fn ->
      if previous,
        do: Application.put_env(:cinder, :filters, previous),
        else: Application.delete_env(:cinder, :filters)
    end)

    artist = generate(artist(name: "Custom Artist"))

    for {title, genre, tracks} <- [
          {"Alpha", :rock, 8},
          {"Bravo", :jazz, 10},
          {"Charlie", :rock, 12},
          {"Delta", :pop, 14}
        ] do
      generate(album(title: title, genre: genre, track_count: tracks, artist_id: artist.id))
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

  defp mount(conn, render_fun) do
    {:ok, view, _html} = live(conn, Cinder.TestLive.Fixture.register(render_fun))
    render_async(view)
    view
  end

  defp change(view, filters) do
    view |> element("#albums-filters") |> render_change(%{"filters" => filters})
    render_async(view)
  end

  test "a hand-written type renders its own control, with its own options, and filters", %{
    conn: conn
  } do
    view =
      mount(conn, fn assigns ->
        ~H"""
        <Cinder.Next.collection id="albums" resource={Music.Album}>
          <:col :let={album} field="title">{album.title}</:col>
          <:filter field="track_count" type="slider" opts={[min: 5, max: 15]} />
        </Cinder.Next.collection>
        """
      end)

    html = render_async(view)

    assert html =~
             ~r/<input(?=[^>]*name="filters\[track_count\]")(?=[^>]*type="range")(?=[^>]*min="5")(?=[^>]*max="15")(?=[^>]*step="1")(?=[^>]*value="15")[^>]*>/

    assert html =~ ~r/<output[^>]*>15<\/output>/

    html = change(view, %{"track_count" => "11"})
    assert titles(html) == ["Alpha", "Bravo"]
    assert html =~ ~r/<output[^>]*>11<\/output>/
  end

  test "a generated type renders and filters like the built-in it's based on", %{conn: conn} do
    view =
      mount(conn, fn assigns ->
        ~H"""
        <Cinder.Next.collection id="albums" resource={Music.Album}>
          <:col :let={album} field="title">{album.title}</:col>
          <:filter field="genre" type={:custom_select} opts={[]} prompt="Any genre" />
        </Cinder.Next.collection>
        """
      end)

    html = render_async(view)
    assert html =~ ~r/<select[^>]*name="filters\[genre\]"/
    assert html =~ ~r/<option[^>]*value=""[^>]*>Any genre<\/option>/

    assert titles(change(view, %{"genre" => "rock"})) == ["Alpha", "Charlie"]
  end

  test "a type with none of the new shell's callbacks is a plain input", %{conn: conn} do
    view =
      mount(conn, fn assigns ->
        ~H"""
        <Cinder.Next.collection id="albums" resource={Music.Album}>
          <:col :let={album} field="title">{album.title}</:col>
          <:filter field="title" type="bare" />
        </Cinder.Next.collection>
        """
      end)

    assert render_async(view) =~
             ~r/<input(?=[^>]*name="filters\[title\]")(?=[^>]*type="text")[^>]*>/

    assert titles(change(view, %{"title" => "Bravo"})) == ["Bravo"]
  end

  test "in a keyword list, the type's own options sit beside the rest", %{conn: conn} do
    path =
      Cinder.TestLive.NextFixture.register(
        &Cinder.Next.LiveView.assign_collection(&1, :albums, Music.Album,
          filters: [track_count: [type: :slider, label: "Tracks", max: 12]]
        ),
        fn assigns ->
          ~H"""
          <Cinder.Next.filter :for={f <- @albums.filters} filter={f} />
          """
        end
      )

    {:ok, view, _html} = live(conn, path)
    html = render_async(view)

    assert html =~ ~r/<label[^>]*>Tracks/
    assert html =~ ~r/<input(?=[^>]*type="range")(?=[^>]*max="12")[^>]*>/
  end

  describe "a type's own options" do
    defp build(filter) do
      Cinder.Next.Config.build(%{
        resource: Music.Album,
        query: nil,
        filter: [Map.merge(%{__slot__: :filter, inner_block: nil}, filter)]
      })
    end

    test "are checked by its schema, naming the declaration and type" do
      assert_raise ArgumentError,
                   ~r/<:filter> for "track_count" \(slider\): unknown options \[:mx\]/,
                   fn -> build(%{field: "track_count", type: :slider, opts: [mx: 12]}) end

      assert_raise ArgumentError, ~r/\(slider\): invalid value for :step option/, fn ->
        build(%{field: "track_count", type: :slider, opts: [step: 0]})
      end
    end

    test "without a schema, are the keys of its default options" do
      assert_raise ArgumentError, ~r/\(bare\): unknown options \[:min\]/, fn ->
        build(%{field: "title", type: :bare, opts: [min: 1]})
      end
    end

    test "registered types are known by name, as atoms or strings" do
      assert build(%{field: "track_count", type: "slider"}).fields["track_count"].filter.type ==
               :slider

      assert_raise ArgumentError, ~r/unknown filter type :slidr/, fn ->
        build(%{field: "track_count", type: :slidr})
      end
    end
  end
end
