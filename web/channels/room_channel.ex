defmodule Api.RoomChannel do
  use Phoenix.Channel
  require Logger
  import Api.Utils
  import Elins

  def join("rooms:lobby", msg, socket) do
    # Logger.debug "join: msg: #{inspect(msg)}; socket: #{inspect(socket)};"
    Process.flag(:trap_exit, true)
    :timer.send_interval(60_000, :ping) # 5
    send(self, {:after_join, msg})
    user = msg["user"]
    socket2 = assign(socket, :user, user)
    Api.Socket.start_link(self, user)
    {:ok, socket2}
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

  def handle_info({:resp, msg}, socket) do
    # Logger.debug "handle_info resp: msg: #{String.valid?(msg)}"
    push socket, "msg", msg
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


  #######################################################

  def handle_in(r, msg, socket) do
    Logger.debug r
    req = to_atoms(msg)
    body = Map.merge %{headers: %{}}, req.body  # default param val
    info = %Info{user: socket.assigns[:user], req: body, route: r, msg: %{cb_id: req.cb_id} }
    handle r, info, body
    # {:noreply, socket}
    {:reply, :ok, socket}
  end

  # this function handles multiple URLs, yet it's responding like to a single request (RESP)... too bad I can't complete array requests.
  @doc "fetch a URL and return its body"
  def handle("/urls", info, body) do
    Api.Utils.post_urls(body.urls, info)
  end
  def respond("/urls", info, res) do
    info.msg |> set [:body], res.body
  end

  @doc "return info extracted from a given url based on a Parsley parselet"
  def handle("/parse", info, %{url: url, parselet: parselet}) do
    info_ = info |> set [:misc, :parselet], parselet
    Api.Utils.post_urls url, info_
  end
  def respond("/parse", info, res) do
    json = Api.Parsing.parse(res.body, info.misc.parselet)
    info.msg |> set [:body], json
  end

  @doc "fetch a URL using different combinations of the given request headers to analyze which affect results"
  def handle("/check", info, body) do
    hdrs = body.headers
    headers_without = Enum.map(hdrs, fn {k, _v} -> {"without #{k}", Map.delete(hdrs, k) } end)
    header_combs = [{"all", hdrs}, {"none", []}] ++ headers_without
    info = Enum.map(header_combs, fn({name, req_hdrs}) ->
      info |> set([:msg, :body], %{name: name}) |> set([:req, :headers], req_hdrs)
    end)
    Api.Utils.post_urls body.urls, info
    # track what's left on client?
  end
  def respond("/check", info, res) do
    info.msg
      |> set([:body, :status], res.status_code)
      |> set([:body, :length], byte_size(res.body))
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
