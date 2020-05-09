defmodule DapnetApi.Scheduler do
  use GenServer

  @time_interval 10*60

  def start_link do
    GenServer.start_link(__MODULE__, :ok, [name: __MODULE__])
  end

  def init(_) do
    Process.send_after(self(), :send_time, 60 * 1000) 
    {:ok, nil}
  end

  def handle_info(:send_time, state) do
    time_call = %{
      "id" => uuid(),
      "protocol" => "pocsag",
      "expires_on" => Timex.now() |> Timex.shift(minutes: 3),
      "priority" => 4,
      "origin" => origin,
      "created_by" => "core",
      "created_on" => Timex.now(),
      "message" => %{
        "ric" => 2504,
        "function" => 0,
        "type" => "numeric",
        "speed" => 1200,
        "data" => Timex.now() |> Timex.format!("{h24}{m}{s}   {0D}{0M}{YY}")
      }
    } |> Poison.encode!

    DapnetApi.Transmitter.Database.list_connected()
    |> Enum.each(fn transmitter ->
      id = Map.get(transmitter, "_id")
      IO.puts("#{id}: #{time_call}")
      DapnetApi.Call.RabbitMQ.publish_call(id, time_call)
    end)

    Process.send_after(self(), :send_time, @time_interval * 1000)
    {:noreply, state}
  end

  defp uuid() do
    UUID.uuid1()
  end

  defp origin() do
    System.get_env("NODE_NAME")
  end
end
