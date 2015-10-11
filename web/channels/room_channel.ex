defmodule Chat.RoomChannel do
  use Phoenix.Channel
  require Logger

  @doc """
  Authorize socket to subscribe and broadcast events on this channel & topic

  Possible Return Values

  `{:ok, socket}` to authorize subscription for channel for requested topic

  `:ignore` to deny subscription/broadcast on this channel
  for the requested topic
  """
  def join("rooms:lobby", msg, socket) do
    Logger.debug "> joined: #{inspect msg}"
    Process.flag(:trap_exit, true)
    :timer.send_interval(5000, :ping)
    send(self, {:after_join, msg})

    # Chat.Socket.start_link(socket, "tycho")
    Chat.Socket.start_link(self, "tycho")

    {:ok, socket}
  end

  def join("rooms:" <> topic, _msg, _socket) do
    Logger.debug "> unauthorized: #{inspect topic}"
    {:error, %{reason: "unauthorized"}}
  end

  def terminate(reason, _socket) do
    Logger.debug "> leave #{inspect reason}"
    :ok
  end

  # internal events to trigger sending

  def handle_info({:after_join, msg}, socket) do
    Logger.debug "> handling after_join"
    broadcast! socket, "user:entered", %{user: msg["user"]}
    push socket, "join", %{status: "connected"}
    {:noreply, socket}
  end

  def handle_info({:resp, msg}, socket) do
    Logger.debug "> replying"
    push socket, "resp", %{data: msg}
    {:noreply, socket}
  end

  def handle_info(:ping, socket) do
    # Logger.debug "> handling ping"
    push socket, "new:msg", %{user: "SYSTEM", body: "ping"}
    {:noreply, socket}
  end

  # handle client messages

  def handle_in("new:msg", msg, socket) do
    Logger.debug "> handling new:msg"
    broadcast! socket, "new:msg", %{user: msg["user"], body: msg["body"]}
    {:reply, {:ok, %{msg: msg["body"]}}, assign(socket, :user, msg["user"])}
  end

  def handle_in("post:/urls", msg, socket) do
    %{"data" => urls} = msg
    Logger.debug "> handling post:/urls: #{inspect urls}"
    socket = assign(socket, :user, msg["user"])
    {:ok, num} = Chat.AmqpBiz.post_urls(urls, reply_to: socket.assigns[:user])
    # so now I'd like to store the socket by this key?
    {:reply, {:ok, %{num: num}}, socket}
  end

  def handle_in(route, msg, socket) do
    Logger.debug "> handling another: [#{route}]: #{inspect msg}"
    broadcast! socket, route, msg
    {:reply, {:ok, msg}, socket}
  end

  # customize/filter broadcasts

  # intercept ["user_joined"]
  #
  # def handle_out("user_joined", msg, socket) do
  #   if User.ignoring?(socket.assigns[:user], msg.user_id) do
  #     {:noreply, socket}
  #   else
  #     push socket, "user_joined", msg
  #     {:noreply, socket}
  #   end
  # end

end
