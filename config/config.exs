import Config

# Add your configuration here
config :logger, level: :info

if config_env() == :test do
  import_config "test.exs"
end
