defmodule DapnetWeb.CallController do
  use DapnetWeb, :controller

  require Ecto.Query
  alias Dapnet.Call
  alias Dapnet.Repo

  plug :permission_required, "call.list" when action in [:list]
  plug :permission_required, "call.show" when action in [:read]
  plug :permission_required, "call.create" when action in [:create]

  def index(conn, params) do
    limit = Map.get(params, "limit", 20)

    calls = Call
    |> Ecto.Query.order_by(desc: :created_at)
    |> Ecto.Query.limit(20)
    |> Repo.all()
    json(conn, calls)
  end

  def show(conn, %{"id" => id} = params) do
    call = Repo.get(Call, id)
    json(conn, call)
  end

  def count(conn, _params) do
    count = Repo.aggregate(Call, :count, :id)
    json(conn, %{"count": count})
  end

  def create(conn, call) do
    user = conn.assigns[:login][:user]["_id"]
    schema = Dapnet.Call.Schema.call_schema

    case ExJsonSchema.Validator.validate(schema, call) do
      :ok ->
        call = call
        |> Map.put("id", uuid())
        |> Map.put("origin", origin())
        |> Map.put("created_at", Timex.now())
        |> Map.put("created_by", user)

        json_call = Jason.encode!(call)

        if Map.get(call, "local", false) do
          changeset = Dapnet.Call.changeset(%Dapnet.Call{}, call)

          case Dapnet.Repo.insert(changeset) do
            {:ok, result} ->
              Dapnet.Call.Dispatcher.dispatch(call)

            {:error, changeset} ->
              IO.inspect(changeset)
          end
        else
          Dapnet.Call.RabbitMQ.publish_call(json_call)
        end

        conn
        |> put_resp_content_type("application/json")
        |> send_resp(200, json_call)
      {:error, errors} ->
        conn |> put_status(400) |> json(%{"errors" => errors})
    end
  end

  def delete(conn, %{"id" => id} = params) do
    call = Repo.get(Call, id)

    case Repo.delete call do
      {:ok, struct} -> json(conn, %{"status": "ok"})
      {:error, changeset} -> json(conn, %{"status": "error"})
    end
  end

  defp uuid() do
    UUID.uuid1()
  end

  defp origin() do
    System.get_env("NODE_NAME")
  end
end