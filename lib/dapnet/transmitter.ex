defmodule Dapnet.Transmitter do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query, only: [from: 2]

  @derive {Jason.Encoder, except: [:__meta__, :__struct__]}
  @primary_key {:id, :string, []}
  schema "transmitters" do
    field :node, :string
    field :connected_since, :utc_datetime
    field :last_seen, :utc_datetime
    field :addr, :string
    field :software, :map
  end

  @doc false
  def changeset(transmitter, attrs) do
    transmitter
    |> cast(attrs, [:id, :node, :connected_since, :last_seen, :addr, :software])
    |> validate_required([:id, :node, :connected_since, :last_seen, :addr])
  end

  def online() do
    limit = Timex.shift(Timex.now(), minutes: -3)
    from tx in Dapnet.Transmitter, where: tx.last_seen > ^limit
  end

  def online(node_id) do
    limit = Timex.shift(Timex.now(), minutes: -3)
    from tx in Dapnet.Transmitter, where: tx.node == ^node_id and tx.last_seen > ^limit
  end

  def is_online?(transmitter) do
    transmitter.last_seen != nil && Timex.diff(Timex.now(), transmitter.last_seen, :minutes) < 3
  end
end
