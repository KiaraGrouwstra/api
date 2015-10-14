defmodule Api.AmqpPub do

  def start_link(_fun \\ &(&1), _opts \\ []) do
    Agent.start_link(&connect/0, name: __MODULE__)
  end

  def get_chan() do
    Agent.get(__MODULE__, &(&1))
  end

  def connect() do
    {:ok, conn} = AMQP.Connection.open("amqp://test:test@127.0.0.1:5672")
    {:ok, chan} = AMQP.Channel.open(conn)
    Api.AmqpBiz.sub_existing(chan)   # move...
    chan
  end

  # @exchange "urls"

  # def make_exc(chan, exchange \\ @exchange) do
  #   AMQP.Exchange.declare chan, exchange
  # end

  # def make_queue(chan, name) do
  #   AMQP.Queue.declare chan, name
  #   AMQP.Queue.bind chan, name, @exchange, [routing_key: name]
  # end

  # def publish(chan, msg, route \\ "", options \\ []) do
  #   AMQP.Basic.publish chan, @exchange, route, msg, options
  # end

  # def consume(chan, queue) do
  #   AMQP.Basic.get chan, queue
  #   # https://github.com/pma/amqp/blob/master/lib/amqp/basic.ex
  #   # returns {:ok, payload, meta}
  #   # meta: %{app_id: :undefined, cluster_id: :undefined, content_encoding: :undefined, content_type: :undefined, correlation_id: :undefined, delivery_tag: 1, exchange: "urls", expiration: :undefined, headers: :undefined, message_count: 0, message_id: :undefined, persistent: false, priority: :undefined, redelivered: true, reply_to: "tycho", routing_key: "lol", timestamp: :undefined, type: :undefined, user_id: :undefined}
  #   # resp = AMQP.Basic.get chan, "lol"
  #   # {:ok, payload, meta} = resp
  #   # meta.reply_to
  # end

  # def subscribe(chan, queue, fun \\
  #     fn(payload, _meta) -> IO.puts("Received: #{payload}") end
  #   ) do
  #   AMQP.Queue.subscribe chan, queue, fun
  # end

end
