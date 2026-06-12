defmodule Cinder.TestRouter do
  use Phoenix.Router
  import Phoenix.LiveView.Router

  pipeline :browser do
    plug :fetch_session
  end

  scope "/" do
    pipe_through :browser
    live "/c/:id", Cinder.TestLive.Fixture
  end
end
