defmodule Cinder.MixProject do
  use Mix.Project

  @version "0.12.1"
  @source_url "https://github.com/sevenseacat/cinder"

  def project do
    [
      app: :cinder,
      version: @version,
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      consolidate_protocols: Mix.env() == :prod,
      deps: deps(),
      docs: docs(),
      package: package(),
      description: description(),
      name: "Cinder",
      aliases: aliases(),
      source_url: @source_url,
      dialyzer: [plt_add_apps: [:mix]],
      gettext: [write_reference_line_numbers: false]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp aliases do
    [
      docs: [
        "compile",
        fn _ -> Cinder.Theme.Docs.write_docs!() end,
        "docs",
        &copy_theme_images/1
      ]
    ]
  end

  defp copy_theme_images(_) do
    File.cp_r!("./docs/screenshots", "./doc/screenshots")
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ash, "~> 3.0"},
      {:ash_phoenix, "~> 2.3"},
      {:phoenix_live_view, "~> 1.0"},
      {:spark, "~> 2.0"},
      {:gettext, "~> 1.0.0"},
      {:usage_rules, "~> 1.0", only: [:dev]},
      {:ex_doc, "~> 0.38", only: :dev, runtime: false},
      {:makeup_eex, "~> 2.0", only: :dev},
      {:makeup_html, ">= 0.0.0", only: :dev},
      {:igniter, "~> 0.5", only: [:dev, :test]},
      {:sourceror, "~> 1.8", only: [:dev, :test]},
      {:mimic, "~> 2.3", only: :test},
      {:ex_check, "~> 0.16", only: [:dev], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:sobelow, "~> 0.13", only: [:dev, :test], runtime: false},
      {:mix_audit, "~> 2.1", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.0", only: [:dev, :test], runtime: false}
    ]
  end

  defp description do
    "A powerful, intelligent data table component for Phoenix LiveView applications with seamless Ash Framework integration."
  end

  defp package do
    [
      name: "cinder",
      maintainers: ["Rebecca Le <traybaby@gmail.com>"],
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url, "Website" => "https://cinder.sevenseacat.net"},
      files: ~w(lib i18n .formatter.exs mix.exs README.md CHANGELOG.md LICENSE usage-rules.md)
    ]
  end

  defp docs do
    [
      main: "readme",
      source_ref: "v#{@version}",
      source_url: @source_url,
      extras: [
        "README.md",
        "docs/getting-started.md",
        "docs/filters.md",
        "docs/sorting.md",
        "docs/advanced.md",
        "docs/theming.md",
        "docs/theme-showcase.md",
        "docs/custom-filters.md",
        "docs/localization.md",
        "docs/upgrading.md",
        "docs/examples.md",
        "CHANGELOG.md"
      ],
      groups_for_modules: [
        "Core Components": [
          Cinder,
          Cinder.Collection,
          Cinder.Controls,
          Cinder.LiveComponent
        ],
        "URL State Management": [
          Cinder.UrlSync,
          Cinder.UrlManager
        ],
        Refresh: [
          Cinder.Refresh,
          Cinder.Update
        ],
        "Filter Types": [
          Cinder.Filter,
          Cinder.Filter.Helpers,
          ~r/Cinder\.Filters\./
        ],
        Renderers: [
          ~r/Cinder\.Renderers\./
        ],
        "Theming System": [
          Cinder.Theme,
          ~r/Cinder\.Theme\./,
          ~r/Cinder\.Themes\./,
          ~r/Cinder\.Components\./
        ],
        Localization: [
          Cinder.Gettext,
          Cinder.Messages
        ],
        "Mix Tasks": [
          ~r/Mix\.Tasks\./
        ],
        Internal: [
          Cinder.QueryBuilder,
          Cinder.Column,
          Cinder.FilterManager,
          Cinder.Filter.Debug,
          Cinder.PageSize,
          Cinder.BulkActionExecutor
        ],
        Deprecated: [
          Cinder.Table,
          Cinder.Table.UrlSync,
          Cinder.Table.Refresh
        ]
      ]
    ]
  end
end
