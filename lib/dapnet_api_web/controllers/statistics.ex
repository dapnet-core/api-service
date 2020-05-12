defmodule DapnetApiWeb.StatisticsController do
  use DapnetApiWeb, :controller

  def statistics(conn, _params) do
    node_name = System.get_env("NODE_NAME")
    node_hostname = System.get_env("NODE_HOSTNAME")

    transmitters = DapnetApi.Transmitter.Database.list_connected()

    local_transmitters = Enum.count(transmitters, fn tx ->
      Map.get(tx, "node") == node_name
    end)
    remote_transmitters = Enum.count(transmitters) - local_transmitters

    nodes = DapnetApi.Cluster.Discovery.nodes()

    reachable_nodes = Enum.count(nodes, fn {_, params} ->
      Map.get(params, "reachable")
    end)
    unreachable_nodes = Enum.count(nodes) - reachable_nodes

    calls = DapnetApi.Call.Database.list()
    local_calls = Enum.count(calls, fn call ->
      Map.get(call, "origin") == node_name
    end)
    remote_calls = Enum.count(calls) - local_calls

    json(conn, %{
      "node" => %{
        "name" => node_name,
        "host" => node_hostname
      },
      "transmitters" => %{
        "connected" => %{
          "local" => local_transmitters,
          "remote" => remote_transmitters
        }
      },
      "nodes" => %{
        "reachable" => reachable_nodes,
        "unreachable" => unreachable_nodes
      },
      "calls" => %{
        "local" => local_calls,
        "remote" => remote_calls
      }
    })
  end
end