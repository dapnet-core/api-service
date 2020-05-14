defmodule DapnetWeb.ClusterController do
  use DapnetWeb, :controller

  def discovery(conn, params) do
    node = params |> Map.get("name")
    auth_key = params |> Map.get("auth_key")

    if Dapnet.Cluster.CouchDB.auth(node, auth_key) do
      nodes = Dapnet.Cluster.Discovery.nodes()
      json(conn, nodes)
    end
  end

  def nodes(conn, _params) do
    nodes = Dapnet.Cluster.Discovery.nodes()
    |> Stream.map(fn {id, node} ->
      {id, Map.delete(node, "couchdb")}
    end)
    |> Map.new

    json(conn, nodes)
  end

  def reachable_nodes(conn, _params) do
    nodes = Dapnet.Cluster.Discovery.reachable_nodes()
    |> Stream.map(fn {id, node} ->
      {id, Map.delete(node, "couchdb")}
    end)
    |> Map.new

    json(conn, nodes)
  end

end