defmodule Cinder.Integration.TelemetryTest do
  @moduledoc """
  A collection's loads emit telemetry spans and `Ash.Tracer` spans, saying which collection
  loaded and with what state, with `sensitive?` fields' values redacted as Ash does.
  """
  use Cinder.ConnCase, async: false

  import Phoenix.ConnTest, only: [get: 2]
  import Phoenix.LiveViewTest, only: [element: 2, live: 2, render_change: 2]

  # Sends its spans to the test, to check they nest
  defmodule Tracer do
    @moduledoc false
    use Ash.Tracer

    @impl true
    def start_span(type, name), do: notify({:start_span, type, name})
    @impl true
    def stop_span, do: notify(:stop_span)
    @impl true
    def set_metadata(type, metadata), do: notify({:set_metadata, type, metadata})
    @impl true
    def get_span_context, do: nil
    @impl true
    def set_span_context(_context), do: :ok
    @impl true
    def trace_type?(_type), do: true

    defp notify(message) do
      if pid = Process.whereis(Cinder.Integration.TelemetryTest), do: send(pid, message)
      :ok
    end
  end

  @events [
    [:cinder, :query, :start],
    [:cinder, :query, :stop],
    [:cinder, :query, :exception],
    [:cinder, :count, :start],
    [:cinder, :count, :stop]
  ]

  setup do
    artist = generate(artist(name: "Alice In Chains"))
    generate(album(title: "Dirt", artist_id: artist.id))

    on_exit(fn ->
      Ash.bulk_destroy!(Music.Album, :destroy, %{})
      Ash.bulk_destroy!(Music.Artist, :destroy, %{})
    end)

    ref = :telemetry_test.attach_event_handlers(self(), @events)
    on_exit(fn -> :telemetry.detach(ref) end)

    {:ok, ref: ref}
  end

  defp mount(conn, render, params \\ "") do
    {:ok, view, _html} = live(conn, Cinder.TestLive.Fixture.register(render) <> params)
    view
  end

  # A count span comes with `count: :async`, which the new shell doesn't have yet
  test "a read emits a query span with the collection's id and state", %{conn: conn, ref: ref} do
    view =
      mount(conn, fn assigns ->
        ~H"""
        <Cinder.Next.collection id="albums" resource={Music.Album}>
          <:field :let={album} name="title" filter sort search>{album.title}</:field>
        </Cinder.Next.collection>
        """
      end)

    view
    |> element("#albums-filters")
    |> render_change(%{"filters" => %{"title" => "Dirt"}, "search" => "dir"})

    assert_receive {[:cinder, :query, :start], ^ref, %{system_time: _},
                    %{search_term: "dir", id: "albums"}}

    assert_receive {[:cinder, :query, :stop], ^ref, %{duration: duration},
                    %{search_term: "dir"} = metadata}

    assert duration > 0

    assert Map.delete(metadata, :telemetry_span_context) == %{
             id: "albums",
             resource: Music.Album,
             action: :read,
             filters: %{
               "title" => %{
                 type: :text,
                 value: "Dirt",
                 operator: :contains,
                 case_sensitive: false
               }
             },
             search_term: "dir",
             sort_by: [],
             page_size: 25,
             current_page: 1,
             pagination_mode: :offset,
             result: :ok
           }
  end

  @tag :capture_log
  test "a failed read stops with an error result", %{conn: conn, ref: ref} do
    mount(conn, fn assigns ->
      ~H"""
      <Cinder.Next.collection id="albums" resource={Music.Album} action={:failing}>
        <:field :let={album} name="title">{album.title}</:field>
      </Cinder.Next.collection>
      """
    end)

    assert_receive {[:cinder, :query, :stop], ^ref, _measurements, %{result: :error}}
    refute_received {[:cinder, :query, :exception], ^ref, _measurements, _metadata}
  end

  describe "sensitive fields" do
    defp mount_users(conn) do
      mount(
        conn,
        fn assigns ->
          ~H"""
          <Cinder.Next.collection id="users" resource={Music.User} url_state={@url_state}>
            <:field :let={user} name="name" filter search>{user.name}</:field>
            <:field :let={user} name="email" filter search>{user.email}</:field>
          </Cinder.Next.collection>
          """
        end,
        "?name=Ann&email=ann%40example.com&search=ann"
      )
    end

    test "have their filter values, and the search term, redacted", %{conn: conn, ref: ref} do
      mount_users(conn)

      assert_receive {[:cinder, :query, :start], ^ref, _measurements, metadata}
      assert %{value: "Ann"} = metadata.filters["name"]
      assert %{value: "**redacted**"} = metadata.filters["email"]
      assert metadata.search_term == "**redacted**"
    end

    test "are shown with Ash's show_sensitive? config", %{conn: conn, ref: ref} do
      Application.put_env(:ash, :show_sensitive?, true)
      on_exit(fn -> Application.delete_env(:ash, :show_sensitive?) end)

      mount_users(conn)

      assert_receive {[:cinder, :query, :start], ^ref, _measurements, metadata}
      assert %{value: "ann@example.com"} = metadata.filters["email"]
      assert metadata.search_term == "ann"
    end
  end

  test "a tracer in `query_opts` sees Cinder's span around Ash's read", %{conn: conn} do
    Process.register(self(), __MODULE__)

    mount(conn, fn assigns ->
      ~H"""
      <Cinder.Next.collection id="albums" resource={Music.Album} query_opts={[tracer: Tracer]}>
        <:field :let={album} name="title">{album.title}</:field>
      </Cinder.Next.collection>
      """
    end)

    assert_receive {:set_metadata, :custom, %{id: "albums", resource: Music.Album}}

    # Spans in a process open and close like a stack, so Ash's read opening next, before
    # anything closes, puts it inside Cinder's
    spans = Enum.drop_while(spans(), &(&1 != {:start_span, :custom, "cinder:albums:query"}))
    assert [_cinder, {:start_span, :action, _ash_read} | _] = spans
  end

  defp spans do
    receive do
      {:start_span, _type, _name} = span -> [span | spans()]
      :stop_span -> [:stop_span | spans()]
    after
      100 -> []
    end
  end
end
