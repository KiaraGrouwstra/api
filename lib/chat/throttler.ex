defmodule Chat.Throttler do
  require Logger
  use ExActor.GenServer #, initial_state: init()  # %{}
  # defstart start_link, do: initial_state([])

  # defstart start_link(fun \\ &(&1), opts \\ []), do: init()
  # def start_link, do: GenServer.start_link(__MODULE__, init(), name: __MODULE__)
  # def start_link(fun \\ &(&1), opts \\ []), do: GenServer.start_link(__MODULE__, init(), name: __MODULE__)
  def start_link(fun \\ &(&1), opts \\ []), do: GenServer.start_link(__MODULE__, nil, name: __MODULE__)

  # def init() do
  def init(_) do
    Logger.debug("initializing throttler!")
    :timer.send_interval(1000, :tick)
    {:ok, %{}}
  end

  # defhandleinfo :tick, state: dict, do: fn ->
  def handle_info(:tick, dict) do
    increased = Enum.into(dict, %{}, fn {k, [incr: incr, val: val]} -> {k,
      [incr: incr, val: val + incr]
    } end)
    # new_state(increased)
    {:noreply, increased}
  end

  defhandleinfo {:dec, k}, state: dict, do: new_state Map.update!(dict, k,
    fn([incr: incr, val: val]) -> [incr: incr, val: val - 1] end
  )

  defhandleinfo {:add, k, incr}, state: dict, do: new_state Map.put(dict, k, [incr: incr, val: 0])

  # defcall test(one, two), do: reply(two)
  # def test(pid, one, two), do: GenServer.call(pid, {:test, one, two})
  # def handle_call({:test, one, two}, from, state), do: {:reply, two, state}

  # defcall get(k), state: dict, do: fn ->
  def get(pid, k), do: GenServer.call(pid, {:get, k})
  def handle_call({:get, k}, from, dict) do
    Logger.debug "#{inspect self} is checking permission for #{k} from #{inspect from}"
    if Map.has_key?(dict, k) do
      Logger.debug "key found"
      spawn fn -> request(k, from, dict) end
      # spawn fn -> request(k, from) end
      # noreply()
      {:noreply, dict}
    else
      Logger.debug "key not found"
      # TODO: make incr variable
      send(self, {:add, k, 1})
      {:reply, :ok, dict}
    end
  end

  defp request(k, from, dict) do
  # defp request(k, pid) do
    Logger.debug "checking request for #{k}"
    case Dict.get(dict, k)[:val] >= 1 do
    # case check(k) >= 1 do
      true ->
        {pid, ref} = from
        send pid, {ref, :ok}
      false ->
        # split throttler by consumed queue?
        :timer.sleep(1000 - rem(:os.system_time(:milli_seconds), 1000))
        # TODO: fix this timing, the ticks don't necessarily happen at .000
        request(k, from, dict)
        # request(k, pid)
    end
  end

  # defcall check(k), state: dict, do: fn ->
  #   reply get(dict, k)[:val]
  # end

end
