defmodule Cinder.Integration.AsyncLoadMemoryTest do
  @moduledoc """
  A column's slot is a HEEx closure over the host LiveView's assigns. The async data
  load must not carry it into its task: process copies do not keep sharing, so every
  slot would bring its own copy of those assigns.
  """
  use Cinder.ConnCase, async: false

  setup {Cinder.TestHelpers, :enable_async_loading}

  @big_elements 500_000

  test "the async load task does not copy what the column slots close over", %{conn: conn} do
    test_pid = self()
    big = Enum.to_list(1..@big_elements)
    big_bytes = :erts_debug.flat_size(big) * :erlang.system_info(:wordsize)

    report_task_memory = fn query, _filter ->
      send(test_pid, {:load_task_memory, Process.info(self(), :memory)})
      query
    end

    path =
      Cinder.TestLive.Fixture.register(fn assigns ->
        assigns = Map.merge(assigns, %{big: big, report_task_memory: report_task_memory})

        ~H"""
        <Cinder.collection resource={Music.Album} url_state={@url_state}>
          <:col :let={album} field="title" filter={[type: :text, fn: @report_task_memory]}>
            {album.title}{length(@big)}
          </:col>
          <:col :let={album} field="genre">{album.genre}{length(@big)}</:col>
          <:col :let={album} field="price">{album.price}{length(@big)}</:col>
          <:col :let={album} field="release_date">{album.release_date}{length(@big)}</:col>
        </Cinder.collection>
        """
      end)

    visit(conn, path <> "?title=x")

    assert_receive {:load_task_memory, {:memory, task_memory}}, 5_000
    assert task_memory < big_bytes
  end
end
