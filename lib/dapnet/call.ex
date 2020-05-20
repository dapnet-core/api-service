defmodule Dapnet.Call do
  use Ecto.Schema
  import Ecto.Changeset

  @derive {Jason.Encoder, except: [:__meta__, :__struct__]}
  @primary_key {:id, Ecto.UUID, []}
  schema "calls" do
    field :created_at, :utc_datetime
    field :created_by, :string
    field :data, :string
    field :distribution, :map
    field :expires_at, :utc_datetime
    field :local, :boolean, default: false
    field :origin, :string
    field :priority, :integer
    field :recipients, :map
  end

  @doc false
  def changeset(call, attrs) do
    call
    |> cast(attrs, [:id, :data, :priority, :local, :origin, :created_by, :created_at, :expires_at, :recipients, :distribution])
    |> validate_required([:id, :data, :priority, :local, :origin, :created_by, :created_at, :recipients, :distribution])
    |> unique_constraint(:id, name: :calls_pkey)
  end
end
