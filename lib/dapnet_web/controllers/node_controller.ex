defmodule DapnetWeb.NodeController do
  use DapnetWeb, :controller
  use DapnetWeb.Plugs.Database, name: "nodes"

  action_fallback DapnetWeb.FallbackController

  def list(conn, _params) do
    options = %{"include_docs" => true, "limit" => 20, "reduce" => "false"}
    |> Map.merge(conn.query_params)

    with {:ok, nodes} <- db_view("byId", options) do
      nodes = Map.update(nodes, "rows", [],
        &Enum.map(&1, fn row -> Map.get(row, "doc") end)
      )
      json(conn, nodes)
    end
  end

  def list_names(conn, _params) do
    with {:ok, result} <- db_list("names", "byId", %{"reduce" => false}) do
      json(conn, result)
    end
  end

  def show(conn, %{"id" => id} = params) do
    with {:ok, node} <- db_get(id) do
      json(conn, node)
    end
  end

  def create(conn, node) do
    user = conn.assigns[:login][:user]["_id"]

    node = if Map.has_key?(node, "_rev") do
      id = Map.get(node, "_id")

      {:ok, old_node} = db_get(id)

      node
      |> Map.put("created_at", Map.get(old_node, "created_at"))
      |> Map.put("created_by", Map.get(old_node, "created_by"))
      |> Map.put("updated_at", Timex.now())
      |> Map.put("updated_by", user)
    else
      node
      |> Map.update("_id", nil, &String.trim/1)
      |> Map.update("_id", nil, &String.downcase/1)
      |> Map.put("created_at", Timex.now())
      |> Map.put("created_by", user)
    end |> Jason.encode!

    {:ok, result} = Database.insert(db(), node)

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, node)
  end

  def delete(conn, %{"id" => id, "revision" => revision} = params) do
    {:ok, node} = db_get(id)

    # TODO: Check owner
    with {:ok, body} <- Database.delete(db(), id, revision) do
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
    |> Map.put("startkey", Jason.encode!(conn.assigns[:login][:user]["_id"]))
    |> Map.put("endkey", Jason.encode!(conn.assigns[:login][:user]["_id"] <> "\ufff0"))
    |> Map.merge(conn.query_params)

    with {:ok, nodes} <- db_view("byOwners", options) do
      nodes = Map.update(nodes, "rows", [],
        &Enum.map(&1, fn row -> Map.get(row, "doc") end)
      )
      json(conn, nodes)
    end
  end

  def my_count(conn, _params) do
    options = %{"reduce" => true}
    |> Map.put("startkey", Jason.encode!(conn.assigns[:login][:user]["_id"]))
    # "\ufff0" -> See https://docs.couchdb.org/en/latest/ddocs/views/collation.html#raw-collation
    |> Map.put("endkey", Jason.encode!(conn.assigns[:login][:user]["_id"] <> "\ufff0"))

    with {:ok, result} <- db_view("byOwners", options) do
      with [head | _tail] <- Map.get(result, "rows") do
        json(conn, %{count: Map.get(head, "value")})
      else # "rows" is empty
        _rows -> json(conn, %{count: 0})
      end
    end
  end
end
