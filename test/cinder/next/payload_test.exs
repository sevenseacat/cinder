defmodule Cinder.Next.PayloadTest do
  @moduledoc """
  Spike measurement (7CC-158): how much each shell sends over the wire per
  interaction. Excluded by default; run with `mix test --only payload`.

  Traces the LiveView process's messages to the test client and adds up the
  JSON size of every diff (the event's reply, plus any pushed diffs), for the
  same actions on both shells. Both are URL-synced, so each action also goes
  through the URL patch round trip, where the parent re-renders the collection.
  """
  use Cinder.ConnCase, async: false

  import Phoenix.ConnTest, only: [get: 2]
  import Phoenix.LiveViewTest, only: [live: 2, render_click: 1, render_change: 2, element: 2]

  @moduletag :payload

  @selectors %{
    current: %{
      sort: "[phx-click=toggle_sort][phx-value-key=title]",
      page_2: ~s(button[phx-click=goto_page][phx-value-page="2"][title="Go to page 2"])
    },
    next: %{
      sort: ~s([data-part="sort"][phx-value-field="title"]),
      page_2: ~s(button[data-part="page"][data-kind="page"][phx-value-page="2"])
    }
  }

  setup do
    artist = generate(artist(name: "Payload Artist"))

    for n <- 1..250 do
      genre = Enum.at([:rock, :pop, :jazz, :classical], rem(n, 4))
      generate(album(title: "Album #{n}", genre: genre, artist_id: artist.id))
    end

    on_exit(fn ->
      Ash.bulk_destroy!(Music.Album, :destroy, %{})
      Ash.bulk_destroy!(Music.Artist, :destroy, %{})
    end)

    :ok
  end

  defp collection(:current, rows, url?) do
    fn assigns ->
      assigns = assign(assigns, rows: rows, url?: url?)

      ~H"""
      <Cinder.collection id="albums" resource={Music.Album} url_state={@url? && @url_state} page_size={@rows}>
        <:col :let={album} field="title" filter sort search>{album.title}</:col>
        <:col :let={album} field="genre" filter={[type: :select]} sort>{album.genre}</:col>
        <:col :let={album} field="price" sort>{Decimal.to_string(album.price)}</:col>
        <:col :let={album} field="release_date" sort>{album.release_date}</:col>
      </Cinder.collection>
      """
    end
  end

  defp collection(:next, rows, url?) do
    fn assigns ->
      assigns = assign(assigns, rows: rows, url?: url?)

      ~H"""
      <Cinder.Next.collection
        id="albums"
        resource={Music.Album}
        url_state={@url? && @url_state}
        page_size={@rows}
      >
        <:col :let={album} field="title" filter sort search>{album.title}</:col>
        <:col :let={album} field="genre" filter sort>{album.genre}</:col>
        <:col :let={album} field="price" sort>{Decimal.to_string(album.price)}</:col>
        <:col :let={album} field="release_date" sort>{album.release_date}</:col>
      </Cinder.Next.collection>
      """
    end
  end

  # Every diff the LiveView sent since tracing started, as JSON bytes
  defp sent_bytes(acc \\ 0) do
    receive do
      {:trace, _pid, :send, %Phoenix.Socket.Reply{payload: %{diff: diff}}, _to} ->
        sent_bytes(acc + byte_size(Jason.encode!(diff)))

      {:trace, _pid, :send, %Phoenix.Socket.Message{event: "diff", payload: diff}, _to} ->
        sent_bytes(acc + byte_size(Jason.encode!(diff)))

      {:trace, _pid, :send, _other, _to} ->
        sent_bytes(acc)
    after
      300 -> acc
    end
  end

  defp measure(view, action) do
    :erlang.trace(view.pid, true, [:send])
    action.()
    bytes = sent_bytes()
    :erlang.trace(view.pid, false, [:send])
    bytes
  end

  test "diff payload per interaction", %{conn: conn} do
    results =
      for url? <- [true, false], rows <- [25, 100], impl <- [:current, :next] do
        selectors = @selectors[impl]

        {:ok, view, _html} =
          live(conn, Cinder.TestLive.Fixture.register(collection(impl, rows, url?)))

        sort = measure(view, fn -> view |> element(selectors.sort) |> render_click() end)
        page = measure(view, fn -> view |> element(selectors.page_2) |> render_click() end)

        filter =
          measure(view, fn ->
            view |> element("form") |> render_change(%{"filters" => %{"genre" => "rock"}})
          end)

        {url?, rows, impl, sort, page, filter}
      end

    IO.puts("\nurl   rows  shell     sort    page 2  filter   (JSON bytes sent per interaction)")

    for {url?, rows, impl, sort, page, filter} <- results do
      IO.puts(
        "#{String.pad_trailing("#{url?}", 6)}#{String.pad_trailing("#{rows}", 6)}#{String.pad_trailing("#{impl}", 10)}" <>
          Enum.map_join([sort, page, filter], "", &String.pad_trailing("#{&1}", 8))
      )
    end
  end
end
