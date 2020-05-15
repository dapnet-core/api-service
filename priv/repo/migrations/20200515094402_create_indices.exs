defmodule Dapnet.Repo.Migrations.CreateIndices do
  use Ecto.Migration

  def change do
    create index("calls", [:created_by, :created_at])
    create index("calls", [:created_at])

    create index("transmitters", [:node, :last_seen])
    create index("transmitters", [:last_seen])
  end
end
