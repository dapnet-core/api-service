defmodule DapnetWeb.SubscriberController do
  use DapnetWeb, :controller
  use DapnetWeb.Plugs.Database, name: "subscribers"

  action_fallback DapnetWeb.FallbackController

  plug :permission_required, "subscriber.list" when action in [:list]

  def list(conn, _params) do
    options = %{"include_docs" => true, "limit" => 20, "reduce" => "false"}
    |> Map.merge(conn.query_params)

    with {:ok, subscribers} <- db_view("byId", options) do
      subscribers = Map.update(subscribers, "rows", [],
        &Enum.map(&1, fn row -> Map.get(row, "doc") end)
      )
      json(conn, subscribers)
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

  def show(conn, %{"id" => id} = params) do
    with {:ok, subscriber} <- db_get(id) do
      json(conn, subscriber)
    end
  end

  def create(conn, subscriber) do
    schema = Dapnet.Subscriber.Schema.subscriber_schema
    user = conn.assigns[:login][:user]["_id"]

    case ExJsonSchema.Validator.validate(schema, subscriber) do
      :ok ->
        subscriber = if Map.has_key?(subscriber, "_rev") do
          id = Map.get(subscriber, "_id")

          {:ok, old_subscriber} = db_get(id)

          subscriber
          |> Map.put("created_at", Map.get(old_subscriber, "created_at"))
          |> Map.put("created_by", Map.get(old_subscriber, "created_by"))
          |> Map.put("updated_at", Timex.now())
          |> Map.put("updated_by", user)
        else
          subscriber
          |> Map.update("_id", nil, &String.trim/1)
          |> Map.update("_id", nil, &String.downcase/1)
          |> Map.put("created_at", Timex.now())
          |> Map.put("created_by", user)
        end |> Jason.encode!

        {:ok, result} = Database.insert(db(), subscriber)

        conn
        |> put_resp_content_type("application/json")
        |> send_resp(200, subscriber)
      {:error, errors} ->
        conn |> put_status(400) |> json(%{"errors" => errors})
    end
  end

  def delete(conn, %{"id" => id, "revision" => revision} = params) do
    {:ok, subscriber} = db_get(id)

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

    with {:ok, subscribers} <- db_view("byOwners", options) do
      subscribers = Map.update(subscribers, "rows", [],
        &Enum.map(&1, fn row -> Map.get(row, "doc") end)
      )
      json(conn, subscribers)
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