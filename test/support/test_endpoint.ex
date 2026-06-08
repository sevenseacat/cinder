defmodule Cinder.TestEndpoint do
  use Phoenix.Endpoint, otp_app: :cinder

  @session_options [
    store: :cookie,
    key: "_cinder_test",
    signing_salt: "cinder_test_salt"
  ]

  socket "/live", Phoenix.LiveView.Socket, websocket: [connect_info: [session: @session_options]]

  plug Plug.Session, @session_options
  plug Cinder.TestRouter
end
