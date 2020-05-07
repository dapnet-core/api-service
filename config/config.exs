# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
use Mix.Config

# Configures the endpoint
config :dapnet_api, DapnetApiWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "GOk/2pbQQKxjAypc6di6KaOm0tnD8d39q7wwqoTZKpemeNBBRWXoURMpOg32/UUF",
  render_errors: [view: DapnetApiWeb.ErrorView, accepts: ~w(json), layout: false],
  pubsub_server: DapnetApi.PubSub,
  live_view: [signing_salt: "PPRP9iCm"],
  http: [dispatch: [
	{:_, [
     {"/telemetry", DapnetApi.Telemetry.Websocket, :all},
     {"/telemetry/transmitters/:id", DapnetApi.Telemetry.Websocket, :transmitter},
     {"/telemetry/nodes/:id", DapnetApi.Telemetry.Websocket, :node},
     {:_, Phoenix.Endpoint.Cowboy2Handler, {DapnetApiWeb.Endpoint, []}}
   ]}]]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

config :dapnet_api, DapnetApi.Cluster.Discovery,
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

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
