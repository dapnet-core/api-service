defmodule DapnetApiWeb.AuthController do
  use DapnetApiWeb, :controller

  def users_roles(conn, params) do
    roles = DapnetApi.Auth.Permissions.roles()
    json(conn, roles)
  end

 def users_login(conn, params) do
    user = DapnetApi.Auth.login(params)

    if user do
      roles = Map.get(user, "roles")
      permissions = DapnetApi.Auth.Permissions.all(roles)

      response = %{
        user: user,
        permissions: permissions
      }

      json(conn, response)
    else
      conn |> put_status(403) |> text("Forbidden")
    end
  end

  def users_permission(conn, %{"action" => action, "id" => id} = params) do
    user = DapnetApi.Auth.login(params)

    roles = if user do
      Map.get(user, "roles", ["user"])
    else
      ["guest"]
    end

    permission = DapnetApi.Auth.Permissions.query(roles, action)

    response = case permission do
      :if_owner -> %{
                   access: id && Map.get(user, "_id") == id,
                   authenticated: user != nil,
                   roles: roles
               }
      :limited -> %{
                  access: permission != :none,
                  authenticated: user != nil,
                  roles: roles,
                  limited_to: ["_id"]
              }
      _ -> %{
           access: permission != :none,
           roles: roles,
           authenticated: user != nil
       }
    end

    json(conn, response)
  end

  def rabbitmq_user(conn, params) do
    user = Map.get(params, "username")
    pass = Map.get(params, "password")

    case user do
      "node-" <> node_id ->
        db = DapnetApi.CouchDB.db("nodes")

        case CouchDB.Database.get(db, node_id) do
        {:ok, result} ->
          auth_key = result |> Poison.decode! |> Map.get("auth_key")
          if pass == auth_key do
            text(conn, "allow administrator")
          else
            text(conn, "deny")
          end
          _ ->
            text(conn, "deny")
        end

      "tx-" <> tx_id ->
        db = DapnetApi.CouchDB.db("transmitters")

        case CouchDB.Database.get(db, tx_id) do
          {:ok, result} ->
            auth_key = result |> Poison.decode! |> Map.get("auth_key")
            if pass == auth_key do
              text(conn, "allow")
            else
              text(conn, "deny")
            end
          _ ->
            text(conn, "deny")
        end

      "thirdparty-" <> user ->
        db = DapnetApi.CouchDB.db("users")

        case CouchDB.Database.get(db, user) do
          {:ok, result} ->
            user = result |> Poison.decode!
            {hash, user} = user |> Map.pop("password")

            if hash && Comeonin.Bcrypt.checkpw(pass, hash) do
              is_thirdparty = Map.get(user, "roles", [])
              |> Enum.any?(fn role -> String.starts_with?(role, "thirdparty.") end)

              if is_thirdparty do
                text(conn, "allow")
              else
                text(conn, "deny")
              end
            else
              text(conn, "deny")
            end
          _ ->
            text(conn, "deny")
        end

     _ -> text(conn, "deny")
    end
  end

  def rabbitmq_vhost(conn, params) do
    user = Map.get(params, "username")

    case user do
      "node-" <> node_id -> text(conn, "allow")
      _ -> text(conn, "allow")
    end
  end

  def rabbitmq_resource(conn, params) do
    user = Map.get(params, "username")

    case user do
      "node-" <> node_id -> text(conn, "allow")
      _ -> text(conn, "allow")
    end

  end

  def rabbitmq_topic(conn, params) do
    user = Map.get(params, "username")

    case user do
      "node-" <> node_id -> text(conn, "allow")
      _ -> text(conn, "allow")
    end
  end
end