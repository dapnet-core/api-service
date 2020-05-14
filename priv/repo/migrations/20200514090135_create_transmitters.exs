defmodule Dapnet.Repo.Migrations.CreateTransmitters do
  use Ecto.Migration

  def change do
    create table(:transmitters, primary_key: false) do
      add :id, :string, primary_key: true
      add :node, :string
      add :connected_since, :utc_datetime
      add :last_seen, :utc_datetime
      add :addr, :string
      add :software, :map
    end
  end
end
