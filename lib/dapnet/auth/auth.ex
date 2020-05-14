defmodule Dapnet.Auth do
  def login(%{"username" => user, "password" => pass} = params) do
    db = Dapnet.CouchDB.db("users")
    case CouchDB.Database.get(db, user) do
      {:ok, result} ->
        user = result |> Poison.decode!
        {hash, user} = user |> Map.pop("password")

        if hash && Bcrypt.verify_pass(pass, hash) do
          user
        else
          nil
        end
      _ ->
        nil
    end
  end
end