defmodule Dapnet.Scheduler.Time do
  def send_calls() do
    origin = System.get_env("NODE_NAME")

    time_call = %{
      "id" => UUID.uuid1(),
      "protocol" => "pocsag",
      "expires_on" => Timex.now() |> Timex.shift(minutes: 2),
      "priority" => 4,
      "origin" => origin,
      "created_by" => "core-scheduler-time",
      "created_on" => Timex.now(),
      "message" => %{
        "ric" => 2504,
        "function" => 0,
        "type" => "numeric",
        "speed" => 1200,
        "data" => Timex.now() |> Timex.format!("{h24}{m}{s}   {0D}{0M}{YY}")
      }
    } |> Jason.encode!

    Dapnet.Repo.all(Dapnet.Transmitter.online(origin))
    |> Enum.each(fn transmitter ->
      Dapnet.Call.RabbitMQ.publish_call(transmitter.id, time_call)
    end)
  end
end
