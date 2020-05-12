defmodule DapnetApi.Transmitter.Database do
  use GenServer

  def update(id, data) do
    GenServer.call(__MODULE__, {:update, id, data})
  end

  def start_link() do
    GenServer.start_link(__MODULE__, {}, [name: __MODULE__])
  end

  def init(args) do
    :ets.new(:transmitters, [:set, :protected, :named_table])
    {:ok, nil}
  end

  def get(id) do
    case :ets.lookup(:transmitters, id) do
      [{_id, data}] -> data
      [] -> %{}
    end
  end

  def list_connected() do
    :ets.tab2list(:transmitters)
    |> Enum.filter(fn {key, val} ->
      last_seen = Map.get(val, "last_seen")
      last_seen != nil && Timex.diff(last_seen, Timex.now(), :minutes) < 3
    end)
    |> Enum.map(fn {key, val} -> val end)
  end

  def handle_call({:update, id, data}, _from, state) do
    data = get(id) |> Map.merge(data)
    :ets.insert(:transmitters, {id, data})
    {:reply, data, state}
  end
end
