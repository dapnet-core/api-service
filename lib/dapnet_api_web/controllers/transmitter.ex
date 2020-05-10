defmodule DapnetApiWeb.TransmitterController do
  use DapnetApiWeb, :controller

  action_fallback DapnetApiWeb.FallbackController

  plug :permission_required, "transmitter.list" when action in [:list, :list_names, :map, :my]
  plug :permission_required, "transmitter.read" when action in [:show, :my_count, :count]
  plug :permission_required, "transmitter.create" when action in [:create]
  plug :permission_required, "transmitter.update" when action in [:update]
  plug :permission_required, "transmitter.delete" when action in [:delete]
  plug :permission_required, "transmitter_groups.list" when action in [:list_groups]

  defp db() do
    DapnetApi.CouchDB.db("transmitters")
  end

  defp db_view(name, options \\ %{}) do
    result = CouchDB.Database.view(db(), "transmitters", name, options)
    with {:ok, result} <- result do
      Poison.decode(result)
    end
  end

  defp db_list(name, view, options \\ %{}) do
    result = CouchDB.Database.list(db(), "transmitters", name, view, options)
    with {:ok, result} <- result do
      Poison.decode(result)
    end
  end

  def list(conn, _params) do
    options = %{"include_docs" => true, "limit" => 20, "reduce" => "false"}
    |> Map.merge(conn.query_params)

    with {:ok, transmitters} <- db_view("byId", options) do
      transmitters = update_transmitters(transmitters)
      json(conn, transmitters)
    end
  end

  def map(conn, _params) do
    options = %{"reduce" => "false"}
    |> Map.merge(conn.query_params)

    with {:ok, transmitters} <- db_view("map", options) do
      transmitters = update_transmitters_view(transmitters)
      json(conn, transmitters)
    end
  end

  def show(conn, %{"id" => id} = params) do
    with {:ok, transmitter} <- CouchDB.Database.get(db(), id) do
      transmitter = transmitter |> Poison.decode! |> update_transmitter(id)
      json(conn, transmitter)
    end
  end

  def create(conn, transmitter) do
    schema = DapnetApi.Transmitter.Schema.transmitter_schema
    user = conn.assigns[:login][:user]["_id"]

    case ExJsonSchema.Validator.validate(schema, transmitter) do
      :ok ->
        transmitter = if Map.has_key?(transmitter, "_rev") do
          id = Map.get(transmitter, "_id")

          {:ok, old_transmitter} = CouchDB.Database.get(db(), id)
          old_transmitter = old_transmitter |> Poison.decode!

          transmitter
          |> Map.put("created_on", Map.get(old_transmitter, "created_on"))
          |> Map.put("created_by", Map.get(old_transmitter, "created_by"))
          |> Map.put("changed_on", Timex.now())
          |> Map.put("changed_by", user)
        else
          transmitter = transmitter
          |> Map.update("_id", nil, &String.trim/1)
          |> Map.update("_id", nil, &String.downcase/1)
          |> Map.put("created_on", Timex.now())
          |> Map.put("created_by", user)
        end |> Poison.encode!

        {:ok, result} = CouchDB.Database.insert(db(), transmitter)

        conn
        |> put_resp_content_type("application/json")
        |> send_resp(200, transmitter)
      {:error, errors} ->
        conn |> put_status(400) |> json(%{"errors" => errors})
    end
  end

  def delete(conn, %{"id" => id, "revision" => revision} = params) do
    {:ok, transmitter} = CouchDB.Database.get(db(), id)
    transmitter = transmitter |> Poison.decode!
    # TODO: Check owner
    with {:ok, body} <- CouchDB.Database.delete(db(), id, revision) do
      conn
      |> put_resp_content_type("application/json")
      |> send_resp(200, body)
    end
  end

  def count(conn, _params) do
    options = %{"reduce" => true}

    with {:ok, result} <- db_view("byId", options) do
      count = result |> Map.get("rows") |> List.first |> Map.get("value")
      json(conn, %{count: count})
    end
  end

  def my(conn, _params) do
    options = %{"include_docs" => true, "limit" => 20, "reduce" => "false"}
    |> Map.put("startkey", Poison.encode!(conn.assigns[:login][:user]["_id"]))
    |> Map.put("endkey", Poison.encode!(conn.assigns[:login][:user]["_id"] <> "\ufff0"))
    |> Map.merge(conn.query_params)

    with {:ok, transmitters} <- db_view("byOwners", options) do
      transmitters = update_transmitters(transmitters)
      json(conn, transmitters)
    end
  end

  def my_count(conn, _params) do
    options = %{"reduce" => true}
    |> Map.put("startkey", Poison.encode!(conn.assigns[:login][:user]["_id"]))
    |> Map.put("endkey", Poison.encode!(conn.assigns[:login][:user]["_id"] <> "\ufff0"))

    with {:ok, result} <- db_view("byOwners", options) do
      count = result |> Map.get("rows") |> List.first |> Map.get("value")
      json(conn, %{count: count})
    end
  end

  def list_names(conn, _params) do
    with {:ok, result} <- db_list("names", "byId", %{"reduce" => false}) do
      json(conn, result)
    end
  end

  def list_groups(conn, _params) do
    options = %{"group_level" => 5}
    with {:ok, result} <- db_list("groups", "byGroup", options) do
      json(conn, result)
    end
  end

  defp update_transmitters(transmitters) do
    transmitters
    |> Map.update("rows", [], fn rows ->
      Enum.map(rows, fn row ->
        update_transmitter(Map.get(row, "doc"), Map.get(row, "id"))
      end)
    end)
  end

  defp update_transmitters_view(transmitters) do
    transmitters
    |> Map.update("rows", [], fn rows ->
      Enum.map(rows, fn row ->
        id = Map.get(row, "id")
        Map.update(row, "value", [], &(update_transmitter(&1, id)))
      end)
    end)
  end

  defp update_transmitter(transmitter, id) do
    status = DapnetApi.Transmitter.Database.get(id)
    online = status["last_seen"] != nil && Timex.diff(status["last_seen"], Timex.now(), :minutes) < 3
    status = Map.put(status, "online", online)
    Map.put(transmitter, "status", status)
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

  defp transmitter_auth(%{"callsign" => id, "auth_key" => auth_key} = params) do
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