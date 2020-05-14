defmodule DapnetWeb.Plugs.BasicAuth do
  import Plug.Conn
  @realm "Basic realm=\"Login\""

  def init(opts), do: opts

  def call(conn, _) do
    case get_req_header(conn, "authorization") do
      ["Basic " <> auth] -> verify(conn, auth)
      _ -> conn
    end
  end

  defp verify(conn, auth) do
    [username, password] = auth |> Base.decode64!() |> String.split(":")

    user = Dapnet.Auth.login(%{"username" => username, "password" => password})

    if user do
      roles = Map.get(user, "roles")
      permissions = Dapnet.Auth.Permissions.all(roles)

      result = %{
        user: user,
        permissions: permissions
      }

      Plug.Conn.assign(conn, :login, result)
    else
      unauthorized(conn)
    end
  end

  defp unauthorized(conn) do
    conn
    |> put_resp_header("www-authenticate", @realm)
    |> send_resp(401, "Unauthorized")
    |> halt()
  end
end