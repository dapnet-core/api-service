defmodule Dapnet.Scheduler.Rubrics do

  def init() do
    :ets.new(:rubric_queue, [:ordered_set, :public, :named_table])
  end

  def update_queue() do
    IO.puts("Updating Cyclic Rubrics Queue")

    options = %{"include_docs" => true, "reduce" => "false"}

    result = Dapnet.CouchDB.db("rubrics")
    |> CouchDB.Database.view("rubrics", "byId", options)

    with {:ok, result} <- result,
         {:ok, result} <- Jason.decode(result) do

      :ets.delete_all_objects(:rubric_queue)

      Map.get(result, "rows")
      |> Enum.each(fn row ->
        doc = Map.get(row, "doc")
        queue_rubric(doc)
      end)
    else
      e -> IO.inspect(e)
    end
  end

  def run_queue() do
    now = System.system_time(:second)

    queue()
    |> Enum.take_while(fn
      {time, _id} -> time <= now
      nil -> false
    end)
    |> Enum.each(fn
      {_time, id} = key ->
        :ets.delete(:rubric_queue, key)
        rubric = get_rubric(id)
        if rubric do
          send_rubric(rubric)
          queue_rubric(rubric)
        end
      _ -> nil
    end)
  end

  def queue() do
    Stream.unfold(:ets.first(:rubric_queue), fn
      :"$end_of_table" -> nil
      key -> {key, :ets.next(:rubric_queue, key)}
    end)
  end

  def send_rubric(rubric) do
    IO.puts("Sending " <> Map.get(rubric, "_id"))

    messages = Map.get(rubric, "content")
    |> Enum.each(&send_call(rubric, &1))
  end

  def send_call(rubric, message) do
    origin = System.get_env("NODE_NAME")
    data = Map.get(message, "data")

    call = %{
      "id" => UUID.uuid1(),
      "data" => data,
      "priority" => Map.get(rubric, "default_priority", 2),
      "origin" => origin,
      "local" => true,
      "created_by" => "core-scheduler-rubrics",
      "created_at" => Timex.now(),
      "recipients" => %{"pocsag" => [%{
        "ric" => 4512,
        "function" => Map.get(rubric, "function", 3)
      }]},
      "distribution" => %{
        "transmitters" => Map.get(rubric, "transmitters", []),
        "transmitter_groups" => Map.get(rubric, "transmitter_groups", [])
      }
    }

    Dapnet.Call.Dispatcher.dispatch(call)
  end

  def get_rubric(id) do
    result = Dapnet.CouchDB.db("rubrics")
    |> CouchDB.Database.get(id)

    with {:ok, result} <- result,
         {:ok, result} <- Jason.decode(result) do
      result
    else
      _ -> nil
    end
  end

  def queue_rubric(rubric) do
    case next_cycle(rubric) do
      nil -> nil
      next ->
        if id = Map.get(rubric, "_id") do
          IO.inspect({next, id})
          :ets.insert(:rubric_queue, {{next, id}, nil})
        end
    end
  end

  def next_cycle(rubric) do
    if Map.get(rubric, "cyclic_transmit") do
      interval = Map.get(rubric, "cyclic_transmit_interval", 360)

      # Convert interval to seconds
      interval = interval * 60

      now = System.system_time(:second)
      now - rem(now, interval) + interval
    else
      nil
    end
  end
end
