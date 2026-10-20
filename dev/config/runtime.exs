import Config

config :cinder_dev, CinderDevWeb.Endpoint,
  http: [port: String.to_integer(System.get_env("PORT", "4000"))]

if config_env() == :dev do
  # Reload browser tabs when matching files change.
  config :cinder_dev, CinderDevWeb.Endpoint,
    live_reload: [
      web_console_logger: true,
      patterns: [
        # Static assets, except user uploads
        ~r"priv/static/(?!uploads/).*\.(js|css|png|jpeg|jpg|gif|svg)$"E,
        # Gettext translations
        ~r"priv/gettext/.*\.po$"E,
        # Router, Controllers, LiveViews and LiveComponents
        ~r"lib/cinder_dev_web/router\.ex$"E,
        ~r"lib/cinder_dev_web/(controllers|live|components)/.*\.(ex|heex)$"E,
        # Cinder itself, and the shared music resources
        ~r"/lib/cinder(\.ex|/.*\.ex)$"E,
        ~r"/test/support/music/.*\.ex$"E
      ]
    ]
end
