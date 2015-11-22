# # acking issues seem to go away after I switched the acking statements further up?
#
# # Consumer.start_link
# # {:ok, conn} = AMQP.Connection.open
# # {:ok, chan} = AMQP.Channel.open(conn)
# # AMQP.Basic.publish chan, "urls", "", "5"
#
# defmodule Consumer do
#   use GenServer
#   use AMQP
#
#   def start_link do
#     GenServer.start_link(__MODULE__, [], [])
#   end
#
#   def init(_opts) do
#     {:ok, conn} = Connection.open("amqp://test:test@localhost")
#     {:ok, chan} = Channel.open(conn)
#     {:ok, _consumer_tag} = Basic.consume(chan, "urls")
#     {:ok, chan}
#   end
#
#   def handle_info({:basic_deliver, payload, %{delivery_tag: tag}}, chan) do
#     Basic.ack chan, tag
#     IO.puts "Consumed a #{payload}."
#     {:noreply, chan}
#   end
#
#   def handle_info({_crap, _meta}, chan) do
#     {:noreply, chan}
#   end
#
# end
