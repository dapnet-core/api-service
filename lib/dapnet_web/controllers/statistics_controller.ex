defmodule DapnetWeb.StatisticsController do
  use DapnetWeb, :controller

  alias Dapnet.Repo
  alias Dapnet.Transmitter
  alias Dapnet.Call

  def statistics(conn, _params) do
    node_name = System.get_env("NODE_NAME")
    node_hostname = System.get_env("NODE_HOSTNAME")

    transmitters = Repo.all(Transmitter.online())

    local_transmitters = Enum.count(transmitters, fn tx ->
      tx.node == node_name
    end)
    remote_transmitters = Enum.count(transmitters) - local_transmitters

    nodes = Dapnet.Cluster.Discovery.nodes()

    reachable_nodes = Enum.count(nodes, fn {_, params} ->
      Map.get(params, "reachable")
    end)
    unreachable_nodes = Enum.count(nodes) - reachable_nodes

    calls = Repo.all(Call)
    local_calls = Enum.count(calls, fn call ->
      call.origin == node_name
    end)
    remote_calls = Enum.count(calls) - local_calls

    json(conn, %{
      "node" => %{
        "name" => node_name,
        "hostname" => node_hostname
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