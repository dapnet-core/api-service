defmodule DapnetWeb.NewsController do
  use DapnetWeb, :controller
  use DapnetWeb.Plugs.Database, name: "news"

  action_fallback DapnetWeb.FallbackController

  def list(conn, %{"rubric_id" => rubric_id} = params) do
    with {:ok, news} <- db_get(rubric_id) do
      json(conn, news)
    end
  end

  def show(conn, %{"rubric_id" => rubric_id, "id" => id} = params) do
    with {:ok, news} <- db_get(rubric_id) do
      items = Map.get(news, "items", [])
      id = String.to_integer(id) - 1
      json(conn, items |> Enum.at(id))
    end
  end

  def create(conn, news, %{"rubric_id" => rubric_id} = params) do
    user = conn.assigns[:login][:user]["_id"]

    news = if Map.has_key?(news, "_rev") do
      news
      |> Map.put("updated_at", Timex.now())
      |> Map.put("updated_by", user)
    else
      news
      |> Map.update("_id", nil, &String.trim/1)
      |> Map.update("_id", nil, &String.downcase/1)
    end |> Jason.encode!

    {:ok, result} = Database.insert(db(), news)

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, news)
  end

  def update(conn, item) do
    user = conn.assigns[:login][:user]["_id"]

    {rubric_id, item} = Map.pop(item, "rubric_id")
    {id, item} = Map.pop(item, "id")

    with {:ok, news} <- db_get(rubric_id) do
      id = String.to_integer(id) - 1

      news = Map.update(news, "items", [], fn items ->
        items
        |> Stream.concat(Stream.cycle([nil]))
        |> Enum.take(10)
        |> List.replace_at(id, item)
      end) |> Jason.encode!

      {:ok, result} = Database.insert(db(), news)

      json(conn, news)
    end
  end
end