defmodule Cinder.TestLive.UrlSyncFixtures do
  @moduledoc """
  Host LiveViews for `use Cinder.UrlSync` set up in ways `Cinder.TestLive.Fixture`
  (which calls `Cinder.UrlSync.handle_params/3` itself) doesn't cover. They share its
  registry: register a render function with `Cinder.TestLive.Fixture.register/2` and
  swap the path's `/c/` for the fixture's prefix.
  """

  defmodule NoHandleParams do
    @moduledoc "URL sync from `on_mount Cinder.UrlSync` alone, mounted at `/n/:id`."
    use Phoenix.LiveView, layout: false
    on_mount Cinder.UrlSync

    @impl true
    def mount(%{"id" => id}, _session, socket) do
      {:ok, Cinder.TestLive.Fixture.assign_registered(socket, id)}
    end

    @impl true
    def render(assigns), do: assigns.__render_fun__.(assigns)
  end

  defmodule HaltingHook do
    @moduledoc """
    A `handle_params` hook that, like many, halts when the LiveView has no
    `handle_params/3` (carrying on would crash a patch), which skips every hook after it.
    """
    def on_mount(:default, _params, _session, socket) do
      {:cont,
       Phoenix.LiveView.attach_hook(socket, :halting, :handle_params, fn _params, _uri, socket ->
         if function_exported?(socket.view, :handle_params, 3),
           do: {:cont, socket},
           else: {:halt, socket}
       end)}
    end
  end

  defmodule AfterHaltingHook do
    @moduledoc """
    `use Cinder.UrlSync` after another app hook that halts, and no `handle_params/3`
    (like a page in a `live_session` with its own hooks), mounted at `/h/:id`.
    """
    use Phoenix.LiveView, layout: false
    on_mount Cinder.TestLive.UrlSyncFixtures.HaltingHook
    use Cinder.UrlSync

    @impl true
    def mount(%{"id" => id}, _session, socket) do
      {:ok, Cinder.TestLive.Fixture.assign_registered(socket, id)}
    end

    @impl true
    def render(assigns), do: assigns.__render_fun__.(assigns)
  end

  defmodule OwnCallbacks do
    @moduledoc """
    Its own `handle_params/3` and `handle_info/2`, neither calling Cinder, mounted at
    `/o/:id`. `handle_params/3` assigns `@tab`; `{:ping, pid}` is answered with `:pong`.
    """
    use Phoenix.LiveView, layout: false
    use Cinder.UrlSync

    @impl true
    def mount(%{"id" => id}, _session, socket) do
      {:ok, Cinder.TestLive.Fixture.assign_registered(socket, id)}
    end

    @impl true
    def handle_params(params, _uri, socket) do
      {:noreply, assign(socket, :tab, params["tab"])}
    end

    @impl true
    def handle_info({:ping, pid}, socket) do
      send(pid, :pong)
      {:noreply, socket}
    end

    @impl true
    def render(assigns), do: assigns.__render_fun__.(assigns)
  end
end
