defmodule Cinder.Integration.SortKeyGuardTest do
  @moduledoc """
  A `toggle_sort` event with a key that is not a sortable column must be a no-op.

  The collection under test deliberately has no `url_state`: with URL sync on, the
  sort is re-decoded against the columns in `handle_params`, which already drops
  bad keys. Without it, the event handler is the only guard.
  """
  use Cinder.ConnCase, async: false

  import Phoenix.LiveViewTest, only: [with_target: 2, render_click: 3, render: 1]

  # Base query sorted by title so row order is deterministic on the ETS data layer.
  defp guarded_collection(assigns) do
    ~H"""
    <Cinder.collection query={Ash.Query.sort(Music.Album, title: :asc)}>
      <:col :let={album} field="title" sort>{album.title}</:col>
      <:col :let={album} field="is_remastered">{to_string(album.is_remastered)}</:col>
    </Cinder.collection>
    """
  end

  defp synced_collection(assigns) do
    ~H"""
    <Cinder.collection resource={Music.Album} url_state={@url_state}>
      <:col :let={album} field="title" sort>{album.title}</:col>
    </Cinder.collection>
    """
  end

  # No columns at all, so the URL's sort has nothing to be checked against
  defp synced_grid(assigns) do
    ~H"""
    <Cinder.collection
      query={Ash.Query.sort(Music.Album, title: :asc)}
      layout={:grid}
      url_state={@url_state}
    >
      <:item :let={album}><p class="album">{album.title}</p></:item>
    </Cinder.collection>
    """
  end

  setup do
    # Sorted by is_remastered ascending these would swap, so a sort that slips
    # through changes the row order.
    artist = generate(artist(name: "Guard Artist"))
    generate(album(title: "Aaa", is_remastered: true, artist_id: artist.id))
    generate(album(title: "Bbb", is_remastered: false, artist_id: artist.id))

    on_exit(fn ->
      Ash.bulk_destroy!(Music.Album, :destroy, %{})
      Ash.bulk_destroy!(Music.Artist, :destroy, %{})
    end)

    :ok
  end

  defp bogus_key, do: "cinder_bogus_#{System.unique_integer([:positive])}"

  defp refute_atom_exists(name) do
    assert_raise ArgumentError, fn -> String.to_existing_atom(name) end
  end

  # Returns the HTML so it can be the last expression in `unwrap/2`.
  defp assert_unchanged(view, before) do
    html = render(view)
    assert html == before
    html
  end

  # The collection's root element carries no DOM id, so target the component itself.
  defp toggle_sort(view, key) do
    view
    |> with_target("[data-phx-component]")
    |> render_click("toggle_sort", %{"key" => key})
  end

  describe "toggle_sort event" do
    test "an unknown key is a no-op and mints no atom", %{conn: conn} do
      key = bogus_key()
      path = Cinder.TestLive.Fixture.register(&guarded_collection/1)

      conn
      |> visit(path)
      |> unwrap(fn view ->
        before = render(view)
        toggle_sort(view, key)
        assert_unchanged(view, before)
      end)
      |> assert_has("tr[data-key=row_class]:first-child td:first-child", text: "Aaa")

      refute_atom_exists(key)
    end

    test "a real but non-sortable column is a no-op", %{conn: conn} do
      path = Cinder.TestLive.Fixture.register(&guarded_collection/1)

      conn
      |> visit(path)
      |> unwrap(fn view ->
        before = render(view)
        toggle_sort(view, "is_remastered")
        assert_unchanged(view, before)
      end)
      |> assert_has("tr[data-key=row_class]:first-child td:first-child", text: "Aaa")
    end
  end

  describe "sort URL param" do
    test "an unknown field is dropped and mints no atom", %{conn: conn} do
      key = bogus_key()
      path = Cinder.TestLive.Fixture.register(&synced_collection/1)

      conn
      |> visit(path <> "?sort=#{key}")
      |> assert_has("td", text: "Aaa")
      |> assert_has("td", text: "Bbb")

      refute_atom_exists(key)
    end

    # Regression: with no columns to check against, the sort went through unchecked.
    # A real attribute sorted the records (by a field nothing declared sortable), and
    # anything else failed validation and put the whole collection in its error state.
    test "is ignored when the collection has no columns to sort by", %{conn: conn} do
      path = Cinder.TestLive.Fixture.register(&synced_grid/1)

      # Each of these would put Bbb first if it were applied
      for sort <- ["-title", "is_remastered", bogus_key()] do
        conn
        |> visit(path <> "?sort=#{sort}")
        |> unwrap(fn view ->
          html = render(view)
          assert html =~ ~r/Aaa.*Bbb/s, "?sort=#{sort} changed the order, or errored"
          html
        end)
      end
    end
  end
end
