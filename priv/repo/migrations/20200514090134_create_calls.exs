defmodule Dapnet.Repo.Migrations.CreateCalls do
  use Ecto.Migration

  def change do
    create table(:calls, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :data, :string
      add :priority, :integer
      add :local, :boolean, default: false, null: false
      add :origin, :string
      add :created_by, :string
      add :created_at, :utc_datetime
      add :expires_at, :utc_datetime
      add :recipients, :map
      add :distribution, :map
    end

  end
end
