import Config

config :cinder, Cinder.TestEndpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  server: false,
  secret_key_base: String.duplicate("a", 64),
  live_view: [signing_salt: "cinder_test_lv"]

config :phoenix_test, :endpoint, Cinder.TestEndpoint
