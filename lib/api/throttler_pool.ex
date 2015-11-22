defmodule Api.ThrottlerPool do
  import Api.GenSupervisor
  @mod Api.Throttler
  def start_link(_args \\ nil, opts \\ []), do: start_link(@mod, __MODULE__, opts)
  def init(:ok), do: init(:ok, @mod)
end

# {:ok, sup} = Api.ThrottlerPool.start_link
# {:ok, pid} = Supervisor.start_child(sup, [nil, [name: :baidu]])
# Api.Throttler.get(pid, "foo")

# worker(Api.ThrottlerPool, [@manager, [name: :throttlers]]),
# {:ok, _pid} = Supervisor.start_child(:throttlers, [nil, [name: :baidu]])
# Api.Throttler.get(:baidu, "foo")
# GenServer.call(:baidu, {:get, "foo"})
