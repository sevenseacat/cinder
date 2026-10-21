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
end
