defmodule Api.RoomChannel do
  use Phoenix.Channel
  require Logger
  import Api.Utils
  import Elins

  def join("rooms:lobby", msg, socket) do
    Logger.debug "join: msg: #{inspect(msg)}; socket: #{inspect(socket)};"
    Process.flag(:trap_exit, true)
    :timer.send_interval(60 * 1000, :ping) # 5
    send(self, {:after_join, msg})
    user = msg["user"]
    socket = assign(socket, :user, user)
    Api.Socket.start_link(self, user)
    {:ok, socket}
  end

  def join("rooms:" <> _topic, _msg, _socket) do
    Logger.debug "wrong room"
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

  def handle_info({:resp, msg, meta}, socket) do
    Logger.debug "handle_info resp: msg: #{String.valid?(msg)}; meta: #{inspect(meta)}"
    push socket, meta[:handler], msg
    {:noreply, socket}
  end

  def handle_info(:ping, socket) do
    Logger.debug "ping"
    push socket, "new:msg", %{user: "SYSTEM", body: "ping"}
    {:noreply, socket}
  end

  # handle client messages

  def handle_in("new:msg", msg, socket) do
    Logger.debug "new:msg"
    broadcast! socket, "new:msg", %{user: msg["user"], body: msg["body"]}
    {:reply, {:ok, %{msg: msg["body"]}}, assign(socket, :user, msg["user"])}
  end

  # this function handles multiple URLs, yet it's responding like to a single request (RESP)... too bad I can't complete array requests.
  def handle_in(r, msg, socket) when r == "POST:/urls" do
    Logger.debug r
    Logger.debug "msg: #{inspect(msg)}"
    info = %Info{meta: %Meta{user: socket.assigns[:user], req: msg |> to_atoms() |> as(MsgIn), handler: "RESP", route: r}}
    Logger.debug "info: #{inspect(info)}"
    urls = msg["body"] |> String.split()
    Api.AmqpBiz.post_urls(urls, info) # {:ok, num} =
    # {:reply, {:ok, %{num: num}}, socket}
    {:noreply, socket}
  end

  def handle_in(r, msg, socket) when r == "POST:/check" do
    Logger.debug r
    info = %Info{meta: %Meta{user: socket.assigns[:user], req: msg |> to_atoms() |> as(MsgIn), handler: "PART", route: r}}  # different handler
    headers = msg["headers"]
    headers_without = Enum.map(headers, fn {k, _v} -> {"without #{k}", Map.delete(headers, k) } end)
    header_combs = [{"all", headers}, {"none", []}] ++ headers_without
    opts = Enum.map(header_combs, fn({name, req_headers}) ->
      info |> set([:msg, :body], %{name: name}) |> set([:meta, :req, :headers], req_headers)
    end)
    urls = msg["body"] # |> String.split()    # wait, I don't think zip_duplicate handles combining with 1-element arrays yet atm.
    Api.AmqpBiz.post_urls(urls, opts) # {:ok, num} =
    # push socket, "DONE", %{cb_id: id}
    # ^ I'll have to make things synchronous to know when it's done...
    # unless I tally expected responses left for this cb_id, then on each partial response check if all's done.
    # even then, I'd need guarantees on the done getting received only after the last messages though...
    # while I don't have any delivery guarantees in the first place.
    # temp workaround: do a sync_confirm on the last expected item before sending an onComplete
    # (this assumes all previous messages have been received by then)
    # {:reply, {:ok, %{num: num}}, socket}
    {:noreply, socket}
  end

  def handle_in(_r, msg, socket) do
    Logger.debug "fallback handle_in"
    # broadcast! socket, route, msg
    push socket, "FALLBACK", msg
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
