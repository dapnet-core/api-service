defmodule DapnetApiWeb.StatisticsController do
  use DapnetApiWeb, :controller

  def statistics(conn, _params) do
    node_name = System.get_env("NODE_NAME")
    node_hostname = System.get_env("NODE_HOSTNAME")

    transmitters = DapnetApi.Transmitter.Database.list_connected()

    local_transmitters = Enum.count(transmitters, fn tx ->
      Map.get(tx, "node") == node_name
    end)
    total_transmitters = Enum.count(transmitters)

    nodes = DapnetApi.Cluster.Discovery.nodes()

    reachable_nodes = Enum.count(nodes, fn {_, params} ->
      Map.get(params, "reachable")
    end)
    total_nodes = Enum.count(nodes)

    calls = DapnetApi.Call.Database.list()
    local_calls = Enum.count(calls, fn call ->
      Map.get(call, "origin") == node_name
    end)
    total_calls  = Enum.count(calls)

    json(conn, %{
      "node" => %{
        "name" => node_name,
        "host" => node_hostname
      },
      "transmitters" => %{
        "connected" => %{
          "local" => local_transmitters,
          "total" => total_transmitters
        }
      },
      "nodes" => %{
        "reachable" => reachable_nodes,
        "total" => total_nodes
      },
      "calls" => %{
        "local" => local_calls,
        "total" => total_calls
      }
    })
  end
end