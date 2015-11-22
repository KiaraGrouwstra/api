defmodule Api.Throttler do
  require Logger
  import Elins
  use ExActor.GenServer
  # http://www.erlang.org/doc/man/gen_server.html#start_link-4
  # def start_link(fun \\ &(&1), opts \\ [name: __MODULE__]), do: GenServer.start_link(__MODULE__, nil, opts)
  def start_link(args \\ nil, opts \\ [name: __MODULE__]), do: GenServer.start_link(__MODULE__, args, opts)

  def init(_) do
    :timer.send_interval(1000, :tick)
    # {:ok, %{}}
    {:ok, %{incr: 1, val: 1}}
    # ^ todo: make incr variable
    # start at 1 credit cuz why not, less initial wait
  end

  @doc "on every tick increment each `val` by their respective `incr` amount"
  # defhandleinfo :tick, state: dict do
  #   new_state Enum.into(dict, %{},
  #     fn {k, [incr: incr, val: val]} -> {k,
  #       [incr: incr, val: val + incr]
  #   } end)
  # end
  # defhandleinfo :tick, state do # : %{incr: incr, val: val}
  #   # new_state state |> edit([:val], fn v -> v + 1 end)
  #   %{incr: incr, val: val} = state
  #   new_state state |> set([:val], val + incr)
  # end
  defhandleinfo :tick, state: %{incr: incr, val: val} do
    new_state %{incr: incr, val: val + incr}
  end

  @doc "decrement the value for a key by 1"
  # defhandleinfo {:dec, k}, state: dict, do: new_state Map.update!(dict, k,
  #   fn([incr: incr, val: val]) -> [incr: incr, val: val - 1] end
  # )
  # defhandleinfo :dec, %{incr: incr, val: val} do
  #   %{incr: incr, val: val - 1}
  # end
  defhandleinfo :dec, state: state, do: new_state(state |> edit([:val], fn v -> v - 1 end))

  # @doc "add a new key"
  # defhandleinfo {:add, k, incr}, state: dict, do: new_state Map.put(dict, k, [incr: incr, val: 0])

  @doc "ask permission given a key, adding it if it wasn't in yet"
  # def get(pid, k), do: GenServer.call(pid, {:get, k})
  # def handle_call({:get, k}, from, dict) do
  #   if Map.has_key?(dict, k) do
  #     spawn fn -> request(k, from) end
  #     {:noreply, dict}
  #   else
  #     # TODO: make incr variable
  #     send(self, {:add, k, 1})
  #     {:reply, :ok, dict}
  #   end
  # end
  def get(pid), do: GenServer.call(pid, :get)
  def handle_call(:get, from, v) do
    spawn fn -> request(from) end
    {:noreply, v}
  end

  # request permission for an existing key, throttling the result if it does not have credit yet
  # defp request(k, from) do
  #   # pid = :erlang.whereis(Api.Throttler)
  #   pid = Kernel.self()
  #   val = check(pid, k)
  #   case val >= 1 do
  #     true ->
  #       {pid, ref} = from
  #       send pid, {ref, :ok}
  #     false ->
  #       # split throttler by consumed queue?
  #       delay = 1000 - rem(:os.system_time(:milli_seconds), 1000)
  #       :timer.sleep(delay)
  #       # TODO: fix this timing, the ticks don't necessarily happen at .000
  #       request(k, from)
  #   end
  # end
  defp request(from) do
    # pid = Kernel.self()
    val = check(self())
    case val >= 1 do
      true ->
        {pid, ref} = from
        send pid, {ref, :ok}
      false ->
        delay = 1000 - rem(:os.system_time(:milli_seconds), 1000)
        :timer.sleep(delay)
        # TODO: fix this timing, the ticks don't necessarily happen at .000
        request(from)
    end
  end

  @doc "respond with a key's value"
  # defcall check(k), state: dict do
  #   reply Dict.get(dict, k)[:val]
  # end
  defcall check(), state: v, do: reply v[:val]

end
