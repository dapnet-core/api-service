defmodule Dapnet.Scheduler.Rubrics do
  use GenServer

  def update_queue, do: GenServer.call(__MODULE__, :update_queue, 10000)
  def run_queue, do: GenServer.call(__MODULE__, :run_queue, 30000)

  def start_link() do
    GenServer.start_link(__MODULE__, {}, [name: __MODULE__])
  end

  def init(_args) do
    :ets.new(:rubric_queue, [:ordered_set, :public, :named_table])
    Process.send_after(self(), :request_changes, 15000)
    {:ok, nil}
  end

  def handle_info(:request_changes, state) do
    user = System.get_env("COUCHDB_USER")
    pass = System.get_env("COUCHDB_PASSWORD")

    req = %HTTPoison.Request{
      method: :get,
      url: "http://couchdb:5984/news/_changes?feed=continuous&include_docs=true&since=now",
      headers: [{"Accept", "application/json"}],
      options: [
        {:stream_to, self()},
        {:recv_timeout, :infinity},
        {:hackney, [basic_auth: {user, pass}]}
      ]
    }
    HTTPoison.request(req)
    {:noreply, state}
  end

  def handle_info(%HTTPoison.AsyncStatus{} = res, state) do
    {:noreply, state}
  end

  def handle_info(%HTTPoison.AsyncHeaders{} = res, state) do
    {:noreply, state}
  end

  def handle_info(%HTTPoison.AsyncChunk{:chunk => chunk} = res, state) do
    data = chunk
    |> String.split("\n")
    |> Enum.map(&Jason.decode(&1))
    |> Enum.each(&process_change(&1))
    {:noreply, state}
  end

  def process_change({:ok, data}) do
    IO.inspect(data)
  end

  def process_change(_error) do
    # IO.inspect(_error)
  end

  def handle_info(%HTTPoison.AsyncEnd{}, state) do
    Process.send_after(self(), :request_changes, 5000)
    {:noreply, state}
  end

  def handle_info(%HTTPoison.Error{}, state) do
    Process.send_after(self(), :request_changes, 5000)
    {:noreply, state}
  end

  def handle_call(:update_queue, _from, state) do
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

    {:reply, :ok, state}
  end

  def handle_call(:run_queue, _from, state) do
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
          send_news(rubric)
          queue_rubric(rubric)
        end
      _ -> nil
    end)

    {:reply, :ok, state}
  end

  defp queue() do
    Stream.unfold(:ets.first(:rubric_queue), fn
      :"$end_of_table" -> nil
      key -> {key, :ets.next(:rubric_queue, key)}
    end)
  end

  defp send_news(rubric) do
    id =  Map.get(rubric, "_id")
    IO.puts("Sending " <> id)

    with {:ok, news} <- get_news(id) do
      messages = Map.get(news, "items")
      |> Enum.with_index(1)
      |> Enum.each(&send_call(rubric, &1))
    else
      _ -> nil
    end
  end

  def send_call(rubric, {message, news_id}) do
    create_skyper_call(rubric, message, news_id)
    |> Dapnet.Call.Dispatcher.dispatch()

    create_news_call(rubric, message, news_id)
    |> Dapnet.Call.Dispatcher.dispatch()
  end

  def create_news_call(rubric, message, news_id) do
    rubric_id = Map.get(rubric, "number")

    create_call(rubric)
    |> Map.merge(%{
      "recipients" => %{"pocsag" => [%{
        "ric" => 1000 + rubric_id,
        "function" => Map.get(rubric, "function", 3)
      }]},
      "data" => Map.get(message, "data")
    })
  end

  defp create_skyper_call(rubric, message, news_id) do
    rubric_id = Map.get(rubric, "number")

    create_call(rubric)
    |> Map.merge(%{
      "recipients" => %{"pocsag" => [%{
        "ric" => 4520,
        "function" => Map.get(rubric, "function", 3)
      }]},
      "data" => Map.get(message, "data")
        |> encode_skyper_news(rubric_id, news_id)
    })
  end

  defp create_call(rubric) do
    origin = System.get_env("NODE_NAME")

    call = %{
      "id" => UUID.uuid1(),
      "priority" => Map.get(rubric, "default_priority", 2),
      "origin" => origin,
      "local" => true,
      "created_by" => "core-scheduler-rubrics",
      "created_at" => Timex.now(),
      "distribution" => %{
        "transmitters" => Map.get(rubric, "transmitters", []),
        "transmitter_groups" => Map.get(rubric, "transmitter_groups", [])
      }
    }
  end

  defp encode_skyper_news(data, rubric_id, news_id) do
    data = to_charlist(data) |> Enum.map(fn char -> char + 1 end)
    ([rubric_id + 0x1f] ++ [news_id + 0x20] ++ data) |> to_string
  end

  defp get_news(id) do
    result = Dapnet.CouchDB.db("news")
    |> CouchDB.Database.get(id)

    with {:ok, result} <- result,
         {:ok, result} <- Jason.decode(result) do
      result
    else
      _ -> nil
    end
  end

  defp get_rubric(id) do
    result = Dapnet.CouchDB.db("rubrics")
    |> CouchDB.Database.get(id)

    with {:ok, result} <- result,
         {:ok, result} <- Jason.decode(result) do
      result
    else
      _ -> nil
    end
  end

  defp queue_rubric(rubric) do
    case next_cycle(rubric) do
      nil -> nil
      next ->
        if id = Map.get(rubric, "_id") do
          IO.inspect({next, id})
          :ets.insert(:rubric_queue, {{next, id}, nil})
        end
    end
  end

  defp next_cycle(rubric) do
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
