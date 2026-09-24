defmodule Cinder.Integration.ReloadAfterErrorTest do
  @moduledoc """
  Pins current behaviour: a collection whose query fails retries on subsequent
  parent re-renders.

  `load_data_if_needed/2` treats "no page loaded yet" as a first load, and a failed
  query leaves `:page` nil, so the collection keeps trying rather than sticking in
  its error state. That is not a designed behaviour so much as a consequence of
  reusing `:page` as the flag; it should eventually be replaced by explicit load
  state and a retry control in the error state, at which point this test should be
  inverted or deleted.

  Until then it earns its place by catching what PR #203 did by accident: re-tying
  first-load detection to a one-shot flag cleared when a query is *attempted*
  rather than when one succeeds.
  """
  use Cinder.ConnCase, async: false

  # The failing query logs the Ash error twice, once per render.
  @moduletag :capture_log

  # The action is not part of the state that triggers a reload (see @data_keys in
  # Cinder.LiveComponent), so swapping it and patching the URL gives us a parent
  # re-render with no state change — exactly the case first-load detection covers.
  defp album_collection(assigns) do
    ~H"""
    <Cinder.collection
      resource={Cinder.Integration.Album}
      action={Agent.get(assigns.action_agent, & &1)}
      url_state={@url_state}
    >
      <:col :let={album} field="title" sort>{album.title}</:col>
    </Cinder.collection>

    <.link patch="?nudge=1">Nudge</.link>
    """
  end

  setup do
    artist = generate(artist(name: "Retry Artist"))
    generate(album(title: "Retry Album", genre: :rock, artist_id: artist.id))

    on_exit(fn ->
      Ash.bulk_destroy!(Cinder.Integration.Album, :destroy, %{})
      Ash.bulk_destroy!(Cinder.Integration.Artist, :destroy, %{})
    end)

    {:ok, agent} = Agent.start_link(fn -> :missing_read_action end)

    path =
      Cinder.TestLive.Fixture.register(fn assigns ->
        album_collection(Map.put(assigns, :action_agent, agent))
      end)

    %{path: path, agent: agent}
  end

  test "a failed load is retried on the next parent re-render", %{
    conn: conn,
    path: path,
    agent: agent
  } do
    session =
      conn
      |> visit(path)
      |> refute_has("td", text: "Retry Album")

    Agent.update(agent, fn _ -> :read end)

    session
    |> click_link("Nudge")
    |> assert_has("td", text: "Retry Album")
  end
end
