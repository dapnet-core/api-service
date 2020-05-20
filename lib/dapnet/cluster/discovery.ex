defmodule Dapnet.Cluster.Discovery do
  use GenServer
  require Logger

  def nodes, do: GenServer.call(__MODULE__, :nodes)
  def reachable_nodes, do: GenServer.call(__MODULE__, :reachable_nodes)
  def update, do: GenServer.call(__MODULE__, :update)

  def start_link do
    GenServer.start_link(__MODULE__, [], [name: __MODULE__])
  end

  def init(_opts) do
    name = System.get_env("NODE_NAME")
    Logger.info("Node name: #{name}")

    nodes = Application.get_env(:dapnet, __MODULE__)[:seed]
    |> Enum.filter(fn {node, _} -> node != name end)
    |> Enum.map(fn {node, params} -> {node,
         Map.merge(params, %{"last_seen" => nil, "reachable" => false})}
       end)
    |> Map.new()

    Logger.info("Initial node list: #{inspect nodes}")

    {:ok, {nodes, %{}}}
  end

  def handle_call(:update, _from, {nodes, requests}) do
    Logger.info("Starting node discovery.")
    body = %{
      name: System.get_env("NODE_NAME"),
      auth_key: System.get_env("NODE_AUTHKEY")
    } |> Jason.encode!

    requests = Enum.map(nodes, fn {node, params} ->
      host = params["host"]

      %HTTPoison.AsyncResponse{:id => id} = HTTPoison.post!("#{host}/cluster/discovery", body,
        [{"content-type", "application/json"}],
        [
          recv_timeout: 5000,
          timeout: 5000,
          stream_to: self()
        ])

      {id, node}
    end)
    |> Map.new()
    |> Map.merge(requests)

    {:reply, :ok, {nodes, requests}}
  end

  def handle_info(%HTTPoison.AsyncStatus{}, state) do
    {:noreply, state}
  end

  def handle_info(%HTTPoison.AsyncHeaders{}, state) do
    {:noreply, state}
  end

  def handle_info(%HTTPoison.AsyncEnd{:id => id}, {nodes, requests}) do
    {node_name, requests} = Map.pop(requests, id)
    {:noreply, {nodes, requests}}
  end

  def handle_info(%HTTPoison.Error{:id => id} = e, {nodes, requests}) do
    {node_name, requests} = Map.pop(requests, id)

    Logger.warn("Could not reach #{node_name}!")

    nodes = Map.update!(nodes, node_name, fn node ->
      %{node | "reachable" => false}
    end)

    {:noreply, {nodes, requests}}
  end

  def handle_info(%HTTPoison.AsyncChunk{"chunk": chunk, "id": id}, {nodes, requests}) do
    node_name = Map.get(requests, id)

    nodes = if node_name do
      node = Map.get(nodes, node_name)

      case Jason.decode(chunk) do
        {:ok, data} ->
          node_data = Map.get(data, node_name)

          if node_data do
            Logger.info("Reached #{node_name}!")
            Map.put(nodes, node_name, node_data)
          else
            Logger.warn("Could not read response from #{node_name}!")
            nodes
          end
        _ ->
          Logger.warn("Could not decode response from #{node_name}!")
          nodes
      end
    else
      nodes
    end

    {:noreply, {nodes, requests}}
  end

  def handle_call(:nodes, _from, {nodes, _} = state) do
    name = System.get_env("NODE_NAME")

    all_nodes = nodes |> Map.put(name, %{
      "host" => System.get_env("NODE_HOSTNAME"),
      "reachable" => true,
      "last_seen" => Timex.now(),
      "couchdb" => %{
        "user" => System.get_env("COUCHDB_USER"),
        "password" => System.get_env("COUCHDB_PASSWORD"),
      }
    })

    {:reply, all_nodes, state}
  end

  def handle_call(:reachable_nodes, _from, {nodes, _} = state) do
    reachable_nodes = nodes
    |> Enum.filter(fn {_, params} -> Map.get(params, "reachable") end)

    {:reply, reachable_nodes, state}
  end
end
