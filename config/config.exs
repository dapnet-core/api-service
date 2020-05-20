# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
use Mix.Config

config :dapnet,
  ecto_repos: [Dapnet.Repo]

# Configures the endpoint
config :dapnet, DapnetWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "6pnkZMQKDsXpSeeBgAbj57iToVlx/I9xi0Gp0vkK19wxyjZVf9WhRNYVGyoxbSRK",
  render_errors: [view: DapnetWeb.ErrorView, accepts: ~w(json), layout: false],
  pubsub_server: Dapnet.PubSub,
  live_view: [signing_salt: "G8lmzTfy"],
  http: [dispatch: [
    {:_, [
     {"/telemetry", Dapnet.Telemetry.Websocket, :all},
     {"/telemetry/transmitters/:id", Dapnet.Telemetry.Websocket, :transmitter},
     {"/telemetry/nodes/:id", Dapnet.Telemetry.Websocket, :node},
     {:_, Phoenix.Endpoint.Cowboy2Handler, {DapnetWeb.Endpoint, []}}
   ]}]]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :phoenix, :filter_parameters, ["password", "auth_key"]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

config :dapnet, Dapnet.Cluster.Discovery,
  seed: %{
    "db0sda-dc1" => %{
      "host" => "dapnetdc1.db0sda.ampr.org"
    },
    "db0sda-dc2" => %{
      "host" => "dapnetdc2.db0sda.ampr.org"
    },
    "db0sda-dc3" => %{
      "host" => "dapnetdc3.db0sda.ampr.org"
    }
  }

config :dapnet, Dapnet.Scheduler,
  jobs: [
    {"*/1 * * * *", {Dapnet.Cluster.Discovery, :update, []}},
    {"*/2 * * * *", {Dapnet.Cluster.RabbitMQ, :update, []}},
    {"*/2 * * * *", {Dapnet.Cluster.CouchDB, :replicate, []}},

    {"*/10 * * * *", {Dapnet.Scheduler.Time, :send_calls, []}},
    {"*/2 * * * *", {Dapnet.Scheduler.Rubrics, :update_queue, []}},
    {"* * * * *", {Dapnet.Scheduler.Rubrics, :run_queue, []}},
  ]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
