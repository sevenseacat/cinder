defmodule CinderDevWeb.DemoHook do
  @moduledoc """
  Shared by every demo page: assigns the Cinder theme from `?theme=` and the
  current query params, so the layout's theme switcher can keep the rest of
  the URL (filters, sort, page) when switching.
  """

  import Phoenix.Component, only: [assign: 3]
  import Phoenix.LiveView, only: [attach_hook: 4]

  @default_theme "daisy_ui"

  def on_mount(:default, _params, _session, socket) do
    {:cont,
     attach_hook(socket, :theme, :handle_params, fn params, uri, socket ->
       {:cont,
        socket
        |> assign(:theme, params["theme"] || @default_theme)
        |> assign(:current_path, URI.parse(uri).path)
        |> assign(:query_params, params)}
     end)}
  end
end
