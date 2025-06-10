defmodule Cinder.MixProject do
  use Mix.Project

  def project do
    [
      app: :cinder,
      version: "0.1.0",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ash, "~> 3.0"},
      {:ash_phoenix, "~> 2.3"},
      {:phoenix_live_view, "~> 1.0"},
      {:stream_data, "~> 1.1"},
      {:usage_rules, "~> 0.1", only: [:dev]},
      {:sourceror, "~> 1.8", only: [:dev, :test]},
      {:igniter, "~> 0.5", only: [:dev, :test]}
    ]
  end
end
