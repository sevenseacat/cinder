import Config

config :cinder, Cinder.TestEndpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  server: false,
  secret_key_base: String.duplicate("a", 64),
  live_view: [signing_salt: "cinder_test_lv"]

config :phoenix_test, :endpoint, Cinder.TestEndpoint

config :ash, default_string_length_count: :codepoints

# Short, so a test waiting it out doesn't wait long
config :cinder, bulk_action_confirm_delay: 200
