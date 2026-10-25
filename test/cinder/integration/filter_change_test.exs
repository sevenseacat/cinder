defmodule Cinder.Integration.FilterChangeTest do
  @moduledoc """
  Covers when a `filter_change` event reads the collection again: only when the
  filters or search actually changed, with or without URL sync.
  """
  use Cinder.ConnCase, async: false
  import Phoenix.ConnTest, only: [get: 2]
  import Phoenix.LiveViewTest, only: [live: 2, element: 2, render_change: 2]

  defp collection(assigns) do
    ~H"""
    <Cinder.collection resource={Music.Album}>
      <:col :let={album} field="title" filter={autocomplete_filter()}>{album.title}</:col>
    </Cinder.collection>
    """
  end

  defp url_synced_collection(assigns) do
    ~H"""
    <Cinder.collection resource={Music.Album} url_state={@url_state}>
      <:col :let={album} field="title" filter={autocomplete_filter()}>{album.title}</:col>
    </Cinder.collection>
    """
  end

  defp autocomplete_filter do
    [
      type: :autocomplete,
      options: [{"Async Album", "Async Album"}, {"Buffered Album", "Buffered Album"}]
    ]
  end

  def send_album_read(_event, _measurements, %{resource: Music.Album}, test_pid),
    do: send(test_pid, :album_read)

  def send_album_read(_event, _measurements, _metadata, _test_pid), do: :ok

  setup do
    artist = generate(artist(name: "Artist"))
    generate(album(title: "Async Album", genre: :rock, artist_id: artist.id))
    generate(album(title: "Buffered Album", genre: :rock, artist_id: artist.id))

    test_pid = self()
    handler_id = "filter-change-test-#{System.unique_integer([:positive])}"

    :telemetry.attach(
      handler_id,
      [:ash, :music, :read, :start],
      &__MODULE__.send_album_read/4,
      test_pid
    )

    on_exit(fn ->
      :telemetry.detach(handler_id)
      Ash.bulk_destroy!(Music.Album, :destroy, %{})
      Ash.bulk_destroy!(Music.Artist, :destroy, %{})
    end)

    %{
      path: Cinder.TestLive.Fixture.register(&collection/1),
      url_synced_path: Cinder.TestLive.Fixture.register(&url_synced_collection/1)
    }
  end

  for {name, path_key} <- [{"without URL sync", :path}, {"with URL sync", :url_synced_path}] do
    test "typing in an autocomplete filter's search box doesn't reload the collection, #{name}",
         %{conn: conn} = context do
      {:ok, view, _html} = live(conn, context[unquote(path_key)])
      flush_reads()
      form = element(view, "form[phx-change=filter_change]")

      html =
        render_change(form, %{"filters" => %{"title" => "", "title_autocomplete_search" => "Buf"}})

      # The dropdown still narrows to the typed text...
      assert html =~ ~s(value="Buffered Album")
      refute html =~ ~s(value="Async Album")
      # ...without reading the collection again.
      refute_receive :album_read, 100

      # Picking an option is a real change, so it does read.
      render_change(form, %{"filters" => %{"title" => "Buffered Album"}})
      assert_receive :album_read
    end
  end

  defp flush_reads do
    receive do
      :album_read -> flush_reads()
    after
      50 -> :ok
    end
  end
end
