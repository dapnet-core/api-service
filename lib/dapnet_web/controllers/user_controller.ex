defmodule DapnetWeb.UserController do
  use DapnetWeb, :controller
  use DapnetWeb.Plugs.Database, name: "users"

  action_fallback DapnetWeb.FallbackController

  plug :permission_required, "user.list" when action in [:list, :list_names, :count, :avatar]
  plug :permission_required, "user.create" when action in [:create]
  plug :permission_required, "user.update" when action in [:update]
  plug :permission_required, "user.delete" when action in [:delete]

  def list(conn, _params) do
    options = %{"include_docs" => true, "limit" => 20, "reduce" => "false"}
    |> Map.merge(conn.query_params)

    with {:ok, users} <- db_view("byId", options) do
      users = Map.update(users, "rows", [],
        &Enum.map(&1, fn row ->
          Map.get(row, "doc")
          |> Map.delete("password")
        end)
      )
      json(conn, users)
    end
  end
  
  def list_usernames(conn, _params) do
    with {:ok, result} <- db_list("usernames", "byId", %{"reduce" => false}) do
      json(conn, result)
    end
  end
  
  def count(conn, _params) do
    options = %{"reduce" => true}

    with {:ok, result} <- db_view("byId", options) do
      count = result |> Map.get("rows") |> List.first |> Map.get("value")
      json(conn, %{count: count})
    end
  end
  
  def show(conn, %{"id" => id} = params) do
    with {:ok, user} <- db_get(id) do
      user = user |> Map.delete("password")
      json(conn, user)
    end
  end
  
  def avatar(conn, %{"id" => id} = params) do
    with {:ok, avatar} <- db_get_attachment(id, "avatar.jpg") do
      conn
      |> put_resp_content_type("image/jpeg")
      |> send_resp(200, avatar)
    end
  end

  def create(conn, user) do
    schema = Dapnet.User.Schema.user_schema
    curr_user_id = conn.assigns[:login][:user]["_id"]

    case ExJsonSchema.Validator.validate(schema, user) do
      :ok ->
        user = if Map.has_key?(user, "_rev") do
          id = Map.get(user, "_id")

          {:ok, old_user} = Database.get(db(), id)
          old_user = old_user |> Jason.decode!
          
          user
          |> Map.put("created_at", Map.get(old_user, "created_at"))
          |> Map.put("created_by", Map.get(old_user, "created_by"))
          |> Map.put("updated_at", Timex.now())
          |> Map.put("updated_by", curr_user_id)
        else
          user
          |> Map.update("_id", nil, &String.trim/1)
          |> Map.update("_id", nil, &String.downcase/1)
          |> Map.put("created_at", Timex.now())
          |> Map.put("created_by", curr_user_id)
        end |> Jason.encode!

        {:ok, result} = Database.insert(db(), user)

        conn
        |> put_resp_content_type("application/json")
        |> send_resp(200, user)
      {:error, errors} ->
        conn |> put_status(400) |> json(%{"errors" => errors})
    end
  end

  def delete(conn, %{"id" => id, "revision" => revision} = params) do
    with {:ok, body} <- Database.delete(db(), id, revision) do
      conn
      |> put_resp_content_type("application/json")
      |> send_resp(200, body)
    end
  end
end