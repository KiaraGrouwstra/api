defmodule ThrottlerTest do
  use ExUnit.Case, async: false
  import Api.Throttler

  @domain "baidu.com"

  def kill_throttlers() do
    Supervisor.which_children(:throttlers)
    |> Enum.each fn({_,pid,_,_}) ->
      Supervisor.terminate_child(:throttlers, pid)
    end
  end

  setup do
    kill_throttlers()
    {:ok, pid} = Api.Utils.make_throttler(@domain)
    {:ok, [pid: pid]}
  end

  ##################################

  test "get", %{pid: pid} do
    assert get(pid) == :ok
  end

  test "check", %{pid: pid} do
    assert check(pid) >= 0
  end

end
