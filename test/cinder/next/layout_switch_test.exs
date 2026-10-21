defmodule Cinder.Next.LayoutSwitchTest do
  @moduledoc "Switching a mounted `Cinder.Next.collection` between a table and a grid."
  use Cinder.ConnCase, async: false

  import Phoenix.ConnTest, only: [get: 2]

  import Phoenix.LiveViewTest,
    only: [
      live: 2,
      render_async: 1,
      render_click: 1,
      render_patch: 2,
      element: 2,
      has_element?: 2,
      assert_patch: 1
    ]

  setup do
    artist = generate(artist(name: "Layout Artist"))

    for title <- ~w(Alpha Bravo Charlie) do
      generate(album(title: title, artist_id: artist.id))
    end

    test_pid = self()
    handler_id = "next-layout-#{System.unique_integer([:positive])}"

    :telemetry.attach(
      handler_id,
      [:ash, :music, :read, :start],
      fn _event, _measurements, %{resource: Music.Album}, _config -> send(test_pid, :read) end,
      nil
    )

    on_exit(fn ->
      :telemetry.detach(handler_id)
      Ash.bulk_destroy!(Music.Album, :destroy, %{})
      Ash.bulk_destroy!(Music.Artist, :destroy, %{})
    end)

    :ok
  end

  defp mount(conn, url_synced?, query \\ "") do
    path =
      Cinder.TestLive.Fixture.register(fn assigns ->
        assigns = assign(assigns, :url_synced?, url_synced?)

        ~H"""
        <Cinder.Next.collection
          id="albums"
          resource={Music.Album}
          url_state={@url_synced? && @url_state}
          grid_columns={2}
        >
          <:col :let={album} field="title" sort>{album.title}</:col>
          <:item :let={album}><h3>{album.title}</h3></:item>
        </Cinder.Next.collection>
        """
      end)

    {:ok, view, _html} = live(conn, path <> query)
    render_async(view)
    flush_reads()
    {view, path}
  end

  defp flush_reads do
    receive do
      :read -> flush_reads()
    after
      50 -> :ok
    end
  end

  defp read? do
    receive do
      :read -> true
    after
      100 -> false
    end
  end

  defp switch(view, layout) do
    view |> element(~s(.cinder-layout[data-layout="#{layout}"])) |> render_click()
  end

  test "switches between a table and a grid without reloading", %{conn: conn} do
    {view, _path} = mount(conn, false)
    assert has_element?(view, ~s(table.cinder-table))
    assert has_element?(view, ~s([data-layout="table"][aria-pressed="true"]))

    html = switch(view, "grid")
    refute read?()

    assert html =~ ~r/<ul[^>]*class="cinder-grid"/
    assert length(Regex.scan(~r/<h3>/, html)) == 3
    assert has_element?(view, ~s([data-layout="grid"][aria-pressed="true"]))
    # Grids sort from the dropdown instead of headers
    assert has_element?(view, ~s(.cinder-sort-select))
  end

  test "the layout goes in the URL without a reload, and browser back returns", %{conn: conn} do
    {view, path} = mount(conn, true)

    switch(view, "grid")
    assert assert_patch(view) =~ "layout=grid"
    assert render_async(view) =~ ~r/<ul[^>]*class="cinder-grid"/
    refute read?()

    render_patch(view, path)
    assert has_element?(view, ~s(table.cinder-table))
    refute read?()
  end

  # Regression: switching back to the default left `layout=grid` in the URL, because
  # UrlSync keeps params it doesn't know the collection manages
  test "switching back to the default layout takes it out of the URL", %{conn: conn} do
    {view, _path} = mount(conn, true, "?layout=grid&keep=me")

    switch(view, "table")
    patched = assert_patch(view)

    refute patched =~ "layout="
    assert patched =~ "keep=me"
    assert has_element?(view, ~s(table.cinder-table))
  end

  test "an unknown layout in the URL falls back to the default", %{conn: conn} do
    {view, _path} = mount(conn, true, "?layout=cards")

    assert has_element?(view, ~s(table.cinder-table))
  end

  test "there's no switcher without a choice", %{conn: conn} do
    path =
      Cinder.TestLive.Fixture.register(fn assigns ->
        ~H"""
        <Cinder.Next.collection id="albums" resource={Music.Album}>
          <:col :let={album} field="title">{album.title}</:col>
        </Cinder.Next.collection>
        """
      end)

    {:ok, view, _html} = live(conn, path)
    render_async(view)

    refute has_element?(view, ~s(.cinder-layout-switch))
  end
end
