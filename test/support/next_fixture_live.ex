defmodule Cinder.TestLive.NextFixture do
  @moduledoc """
  A host LiveView for collections kept in a LiveView's assigns
  (`use Cinder.Next.LiveView`), with its `mount` and template supplied by the test,
  like `Cinder.TestLive.Fixture` does for templates alone.

      path =
        Cinder.TestLive.NextFixture.register(
          &Cinder.Next.LiveView.assign_collection(&1, :albums, Music.Album, url: true),
          fn assigns ->
            ~H\"\"\"
            <Cinder.Next.table collection={@albums}>
              <:col :let={album} field="title">{album.title}</:col>
            </Cinder.Next.table>
            \"\"\"
          end
        )
  """
  use Phoenix.LiveView, layout: false
  use Cinder.Next.LiveView

  @table :cinder_test_next_fixtures

  @doc "Creates the registry table; call once from `test_helper.exs`."
  def setup_registry! do
    :ets.new(@table, [:named_table, :public, :set, read_concurrency: true])
    :ok
  end

  @doc "Registers a `mount` function (socket in, socket out) and a template, returning the path."
  def register(mount_fun, render_fun)
      when is_function(mount_fun, 1) and is_function(render_fun, 1) do
    id = System.unique_integer([:positive]) |> Integer.to_string()
    :ets.insert(@table, {id, mount_fun, render_fun})
    "/n/#{id}"
  end

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    [{^id, mount_fun, render_fun}] = :ets.lookup(@table, id)
    {:ok, socket |> assign(:__render_fun__, render_fun) |> mount_fun.()}
  end

  @impl true
  def handle_params(_params, _uri, socket), do: {:noreply, socket}

  @impl true
  def render(assigns), do: assigns.__render_fun__.(assigns)
end
