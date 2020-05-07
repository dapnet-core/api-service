defmodule DapnetApiWeb.Plugs.Auth do
  import Plug.Conn
  import Phoenix.Controller

  def auth_required(conn, _) do
    if conn.assigns[:login] do
      conn
    else
      conn |> forbidden
    end
  end

  defp forbidden(conn) do
    conn
    |> send_resp(403, "Forbidden")
    |> halt()
  end
end