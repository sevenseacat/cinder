defmodule Cinder.Next.HardFiltersTest do
  @moduledoc """
  Filters that aren't one input to one value: checkboxes posting a list, and a
  range with two inputs, on a mounted `Cinder.Next.collection`.
  """
  use Cinder.ConnCase, async: false

  import Phoenix.ConnTest, only: [get: 2]

  import Phoenix.LiveViewTest,
    only: [
      live: 2,
      render_async: 1,
      render_change: 2,
      render_patch: 2,
      element: 2,
      assert_patch: 1
    ]

  @tags ["live", "debut", "deluxe"]

  setup do
    artist = generate(artist(name: "Filters Artist"))

    for {title, tags, price} <- [
          {"Alpha", ["live"], "10"},
          {"Bravo", ["debut"], "20"},
          {"Charlie", ["live", "deluxe"], "30"},
          {"Delta", [], "40"},
          {"Echo", ["deluxe"], "50"}
        ] do
      generate(album(title: title, tags: tags, price: Decimal.new(price), artist_id: artist.id))
    end

    on_exit(fn ->
      Ash.bulk_destroy!(Music.Album, :destroy, %{})
      Ash.bulk_destroy!(Music.Artist, :destroy, %{})
    end)

    :ok
  end

  defp collection(url_synced?) do
    tags = Enum.map(@tags, &{&1, &1})

    fn assigns ->
      assigns = assign(assigns, tags: tags, url_synced?: url_synced?)

      ~H"""
      <Cinder.Next.collection id="albums" resource={Music.Album} url_state={@url_synced? && @url_state}>
        <:col :let={album} field="title">{album.title}</:col>
        <:filter field="tags" type="multi_checkboxes" options={@tags} />
        <:filter field="price" type="number_range" />
      </Cinder.Next.collection>
      """
    end
  end

  defp mount(conn, url_synced?, query \\ "") do
    path = Cinder.TestLive.Fixture.register(collection(url_synced?))
    {:ok, view, _html} = live(conn, path <> query)
    render_async(view)
    {view, path}
  end

  defp change(view, filters) do
    view |> element("#albums-filters") |> render_change(%{"filters" => filters})
    render_async(view)
  end

  defp titles(html), do: Regex.scan(~r/Alpha|Bravo|Charlie|Delta|Echo/, html) |> List.flatten()

  defp input(html, name), do: Regex.run(~r/<input[^>]*name="#{Regex.escape(name)}"[^>]*>/, html)

  describe "multi-checkboxes" do
    test "render by default, and post a list that matches any of the ticked values", %{conn: conn} do
      {view, _path} = mount(conn, false)
      assert render_async(view) =~ ~r/<fieldset[^>]*data-field="tags"/

      html = change(view, %{"tags" => ["live", "deluxe"]})

      assert Enum.sort(titles(html)) == ["Alpha", "Charlie", "Echo"]

      assert html =~
               ~r/<input(?=[^>]*value="live")(?=[^>]*checked)[^>]*name="filters\[tags\]\[\]"/
    end

    test "unticking every box clears the filter", %{conn: conn} do
      {view, _path} = mount(conn, false)
      change(view, %{"tags" => ["debut"]})

      # The test tool merges in the form's current values, so untick the box explicitly
      assert length(titles(change(view, %{"tags" => []}))) == 5
    end
  end

  describe "number range" do
    test "renders two inputs, and filters between them", %{conn: conn} do
      {view, _path} = mount(conn, false)
      html = render_async(view)
      assert input(html, "filters[price_min]")
      assert input(html, "filters[price_max]")

      assert Enum.sort(titles(change(view, %{"price_min" => "20", "price_max" => "40"}))) ==
               ["Bravo", "Charlie", "Delta"]
    end

    test "half a range filters, and the half that's typed stays in its input", %{conn: conn} do
      {view, _path} = mount(conn, false)
      html = change(view, %{"price_min" => "25", "price_max" => ""})

      assert Enum.sort(titles(html)) == ["Charlie", "Delta", "Echo"]
      assert [min] = input(html, "filters[price_min]")
      assert min =~ ~s(value="25")
    end
  end

  describe "raw input with URL sync" do
    test "survives the URL round trip, and is dropped when the URL moves elsewhere", %{
      conn: conn
    } do
      {view, path} = mount(conn, true)

      change(view, %{"price_min" => "25", "price_max" => ""})
      assert assert_patch(view) =~ "price"
      html = render_async(view)
      assert Enum.sort(titles(html)) == ["Charlie", "Delta", "Echo"]
      assert hd(input(html, "filters[price_min]")) =~ ~s(value="25")

      # What browser back does: the older URL, without the filter
      render_patch(view, path)
      html = render_async(view)

      assert length(titles(html)) == 5
      refute hd(input(html, "filters[price_min]")) =~ ~s(value="25")
    end
  end

  describe "autocomplete" do
    setup %{conn: conn} do
      titles = Enum.map(~w(Alpha Bravo Charlie Delta Echo), &{&1, &1})

      path =
        Cinder.TestLive.Fixture.register(fn assigns ->
          assigns = assign(assigns, :titles, titles)

          ~H"""
          <Cinder.Next.collection id="albums" resource={Music.Album}>
            <:col :let={album} field="genre">{album.genre}</:col>
            <:filter field="title" type="autocomplete" options={@titles} max_results={2} />
          </Cinder.Next.collection>
          """
        end)

      {:ok, view, _html} = live(conn, path)
      render_async(view)

      test_pid = self()
      handler_id = "next-autocomplete-#{System.unique_integer([:positive])}"

      :telemetry.attach(
        handler_id,
        [:ash, :music, :read, :start],
        fn _event, _measurements, _metadata, _config -> send(test_pid, :album_read) end,
        nil
      )

      on_exit(fn -> :telemetry.detach(handler_id) end)

      %{view: view}
    end

    defp option_values(html) do
      Regex.scan(~r/<input[^>]*type="radio"[^>]*value="([^"]*)"/, html, capture: :all_but_first)
      |> List.flatten()
    end

    defp reads(count \\ 0) do
      receive do
        :album_read -> reads(count + 1)
      after
        100 -> count
      end
    end

    test "typing narrows the options without querying", %{view: view} do
      html = change(view, %{"title_autocomplete_search" => "a", "title" => ""})

      # Alpha, Bravo, Charlie and Delta all contain "a"; only the first two are shown
      assert option_values(html) == ["Alpha", "Bravo"]
      assert reads() == 0

      assert option_values(change(view, %{"title_autocomplete_search" => "ec", "title" => ""})) ==
               ["Echo"]
    end

    test "choosing an option filters, and it stays chosen when the search moves on", %{view: view} do
      html = change(view, %{"title_autocomplete_search" => "ch", "title" => "Charlie"})
      # The table only shows genre, so count rows rather than titles (the options have titles)
      assert length(Regex.scan(~r/class="cinder-row"/, html)) == 1
      assert reads() == 1

      html = change(view, %{"title_autocomplete_search" => "zz", "title" => "Charlie"})
      assert option_values(html) == ["Charlie"]
      assert html =~ ~r/<input(?=[^>]*value="Charlie")[^>]*checked/
      assert reads() == 0
    end
  end

  describe "read action argument" do
    setup %{conn: conn} do
      # Give the albums different track counts for the argument to filter on
      for {album, tracks} <- Enum.zip(Ash.read!(Music.Album, load: []), [8, 10, 12, 14, 16]) do
        Ash.Seed.update!(album, %{track_count: tracks})
      end

      path =
        Cinder.TestLive.Fixture.register(fn assigns ->
          ~H"""
          <Cinder.Next.collection id="albums" resource={Music.Album} action={:with_min_tracks}>
            <:col :let={album} field="title">{album.title}</:col>
            <:argument name="min_tracks" label="Min. tracks" />
          </Cinder.Next.collection>
          """
        end)

      {:ok, view, _html} = live(conn, path)
      %{view: view}
    end

    defp min_tracks_input(html),
      do: Regex.run(~r/<input[^>]*name="filters\[min_tracks\]"[^>]*>/, html)

    @tag :capture_log
    test "on first load it's marked required, with no error until it's been used", %{
      view: view
    } do
      html = render_async(view)
      [input] = min_tracks_input(html)

      # Required and a number input, both from the action's declaration of the argument
      assert input =~ ~s(required)
      assert input =~ ~s(type="number")
      refute input =~ ~s(aria-invalid)
      refute html =~ ~s(class="cinder-filter-error")

      # The collection is waiting on input, not broken
      assert html =~ ~s(data-state="invalid")
      refute html =~ ~s(class="cinder-error")
    end

    @tag :capture_log
    test "an untouched input stays quiet; a used, empty one shows why", %{view: view} do
      # LiveView marks inputs nobody has interacted with yet as `_unused_`
      html = change(view, %{"min_tracks" => "", "_unused_min_tracks" => ""})
      refute html =~ ~s(class="cinder-filter-error")

      html = change(view, %{"min_tracks" => ""})
      assert html =~ ~r/class="cinder-filter-error"[^>]*>is required</
      assert hd(min_tracks_input(html)) =~ ~s(aria-invalid)
    end

    test "a value goes to the action, and clears the error", %{view: view} do
      html = change(view, %{"min_tracks" => "12"})

      assert length(titles(html)) == 3
      refute html =~ ~s(class="cinder-filter-error")
      refute hd(min_tracks_input(html)) =~ ~s(aria-invalid)
    end

    @tag :capture_log
    test "an invalid value shows Ash's message, and stays in the input", %{view: view} do
      html = change(view, %{"min_tracks" => "abc"})

      assert html =~ ~r/class="cinder-filter-error"[^>]*>is invalid</
      assert hd(min_tracks_input(html)) =~ ~s(value="abc")
    end
  end

  # Regression: a custom layout rendering every filter as a plain `<input>` lost a
  # select filter's value on the next change, because its `input_attrs` carried no
  # `value` (a select's value lives in its options). Attribute maps carry state as
  # well as wiring, so spreading them onto any control must keep it.
  test "a select filter's input_attrs keep its value, whatever control they're spread on", %{
    conn: conn
  } do
    path =
      Cinder.TestLive.Fixture.register(fn assigns ->
        ~H"""
        <Cinder.Next.collection id="albums" resource={Music.Album}>
          <:col :let={album} field="title">{album.title}</:col>
          <:filter field="genre" type="select" />
          <:filter field="title" type="text" />
          <:page :let={c}>
            <form {c.form_attrs}>
              <input :for={f <- c.filters} {f.input_attrs} />
            </form>
            <p :for={row <- c.rows}>{row.record.title}</p>
          </:page>
        </Cinder.Next.collection>
        """
      end)

    {:ok, view, _html} = live(conn, path)
    render_async(view)

    html = change(view, %{"genre" => "jazz", "title" => ""})
    assert html =~ ~r/<input[^>]*name="filters\[genre\]"[^>]*value="jazz"/

    # Another filter changes; the form posts the genre input's value again
    html = change(view, %{"title" => "a"})
    assert html =~ ~r/<input[^>]*name="filters\[genre\]"[^>]*value="jazz"/
  end
end
