defmodule Api.Throttler do
  require Logger
  import Elins
  use ExActor.GenServer
  def start_link(args \\ nil, opts \\ [name: __MODULE__]), do: GenServer.start_link(__MODULE__, args, opts)

  def init(_) do
    :timer.send_interval(1_000, :tick)
    {:ok, %{incr: 1, val: 1}}
    # 1 bonus; TODO: make incr variable
  end

  @doc "on every tick increment each `val` by their respective `incr` amount"
  defhandleinfo :tick, state: %{incr: incr, val: val} do
    new_state %{incr: incr, val: val + incr}
  end

  @doc "decrement the value for a key by 1"
  defhandleinfo :dec, state: state, do: new_state(state |> edit([:val], fn v -> v - 1 end).())

  @doc "ask permission given a key, adding it if it wasn't in yet"
  def get(pid), do: GenServer.call(pid, :get)
  # skipping defcall macro for 'from' param
  def handle_call(:get, from, v) do
    throttler = self()
    Task.start_link fn -> request(from, throttler) end
    {:noreply, v}
  end

  defp request(from, throttler) do
    val = check(throttler)
    case val >= 1 do
      true ->
        {pid, ref} = from
        send pid, {ref, :ok}
      false ->
        delay = 1_000 - rem(:os.system_time(:milli_seconds), 1_000)
        :timer.sleep(delay)
        # TODO: fix this timing, the ticks don't necessarily happen at .000
        request(from, throttler)
        # how should this blocking work with GenServer's standard 5s timeout?
    end
  end

  @doc "respond with a key's value"
  defcall check(), state: v, do: reply v[:val]

end
