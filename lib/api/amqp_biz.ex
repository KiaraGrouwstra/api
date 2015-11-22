# TODO: ditch AMQP for native message passing?

defmodule Api.AmqpBiz do
  require Logger
  import Api.Utils
  import Elins
  alias Porcelain.Result

  # pub

  @doc "for arrays of URLs and options, posts each pair to the fetching queue."
  def post_urls(urls, opts \\ []) do
    Logger.debug "post_urls"
    # exchange = "urls"
    # chan = Api.AmqpPub.get_chan()
    Api.Utils.zip_duplicate(urls, opts) |> Enum.each fn({url, opt}) ->
    # for url <- urls, opt <- opts do  # does a cartesian, ok for 1:n/n:1 but for n:n I need zip instead...
      # queue = route = Api.Utils.url_domain(url)
      # AMQP.Queue.declare chan, queue
      # AMQP.Queue.bind chan, queue, exchange, [routing_key: route]
      # Logger.debug "opt: #{inspect(opt)}"
      # AMQP.Basic.publish chan, exchange, route, url, [headers: [json: Poison.encode!(opt)]]
      domain = Api.Utils.url_domain(url)
      {url, opt} |> Api.QueueStore.push(domain)
    end
    # return the size for the notification message... doesn't work when URLs is not always an array.
    # num = Enum.count(urls)
    # Logger.debug "posted #{num} urls"
    # {:ok, num}
    # {:ok}
  end

  # sub ########################################################################

  def creator(chan, _msg, %{delivery_tag: tag, headers: headers}) do
    Logger.debug "creator"
    queue = headers |> get_header "name"
    make_fetcher(chan, queue)
    AMQP.Basic.ack chan, tag
  end

  # def deleter(_chan, _msg, tag) do
  #   _queue = get_header(tag.headers, "name")
  #   # TODO: kill queue fetcher with this name
  # end

  # ^ How to deal with shared distributed queues if I'm gonna be making new private queues?

  defp throttle(domain) do
    # pid = :erlang.whereis(Api.Throttler)
    # :ok = Api.Throttler.get(pid, domain)
    # ^ refactor so that for one throttler per domain, make if non-existent
    # check if alive
    where = Process.whereis(domain) # :: pid | port | nil
    case where do
      nil ->
        IO.puts "creating throttler for #{domain}"
        {:ok, _pid} = Supervisor.start_child(:throttlers, [nil, [name: domain]])
    end
    :ok = Api.Throttler.get(domain)
    # atomify domains?
  end

  # from the start; topic; many different queues
  def fetcher(chan, url, %{delivery_tag: tag, routing_key: domain, headers: amqp_meta}) do
    Logger.debug "fetcher"
    # Logger.debug "amqp_meta: #{inspect(amqp_meta)}"
    route = exchange = "responses"
    AMQP.Basic.ack chan, tag
    throttle(domain)
    info_struc = amqp_unheader(amqp_meta)[:json] |> Poison.decode!() |> to_atoms() # |> as(Info)
    # Logger.debug "info_struc: #{inspect(info_struc)}"
    %HTTPotion.Response{body: body, headers: resp_headers, status_code: status} = fetch_decode(url, info_struc[:meta][:req][:headers])
    info = info_struc |> set [:msg, :status], status
    headers = [json: Poison.encode!(info)]
    # Logger.debug Floki.find(body, "title") |> Floki.raw_html
    # html |> Floki.find(".pages a") |> Floki.attribute("href") |> Enum.map(fn(url) -> HTTPoison.get!(url) end)
    parselet = "{\"header\":\"h1\"}"
    %Result{out: output, status: 0} = Porcelain.exec("parsley", [parselet, body])
    Logger.debug output
    # ^ to store the compiled parselet objects I should probably go the NIF route: https://github.com/elixir-lang/elixir/wiki/Interoperability-with-C
    # alt: parsleyc -r in_file -w out_file... or instead just return it as a string and pass it on as a parameter.
    case status do
      x when x in 200..299 -> # OK
        Logger.debug "fetched page #{url}, posting to responses!"
        AMQP.Basic.publish chan, exchange, route, body, headers: headers
        # part = 0
        # KafkaEx.produce("dumps", part, body)
      x when x in 300..399 -> # redirect
        location = resp_headers[:Location]
        Logger.info "Redirecting from #{url} to #{location}"
        AMQP.Basic.publish chan, "urls", domain, location, headers: headers
        # do something to increase the tries/redirects flag so as to prevent infinite loops?
      x when x >= 400      -> # error
        Logger.warn "Page #{url} resulted in error #{x}!"
        AMQP.Basic.publish chan, exchange, route, body, headers: headers
    end
  end

  # direct exchange, process where we left off; or assume time-out and make new queue?
  def responder(chan, amqp_msg, %{delivery_tag: tag, headers: amqp_meta}) do
    Logger.debug "responder: msg: #{String.valid?(amqp_msg)}"
    info_struc = amqp_unheader(amqp_meta)[:json] |> Poison.decode!() |> to_atoms() # |> as(Info)
    %{msg: msg_old, meta: meta} = info_struc
    AMQP.Basic.ack chan, tag
    msg_ = msg_old |> set([:cb_id], meta.req.cb_id)
    msg = case meta.route do
      "POST:/urls" ->
        msg_ |> set([:body], amqp_msg)
      "POST:/check" ->
        msg_ |> set([:body, :status], msg_.status) |> set([:body, :length], String.length(amqp_msg))
    end
    # AMQP.Basic.reject chan, tag, requeue: not redelivered
    meta.user |> String.to_atom() |> Api.Socket.get() |> send {:resp, msg, meta}
  end

end
