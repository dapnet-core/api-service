defmodule DapnetWeb.RubricController do
  use DapnetWeb, :controller
  use DapnetWeb.Plugs.Database, name: "rubrics"

  action_fallback DapnetWeb.FallbackController

  def list(conn, _params) do
    options = %{"include_docs" => true, "limit" => 20, "reduce" => "false"}
    |> Map.merge(conn.query_params)

    with {:ok, rubrics} <- db_view("byId", options) do
      rubrics = Map.update(rubrics, "rows", [],
        &Enum.map(&1, fn row -> Map.get(row, "doc") end)
      )
      json(conn, rubrics)
    end
  end

  def list_names(conn, _params) do
    with {:ok, result} <- db_list("names", "byId", %{"reduce" => false}) do
      json(conn, result)
    end
  end

  def show(conn, %{"id" => id} = params) do
    with {:ok, rubric} <- db_get(id) do
      json(conn, rubric)
    end
  end

  def create(conn, rubric) do
    user = conn.assigns[:login][:user]["_id"]

    rubric = if Map.has_key?(rubric, "_rev") do
      id = Map.get(rubric, "_id")

      {:ok, old_rubric} = db_get(id)

      rubric
      |> Map.put("created_at", Map.get(old_rubric, "created_at"))
      |> Map.put("created_by", Map.get(old_rubric, "created_by"))
      |> Map.put("updated_at", Timex.now())
      |> Map.put("updated_by", user)
    else
      rubric = rubric
      |> Map.update("_id", nil, &String.trim/1)
      |> Map.update("_id", nil, &String.downcase/1)
      |> Map.put("created_at", Timex.now())
      |> Map.put("created_by", user)
    end |> Jason.encode!

    {:ok, result} = Database.insert(db(), rubric)

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, rubric)
  end

  def delete(conn, %{"id" => id, "revision" => revision} = params) do
    {:ok, rubric} = db_get(id)

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

    with {:ok, rubrics} <- db_view("byOwners", options) do
      rubrics = Map.update(rubrics, "rows", [],
        &Enum.map(&1, fn row -> Map.get(row, "doc") end)
      )
      json(conn, rubrics)
    end
  end

  def my_count(conn, _params) do
    options = %{"reduce" => true}
    |> Map.put("startkey", Jason.encode!(conn.assigns[:login][:user]["_id"]))
    |> Map.put("endkey", Jason.encode!(conn.assigns[:login][:user]["_id"] <> "\ufff0"))

    with {:ok, result} <- db_view("byOwners", options) do
      count = result |> Map.get("rows") |> List.first |> Map.get("value")
      json(conn, %{count: count})
    end
  end
end