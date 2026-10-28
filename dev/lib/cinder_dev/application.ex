defmodule CinderDev.Application do
  # See https://elixir.hexdocs.pm/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      CinderDevWeb.Telemetry,
      {Phoenix.PubSub, name: CinderDev.PubSub},
      # Start a worker by calling: CinderDev.Worker.start_link(arg)
      # {CinderDev.Worker, arg},
      # Start to serve requests, typically the last entry
      CinderDevWeb.Endpoint
    ]

    # See https://elixir.hexdocs.pm/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: CinderDev.Supervisor]

    with {:ok, pid} <- Supervisor.start_link(children, opts) do
      CinderDev.Seeds.run()
      {:ok, pid}
    end
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    CinderDevWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
