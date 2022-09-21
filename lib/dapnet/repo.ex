defmodule Dapnet.Repo do
  use Ecto.Repo,
    otp_app: :dapnet,
    adapter: Ecto.Adapters.Postgres

  use Paginator, include_total_count: true

  require Protocol
  Protocol.derive(Jason.Encoder, Paginator.Page)
  Protocol.derive(Jason.Encoder, Paginator.Page.Metadata)
end
