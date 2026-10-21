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

    live_session :demo, on_mount: CinderDevWeb.DemoHook do
      live "/", TableLive
      live "/filters", FiltersLive
      live "/list", ListLive
      live "/grid", GridLive
      live "/pagination", PaginationLive
      live "/selection", SelectionLive
      live "/controls", ControlsLive
      live "/states", StatesLive
      live "/next", NextLive
      live "/next/grid", NextGridLive
      live "/next/layouts", NextLayoutsLive
      live "/next/daisy", NextDaisyLive
      live "/next/petal", NextPetalLive
      live "/next/live", NextLiveViewLive
      live "/next/power", NextPowerLive
    end
  end
end
