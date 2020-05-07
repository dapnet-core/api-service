defmodule DapnetApiWeb.TransmitterController do
  use DapnetApiWeb, :controller

  def transmitters_list(conn, params) do
    options = %{"include_docs" => true, "limit" => 20, "reduce" => "false"}
    |> Map.merge(conn.query_params)

    {:ok, results} = DapnetApi.CouchDB.db("transmitters")
    |> CouchDB.Database.view("transmitters", "byId", options)

    transmitters = results
    |> Poison.decode!
    |> Map.update("rows", [], fn rows ->
      Enum.map(rows, &(Map.get(&1, "doc")))
      |> Enum.map(fn transmitter ->
        status = DapnetApi.Transmitter.Database.get(transmitter["_id"])
        online = status["last_seen"] != nil && Timex.diff(status["last_seen"], Timex.now(), :minutes) < 2
        status = Map.put(status, "online", online)
        Map.put(transmitter, "status", status)
      end)
    end)

    json(conn, transmitters)
  end

  def transmitters_map(conn, params) do
    {:ok, results} = DapnetApi.CouchDB.db("transmitters")
    |> CouchDB.Database.view("transmitters", "map")
    
    transmitters = results |> Poison.decode!

    json(conn, transmitters)
  end

  def transmitters_show(conn, %{"id" => id} = params) do
    result = DapnetApi.CouchDB.db("transmitters")
    |> CouchDB.Database.get(id)

    case result do
      {:ok, data} ->
        transmitter = data |> Poison.decode!
        json(conn, transmitter)
      _ ->
        send_resp(conn, 404, "Not found")
    end
  end

  def bootstrap(conn, params) do
    transmitter = transmitter_auth(params)

    if transmitter do
      nodes = case HTTPoison.get("http://cluster/cluster/nodes") do
                {:ok, response} -> Poison.decode!(response.body)
                _ -> %{}
              end

      response = %{
        "timeslots" => Map.get(transmitter, "timeslots"),
        "nodes" => nodes
      }

      ip_addr = Plug.Conn.get_req_header(conn, "x-forwarded-for")

      data = %{
        "_id" => transmitter["_id"],
        "node" => System.get_env("NODE_NAME"),
        "connected_since" => Timex.now(),
        "last_seen" => Timex.now(),
        "addr" => ip_addr,
        "software" => Map.get(params, "software"),
      }

      data = DapnetApi.Transmitter.Database.update(transmitter["_id"], data)
      DapnetApi.Transmitter.RabbitMQ.publish_heartbeat(data)

      json(conn, response)
    else
      send_resp(conn, 403, "Forbidden")
    end
  end

  def heartbeat(conn, params) do
    transmitter = transmitter_auth(params)

    if transmitter do
      ip_addr = Plug.Conn.get_req_header(conn, "x-forwarded-for")

      data = %{
        "last_seen" => Timex.now(),
        "addr" => ip_addr
      }

      data = DapnetApi.Transmitter.Database.update(transmitter["_id"], data)
      DapnetApi.Transmitter.RabbitMQ.publish_heartbeat(data)

      json(conn, %{"status" => "ok"})
    else
      send_resp(conn, 403, "Forbidden")
    end
  end

  def transmitter_auth(%{"callsign" => id, "auth_key" => auth_key} = params) do
    if id != nil and auth_key != nil do
      db = DapnetApi.CouchDB.db("transmitters")
      case CouchDB.Database.get(db, id) do
        {:ok, result} ->
          transmitter = result |> Poison.decode!
          {correct_auth_key, transmitter} = transmitter |> Map.pop("auth_key")

          if auth_key == correct_auth_key do
            transmitter
          else
            nil
          end
        _ ->
          nil
      end
    else
      nil
    end
  end
end