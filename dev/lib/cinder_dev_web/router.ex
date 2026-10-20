defmodule CinderDevWeb.Router do
  use CinderDevWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {CinderDevWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  scope "/", CinderDevWeb do
    pipe_through :browser

    live "/", AlbumsLive
  end
end
