defmodule Dapnet.Cluster.Replication do
  use GenServer
  require Logger

  @databases ["users", "transmitters", "subscribers", "rubrics", "news", "nodes"]
  def start_link do
    GenServer.start_link(__MODULE__, [], [name: __MODULE__])
  end

  def update() do
    GenServer.call(__MODULE__, :update)
  end

  def init(_opts) do
    {:ok, nil}
  end

  def handle_call(:update, _from, state) do
    Dapnet.Cluster.Discovery.reachable_nodes()
    |> Enum.filter(fn {_, params} -> Map.get(params, "couchdb") != nil end)
    |> Enum.each(fn {node, params} -> Dapnet.Cluster.CouchDB.sync_with(node, params) end)
    {:reply, :ok, state}
  end
end
