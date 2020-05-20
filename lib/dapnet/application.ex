defmodule Dapnet.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      # Start the Ecto repository
      Dapnet.Repo,
      # Start the Telemetry supervisor
      DapnetWeb.Telemetry,
      # Start the PubSub system
      {Phoenix.PubSub, name: Dapnet.PubSub},
      # Start the Endpoint (http/https)
      DapnetWeb.Endpoint,
      # Start a worker by calling: Dapnet.Worker.start_link(arg)
      # {Dapnet.Worker, arg}
      worker(Dapnet.CouchDB, [], restart: :permanent),

      worker(Dapnet.Cluster.RabbitMQ, [], restart: :permanent),
      worker(Dapnet.Cluster.Discovery, [], restart: :permanent),
      worker(Dapnet.Cluster.CouchDB, [], restart: :permanent),

      worker(Dapnet.Call.RabbitMQ, [], restart: :permanent),
      worker(Dapnet.Call.Dispatcher, [], restart: :permanent),

      worker(Dapnet.Transmitter.RabbitMQ, [], restart: :permanent),

      worker(Dapnet.Telemetry.Consumer, [], restart: :permanent),
      worker(Dapnet.Telemetry.Database, [], restart: :permanent),

      worker(Dapnet.Scheduler.Rubrics, [], restart: :permanent),
      worker(Dapnet.Scheduler, [])
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Dapnet.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    DapnetWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
