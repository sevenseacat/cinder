defmodule Cinder.TestLive.Fixture do
  @moduledoc """
  A minimal host LiveView whose template is supplied by the test.

  This is the single fixture for full-lifecycle integration tests. It contains no
  collection-specific rendering logic — the test provides the HEEx. It wires up
  `mount`, `handle_params`, and `Cinder.UrlSync`, forwards refresh messages to
  `Cinder.refresh_table/3`, and delegates `render/1` to the supplied function.

  ## Usage

      path =
        Cinder.TestLive.Fixture.register(fn assigns ->
          ~H\"\"\"
          <Cinder.collection resource={Cinder.Integration.Album} url_state={@url_state}>
            <:col :let={album} field="title" filter sort>{album.title}</:col>
          </Cinder.collection>
          \"\"\"
        end)

      conn |> visit(path) |> assert_has("td", text: "...")

  The render function receives the LiveView's full assigns (including `@url_state`)
  and returns the rendered template. Its parameter **must** be named `assigns` so
  the `~H` sigil and `@field` references resolve. (`import Phoenix.Component` is
  brought in by `Cinder.ConnCase`.)

  To request a refresh from a mounted LiveView test, give the collection an
  explicit ID and send the fixture a message:

      send(view.pid, {:refresh_table, "albums", silent: true})

  Pass `[]` as the final tuple element for an ordinary refresh.
  """
  use Phoenix.LiveView, layout: false
  use Cinder.UrlSync

  @table :cinder_test_fixtures

  @doc """
  Creates the registry table. Call once from `test_helper.exs` before any test
  registers a render function.
  """
  def setup_registry! do
    :ets.new(@table, [:named_table, :public, :set, read_concurrency: true])
    :ok
  end

  @doc """
  Registers a render function and returns the path to mount it at.

  The function is held in an in-process ETS table (not serialized), so it can be
  any closure capturing test state.
  """
  def register(render_fun) when is_function(render_fun, 1) do
    id = System.unique_integer([:positive]) |> Integer.to_string()
    :ets.insert(@table, {id, render_fun})
    "/c/#{id}"
  end

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    case :ets.lookup(@table, id) do
      [{^id, render_fun}] ->
        {:ok, assign(socket, :__render_fun__, render_fun)}

      [] ->
        raise "No fixture registered for id #{inspect(id)}. " <>
                "Call Cinder.TestLive.Fixture.register/1 and visit the returned path."
    end
  end

  @impl true
  def handle_params(params, uri, socket) do
    {:noreply, Cinder.UrlSync.handle_params(params, uri, socket)}
  end

  @impl true
  def handle_info({:refresh_table, collection_id, opts}, socket) do
    {:noreply, Cinder.refresh_table(socket, collection_id, opts)}
  end

  @impl true
  def render(assigns) do
    assigns.__render_fun__.(assigns)
  end
end
