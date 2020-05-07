defmodule DapnetApiWeb.Router do
  use DapnetApiWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
    plug DapnetApiWeb.Plugs.BasicAuth
  end

  scope "/", DapnetApiWeb do
    pipe_through :api

    post "/cluster/discovery", ClusterController, :discovery
    get "/cluster/nodes", ClusterController, :nodes
    get "/cluster/reachable_nodes", ClusterController, :reachable_nodes

    get "/auth/users/roles", AuthController, :users_roles
    post "/auth/users/login", AuthController, :users_login
    post "/auth/users/permission/:action", AuthController, :users_permission
    post "/auth/users/permission/:action/:id", AuthController, :users_permission

    get "/auth/rabbitmq/user", AuthController, :rabbitmq_user
    get "/auth/rabbitmq/vhost", AuthController, :rabbitmq_vhost
    get "/auth/rabbitmq/resource", AuthController, :rabbitmq_resource
    get "/auth/rabbitmq/topic", AuthController, :rabbitmq_topic

    post "/calls", CallController, :calls_create
    get "/calls", CallController, :calls_list
    get "/calls/:id", CallController, :calls_show

    post "/transmitters/_bootstrap", TransmitterController, :bootstrap
    post "/transmitters/_heartbeat", TransmitterController, :heartbeat
    get "/transmitters", TransmitterController, :transmitters_list
    get "/transmitters/_map", TransmitterController, :transmitters_map
    get "/transmitters/:id", TransmitterController, :transmitters_show
  end

  # Enables LiveDashboard only for development
  #
  # If you want to use the LiveDashboard in production, you should put
  # it behind authentication and allow only admins to access it.
  # If your application does not have an admins-only section yet,
  # you can use Plug.BasicAuth to set up some basic authentication
  # as long as you are also using SSL (which you should anyway).
  if Mix.env() in [:dev, :test] do
    import Phoenix.LiveDashboard.Router

    scope "/" do
      pipe_through [:fetch_session, :protect_from_forgery]
      live_dashboard "/dashboard", metrics: DapnetApiWeb.Telemetry
    end
  end
end
