defmodule Dapnet.Repo do
  use Ecto.Repo,
    otp_app: :dapnet,
    adapter: Ecto.Adapters.Postgres
end
