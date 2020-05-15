defmodule Dapnet.Scheduler do
  use GenServer

  @time_interval 1*60
  @rubric_update_interval 60*60
  @rubric_send_interval 1*60

  def start_link do
    GenServer.start_link(__MODULE__, :ok, [name: __MODULE__])
  end

  def init(_) do
    Process.send_after(self(), :send_time, 60 * 1000)
    Process.send_after(self(), :update_rubrics, 20 * 1000)
    Process.send_after(self(), :send_rubrics, 60 * 1000)
    Dapnet.Scheduler.Rubrics.init()
    {:ok, nil}
  end

  def handle_info(:update_rubrics, state) do
    Dapnet.Scheduler.Rubrics.update_queue()
    Process.send_after(self(), :update_rubrics, @rubric_update_interval * 1000)
    {:noreply, state}
  end

  def handle_info(:send_rubrics, state) do
    Dapnet.Scheduler.Rubrics.run_queue()
    Process.send_after(self(), :send_rubrics, @rubric_send_interval * 1000)
    {:noreply, state}
  end

  def handle_info(:send_time, state) do
    Dapnet.Scheduler.Time.send_calls()
    Process.send_after(self(), :send_time, @time_interval * 1000)
    {:noreply, state}
  end
end
