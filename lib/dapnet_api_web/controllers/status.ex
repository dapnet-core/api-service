defmodule DapnetApiWeb.StatusController do
  use DapnetApiWeb, :controller

  def status(conn, _params) do
    workers = Supervisor.which_children(DapnetApi.Supervisor)
    |> Enum.map(fn {name, pid, _type, _modules} ->
      status = case pid do
        pid when is_pid(pid) ->
          :running
        status -> status
      end
      %{"name" => name, "status" => status}
    end)
    json(conn, %{"status": :ok, "workers": workers})
  end
end