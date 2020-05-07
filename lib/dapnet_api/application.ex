defmodule DapnetApi.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    import Supervisor.Spec

    children = [
      # Start the Telemetry supervisor
      DapnetApiWeb.Telemetry,
      # Start the PubSub system
      {Phoenix.PubSub, name: DapnetApi.PubSub},
      # Start the Endpoint (http/https)
      DapnetApiWeb.Endpoint,
      # Start a worker by calling: DapnetApi.Worker.start_link(arg)
      # {DapnetApi.Worker, arg}
      worker(DapnetApi.CouchDB, [], restart: :permanent),

      worker(DapnetApi.Cluster.RabbitMQ, [], restart: :permanent),
      worker(DapnetApi.Cluster.Discovery, [], restart: :permanent),
      worker(DapnetApi.Cluster.CouchDB, [], restart: :permanent),
      worker(DapnetApi.Cluster.Replication, [], restart: :permanent),

      worker(DapnetApi.Call.RabbitMQ, [], restart: :permanent),
      worker(DapnetApi.Call.Database, [], restart: :permanent),
      worker(DapnetApi.Call.Dispatcher, [], restart: :permanent),

      worker(DapnetApi.Transmitter.Database, [], restart: :permanent),
      worker(DapnetApi.Transmitter.RabbitMQ, [], restart: :permanent),

      worker(DapnetApi.Telemetry.Consumer, [], restart: :permanent),
      worker(DapnetApi.Telemetry.Database, [], restart: :permanent),
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: DapnetApi.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    DapnetApiWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
