# TODO: ditch AMQP for native message passing?

defmodule Chat.AmqpSub do
  require Logger
  # Responders: noreply(), reply(response), new_state(state), set_and_reply(new_state, response)
  use ExActor.GenServer #, initial_state: init_subscribe(opts) # Chat.Amqp.get_chan() # connect()
  # defstart start_link, do: initial_state(connect())
  # defcast stop, do: stop_server(:normal)

  # defcall get, state: state, do: reply(state)
  # defcast inc(x), state: state, do: new_state(state + x)

  # use AMQP

  # defstart start_link(opts \\ []), do: start_link(&(&1), opts)
  defstart start_link(fun, opts), do: init_subscribe(opts)

  def connect() do
    # {:ok, _pid} = KafkaEx.create_worker(:my_kafka)  # doesn't belong here, esp. if one per instance...
    {:ok, conn} = AMQP.Connection.open("amqp://test:test@127.0.0.1:5672")
    {:ok, chan} = AMQP.Channel.open(conn)
    chan
  end

  def init_subscribe([queue: q, lambda: l]) do
    init_subscribe([queue: q, lambda: l, chan: connect()])
  end
  def init_subscribe([queue: queue_settings, lambda: l, chan: chan]) do
    queue = case queue_settings do
      {:join, queue} -> queue
      {:make, exchange, route} ->
        {:ok, %{queue: queue}} = AMQP.Queue.declare chan, "", [auto_delete: true]
        # [durable: true]  # no point in durability if I keep making new ones
        AMQP.Queue.bind chan, queue, exchange, [routing_key: route]
        queue
    end
    {:ok, _tag} = AMQP.Basic.consume(chan, queue)
    {:ok, %{chan: chan, lambda: l, queue: queue_settings}} # keep queue to reconnect?
  end

  # def get_chan() do
  #   Agent.get(__MODULE__, fn(state) -> state.chan end)
  # end

  # defhandleinfo {:basic_cancel,     _tag}, do: stop(:normal) # new_state(connect())
  defhandleinfo {:basic_consume_ok, _tag}, do: noreply
  defhandleinfo {:basic_cancel_ok,  _tag}, do: noreply
  # defhandleinfo {:basic_deliver, payload, tag}, state: %{chan: chan, lambda: lambda}, do: fn ->
  def handle_info({:basic_deliver, payload, tag}, state) do
    %{chan: chan, lambda: lambda} = state
    spawn fn -> lambda.(chan, payload, tag) end
    # noreply
    {:noreply, state}
  end

end
