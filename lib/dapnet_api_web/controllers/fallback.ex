defmodule DapnetApiWeb.FallbackController do
  use Phoenix.Controller

  def call(conn, {:error, reason}) do
    conn |> send_resp(404, "Not Found")
  end
end