defmodule Cinder.Integration.BulkActionSafetyTest do
  @moduledoc """
  Bulk actions stay inside the collection's scope, ignore forged events, and report a
  partial success as an error.
  """
  use Cinder.ConnCase, async: false
  use Mimic

  import Phoenix.ConnTest, only: [get: 2]

  import Phoenix.LiveViewTest,
    only: [live: 2, render: 1, render_async: 1, render_click: 3, with_target: 2]

  alias Cinder.TestLive.Fixture

  require Ash.Query

  setup do
    artist = generate(artist(name: "Bulk Artist"))

    albums =
      for {title, genre} <- [{"Alpha", :rock}, {"Bravo", :rock}, {"Charlie", :jazz}],
          into: %{} do
        {title, generate(album(title: title, genre: genre, artist_id: artist.id))}
      end

    on_exit(fn ->
      Ash.bulk_destroy!(Music.Album, :destroy, %{})
      Ash.bulk_destroy!(Music.Artist, :destroy, %{})
    end)

    %{albums: albums}
  end

  defp mount(conn, base_query) do
    path =
      Fixture.register(
        fn assigns ->
          assigns = assign(assigns, :base_query, assigns[:base_query] || base_query)

          ~H"""
          <Cinder.collection
            id="albums"
            query={@base_query}
            selectable
            on_selection_change={:selection_changed}
          >
            <:col :let={album} field="title">{album.title}</:col>
            <:bulk_action
              action={:remaster}
              label="Remaster"
              on_success={:bulk_done}
              on_error={:bulk_failed}
            />
          </Cinder.collection>
          """
        end,
        forward_to: self()
      )

    {:ok, view, _html} = live(conn, path)
    render_async(view)
    view
  end

  # Callbacks reach the test in two hops (the collection messages the LiveView, the
  # fixture forwards it), after the event has returned, so they get a generous wait

  defp event(view, name, params),
    do: view |> with_target("[data-phx-component]") |> render_click(name, params)

  defp select(view, album), do: event(view, "toggle_select", %{"id" => to_string(album.id)})

  defp remastered?(album), do: Ash.get!(Music.Album, album.id).is_remastered

  test "a bulk action only touches selected records still in the base query", %{
    conn: conn,
    albums: albums
  } do
    view = mount(conn, Ash.Query.filter(Music.Album, genre == :rock))
    select(view, albums["Alpha"])
    select(view, albums["Bravo"])

    # Alpha leaves the collection's scope after being selected
    Ash.Seed.update!(albums["Alpha"], %{genre: :jazz})

    event(view, "bulk_action_execute", %{"index" => 0})

    refute remastered?(albums["Alpha"])
    assert remastered?(albums["Bravo"])
  end

  test "changing the base query clears the selection; the user's filters and pages don't", %{
    conn: conn,
    albums: albums
  } do
    view = mount(conn, Music.Album)
    select(view, albums["Alpha"])
    assert_receive {:selection_changed, %{selected_count: 1}}, 1000

    event(view, "goto_page", %{"page" => "1"})
    refute_receive {:selection_changed, _}

    Fixture.run(view, &assign(&1, :base_query, Ash.Query.filter(Music.Album, genre == :jazz)))
    render_async(view)

    assert_receive {:selection_changed, %{selected_count: 0, action: :clear}}, 1000
    event(view, "bulk_action_execute", %{"index" => 0})
    refute remastered?(albums["Alpha"])
  end

  @tag :capture_log
  test "a forged action index runs nothing and doesn't crash", %{conn: conn, albums: albums} do
    view = mount(conn, Music.Album)
    select(view, albums["Alpha"])

    for index <- ["0", -1, 1, nil] do
      event(view, "bulk_action_execute", %{"index" => index})
    end

    assert render(view) =~ "Alpha"
    refute remastered?(albums["Alpha"])
  end

  # Ash skips records that fail and commits the rest by default, and treats a partial
  # success as a failure (its bang functions raise on it)
  @tag :capture_log
  test "a partial success is reported as an error, with the errors", %{
    conn: conn,
    albums: albums
  } do
    Mimic.set_mimic_global()
    error = Ash.Error.Unknown.UnknownError.exception(error: "one record failed")
    test = self()

    Mimic.stub(Ash, :bulk_update, fn _query, _action, _input, opts ->
      send(test, {:bulk_update_opts, opts})
      %Ash.BulkResult{status: :partial_success, errors: [error], error_count: 1}
    end)

    view = mount(conn, Music.Album)
    select(view, albums["Alpha"])
    event(view, "bulk_action_execute", %{"index" => 0})

    assert_receive {:bulk_failed, %{partial: true, reason: [^error]}}, 1000
    refute_received {:bulk_done, _}

    # Ash only returns the errors when asked
    assert_received {:bulk_update_opts, opts}
    assert opts[:return_errors?] == true
  end
end
