defmodule Cinder.TestLive.Fixture do
  @moduledoc """
  A logic-free host LiveView whose template is supplied by the test.

  This is the single fixture for full-lifecycle integration tests. It contains no
  collection-specific logic — the test provides the HEEx, so there is nothing in
  the fixture itself worth testing. It just wires up `mount`, `handle_params`, and
  `Cinder.UrlSync`, runs functions the test sends it, and delegates `render/1` to
  the supplied function.

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

  To call a parent-side function such as `Cinder.refresh_table/3` from a test,
  give the collection an explicit ID and use `run/2`:

      Cinder.TestLive.Fixture.run(view, &Cinder.refresh_table(&1, "albums", silent: true))
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

  @doc """
  Runs `fun` on the mounted LiveView's socket, as a parent's `handle_info/2`
  would, and returns once it has run.

  Anything `fun` queues for the LiveView, such as a `send_update`, is then
  handled before the next `render/1`, so the render sees its effect.
  """
  def run(view, fun) when is_function(fun, 1) do
    ref = make_ref()
    send(view.pid, {:run, {self(), ref}, fun})

    receive do
      {^ref, :ok} -> :ok
    after
      1000 -> raise "the fixture LiveView did not run the function"
    end
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
  def handle_info({:run, {pid, ref}, fun}, socket) do
    socket = fun.(socket)
    send(pid, {ref, :ok})
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    assigns.__render_fun__.(assigns)
  end
end
