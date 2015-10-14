defmodule Api.RoomChannel do
  use Phoenix.Channel
  require Logger

  def join("rooms:lobby", msg, socket) do
    Logger.debug "join: msg: #{inspect(msg)}; socket: #{inspect(socket)};"
    Process.flag(:trap_exit, true)
    :timer.send_interval(60 * 000, :ping) # 5
    send(self, {:after_join, msg})
    user = msg["user"]
    socket = assign(socket, :user, user)
    Api.Socket.start_link(self, user)
    {:ok, socket}
  end

  def join("rooms:" <> topic, _msg, _socket) do
    {:error, %{reason: "unauthorized"}}
  end

  def terminate(reason, _socket) do
    Logger.debug "> leave #{inspect reason}"
    :ok
  end

  # internal events to trigger sending

  def handle_info({:after_join, msg}, socket) do
    Logger.debug "after_join"
    broadcast! socket, "user:entered", %{user: msg["user"]}
    push socket, "join", %{status: "connected"}
    {:noreply, socket}
  end

  def handle_info({:resp, msg, req}, socket) do
    Logger.debug "handle_info resp: msg: #{String.valid?(msg)}; req: #{inspect(req)}"
    push socket, "RESP", %{body: msg, cb_id: req[:cb_id]}
    {:noreply, socket}
  end

  def handle_info(:ping, socket) do
    push socket, "new:msg", %{user: "SYSTEM", body: "ping"}
    {:noreply, socket}
  end

  # handle client messages

  def handle_in("new:msg", msg, socket) do
    Logger.debug "new:msg"
    broadcast! socket, "new:msg", %{user: msg["user"], body: msg["body"]}
    {:reply, {:ok, %{msg: msg["body"]}}, assign(socket, :user, msg["user"])}
  end

  def handle_in("POST:/urls", msg, socket) do
    Logger.debug "POST:/urls"
    %{"body" => body, "cb_id" => cb_id } = msg
    urls = body
    from = socket.assigns[:user]
    headers = Enum.into(msg, [])
    opts = [reply_to: from, headers: headers]
    {:ok, num} = Api.AmqpBiz.post_urls(urls, opts)
    {:reply, {:ok, %{num: num}}, socket}
  end

  def handle_in(route, msg, socket) do
    Logger.debug "fallback handle_in"
    # broadcast! socket, route, msg
    # {:reply, {:ok, msg}, socket}
    push socket, route, msg
    {:noreply, socket}
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
