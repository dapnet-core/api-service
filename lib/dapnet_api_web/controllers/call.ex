defmodule DapnetApiWeb.CallController do
  use DapnetApiWeb, :controller

  plug :permission_required, "call.list" when action in [:list]
  plug :permission_required, "call.show" when action in [:read]
  plug :permission_required, "call.create" when action in [:create]

  def list(conn, params) do
    case DapnetApi.Call.Database.list() do
      nil ->
      	conn |> put_status(404) |> json(%{"error" => "Not found"})
      result ->
        json(conn, result)
    end
  end

  def show(conn, %{"id" => id} = params) do
    case DapnetApi.Call.Database.read(id) do
      nil ->
      	conn |> put_status(404) |> json(%{"error" => "Not found"})
      result ->
      	json(conn, result)
    end
  end

  def create(conn, params) do
    schema = DapnetApi.Call.Schema.call_schema
    call = conn.body_params
    user = conn.assigns[:login][:user]["_id"]

    case ExJsonSchema.Validator.validate(schema, call) do
      :ok ->
        call = call
        |> Map.put("id", uuid())
        |> Map.put("origin", origin())
        |> Map.put("created_on", Timex.now())
        |> Map.put("created_by", user)

        json_call = Poison.encode!(call)

        if Map.get(call, "local", false) do
          DapnetApi.Call.Dispatcher.dispatch(call)
        else
          DapnetApi.Call.RabbitMQ.publish_call(json_call)
        end

        conn
        |> put_resp_content_type("application/json")
        |> send_resp(200, json_call)
      {:error, errors} ->
        conn |> put_status(404) |> json(%{"errors" => errors})
    end
  end

  defp uuid() do
    UUID.uuid1()
  end

  defp origin() do
    System.get_env("NODE_NAME")
  end
end