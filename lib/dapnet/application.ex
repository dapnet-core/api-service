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

      {Dapnet.CouchDB, restart: :permanent},

      {Dapnet.Cluster.RabbitMQ, restart: :permanent},
      {Dapnet.Cluster.Discovery, restart: :permanent},
      {Dapnet.Cluster.CouchDB, restart: :permanent},

      {Dapnet.Call.RabbitMQ, restart: :permanent},
      {Dapnet.Call.Dispatcher, restart: :permanent},

      {Dapnet.Transmitter.RabbitMQ, restart: :permanent},

      {Dapnet.Telemetry.Consumer, restart: :permanent},
      {Dapnet.Telemetry.Database, restart: :permanent},

      {Dapnet.Scheduler.Rubrics, restart: :permanent},
      Dapnet.Scheduler
    ]
    
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
