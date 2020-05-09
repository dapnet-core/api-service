defmodule DapnetApiWeb.Plugs.Auth do
  import Plug.Conn
  import Phoenix.Controller
  @realm "Basic realm=\"Login\""

  def auth_required(conn, _) do
    if conn.assigns[:login] do
      conn
    else
      conn |> unauthorized
    end
  end

  def permission_required(conn, action) do
    case conn.assigns[:login] do
      %{:permissions => permissions} ->
        IO.inspect(permissions)
        IO.inspect(action)
        if Map.get(permissions, action) == :all do
          conn
        else
          conn |> forbidden
        end
      test ->
        IO.inspect(test)
        conn |> unauthorized
    end
  end

  defp forbidden(conn) do
    conn
    |> send_resp(403, "Forbidden")
    |> halt()
  end

  defp unauthorized(conn) do
    conn
    |> put_resp_header("www-authenticate", @realm)
    |> send_resp(401, "Unauthorized")
    |> halt()
  end
end