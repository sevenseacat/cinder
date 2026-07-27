defmodule Cinder.Integration.AsyncLoadTest do
  @moduledoc """
  Covers opt-in server-rendered initial data with async loading enabled.

  Every other integration test loads data synchronously (see `Cinder.ConnCase`)
  for simplicity. This test opts back into Cinder's default async mode and
  verifies the global and per-collection SSR settings.
  """
  use Cinder.ConnCase, async: false
  import Phoenix.ConnTest, only: [get: 2, html_response: 2]

  # Opt back into async loading for this test (ConnCase's setup disabled it).
  setup {Cinder.TestHelpers, :enable_async_loading}

  defp restore_ssr_config(nil), do: Application.delete_env(:cinder, :ssr)
  defp restore_ssr_config(value), do: Application.put_env(:cinder, :ssr, value)

  defp ssr_album_collection(assigns) do
    ~H"""
    <Cinder.collection resource={Cinder.Integration.Album} url_state={@url_state} ssr>
      <:col :let={album} field="title" sort>{album.title}</:col>
    </Cinder.collection>
    """
  end

  defp default_album_collection(assigns) do
    ~H"""
    <Cinder.collection resource={Cinder.Integration.Album} url_state={@url_state}>
      <:col :let={album} field="title" sort>{album.title}</:col>
    </Cinder.collection>
    """
  end

  defp async_album_collection(assigns) do
    ~H"""
    <Cinder.collection resource={Cinder.Integration.Album} url_state={@url_state} ssr={false}>
      <:col :let={album} field="title" sort>{album.title}</:col>
    </Cinder.collection>
    """
  end

  setup do
    artist = generate(artist(name: "Async Artist"))
    generate(album(title: "Async Album", genre: :rock, artist_id: artist.id))

    on_exit(fn ->
      Ash.bulk_destroy!(Cinder.Integration.Album, :destroy, %{})
      Ash.bulk_destroy!(Cinder.Integration.Artist, :destroy, %{})
    end)

    %{
      ssr_path: Cinder.TestLive.Fixture.register(&ssr_album_collection/1),
      default_path: Cinder.TestLive.Fixture.register(&default_album_collection/1),
      async_path: Cinder.TestLive.Fixture.register(&async_album_collection/1)
    }
  end

  test "ssr=true includes collection data in the initial HTTP response", %{
    conn: conn,
    ssr_path: path
  } do
    html =
      conn
      |> get(path)
      |> html_response(200)

    assert html =~ "Async Album"
  end

  test "SSR is disabled by default", %{conn: conn, default_path: path} do
    html =
      conn
      |> get(path)
      |> html_response(200)

    refute html =~ "Async Album"
  end

  test "the default async load still delivers collection data", %{conn: conn, default_path: path} do
    conn
    |> visit(path)
    |> assert_has("td", text: "Async Album", timeout: 1000)
  end

  test "SSR can be enabled globally", %{conn: conn, default_path: path} do
    original = Application.get_env(:cinder, :ssr)
    Application.put_env(:cinder, :ssr, true)
    on_exit(fn -> restore_ssr_config(original) end)

    html =
      conn
      |> get(path)
      |> html_response(200)

    assert html =~ "Async Album"
  end

  test "a collection setting overrides the global setting", %{conn: conn, async_path: path} do
    original = Application.get_env(:cinder, :ssr)
    Application.put_env(:cinder, :ssr, true)
    on_exit(fn -> restore_ssr_config(original) end)

    html =
      conn
      |> get(path)
      |> html_response(200)

    refute html =~ "Async Album"
  end
end
