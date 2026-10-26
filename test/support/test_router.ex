defmodule Cinder.TestRouter do
  use Phoenix.Router
  import Phoenix.LiveView.Router

  pipeline :browser do
    # Without this, `conn.params` on a disconnected render holds only path params,
    # so no URL state reaches the LiveView's first `handle_params/3`.
    plug :fetch_query_params
    plug :fetch_session
  end

  scope "/" do
    pipe_through :browser
    live "/c/:id", Cinder.TestLive.Fixture
    live "/n/:id", Cinder.TestLive.UrlSyncFixtures.NoHandleParams
    live "/o/:id", Cinder.TestLive.UrlSyncFixtures.OwnCallbacks
    live "/h/:id", Cinder.TestLive.UrlSyncFixtures.AfterHaltingHook
  end
end
