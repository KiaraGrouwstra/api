defmodule Api.Throttler do
  require Logger
  use ExActor.GenServer
  def start_link(fun \\ &(&1), opts \\ []), do: GenServer.start_link(__MODULE__, nil, name: __MODULE__)

  def init(_) do
    :timer.send_interval(1000, :tick)
    {:ok, %{}}
  end

  defhandleinfo :tick, state: dict do
    new_state Enum.into(dict, %{},
      fn {k, [incr: incr, val: val]} -> {k,
        [incr: incr, val: val + incr]
    } end)
  end

  defhandleinfo {:dec, k}, state: dict, do: new_state Map.update!(dict, k,
    fn([incr: incr, val: val]) -> [incr: incr, val: val - 1] end
  )

  defhandleinfo {:add, k, incr}, state: dict, do: new_state Map.put(dict, k, [incr: incr, val: 0])

  def get(pid, k), do: GenServer.call(pid, {:get, k})
  def handle_call({:get, k}, from, dict) do
    if Map.has_key?(dict, k) do
      spawn fn -> request(k, from) end
      {:noreply, dict}
    else
      # TODO: make incr variable
      send(self, {:add, k, 1})
      {:reply, :ok, dict}
    end
  end

  defp request(k, from) do
    pid = :erlang.whereis(Api.Throttler)
    val = check(pid, k)
    case val >= 1 do
      true ->
        {pid, ref} = from
        send pid, {ref, :ok}
      false ->
        # split throttler by consumed queue?
        :timer.sleep(1000 - rem(:os.system_time(:milli_seconds), 1000))
        # TODO: fix this timing, the ticks don't necessarily happen at .000
        request(k, from)
    end
  end

  defcall check(k), state: dict do
    reply Dict.get(dict, k)[:val]
  end

end
