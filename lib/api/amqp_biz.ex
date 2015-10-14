defmodule Api.AmqpBiz do
  require Logger

  # pub

  def post_urls(msg, options \\ []) do
    Logger.debug "post_urls"
    chan = Api.AmqpPub.get_chan()
    urls = String.split(msg)
    Enum.each urls, fn(url) ->
      uri = URI.parse(url)
      host = uri.host
      # TODO: strip off www(2?) and subdomains, i.e. just get the "\w+\.\w+$"...?
      # but assumes 1 TLD, failing for dual ones like .co.uk
      # and for none (IP-based, localhost), though those should lack subs too...
      # dual TLDs to pattern-match against: https://en.wikipedia.org/wiki/Second-level_domain
      # http://stackoverflow.com/a/14662475/1502035
      # on that topic I'll wanna block having people use my scraper on its own localhost, 127.0.0.1, 192.168.*.*...
      domain = host
      exchange = "urls"
      AMQP.Queue.declare chan, domain
      AMQP.Queue.bind chan, domain, exchange, [routing_key: domain]
      AMQP.Basic.publish chan, exchange, domain, url, options
    end
    # return the size for the notification message
    num = Enum.count(urls)
    {:ok, num}
  end

  # misc

  def get_header(lst,k) do
    Enum.find(lst, nil, fn(x) -> elem(x, 0) == k end) |> elem(2)
  end

  # create queue monitor with this name plus a given throttling rate
  def make_fetcher(chan, queue) do
    {:ok, _pid} = Api.AmqpSub.start_link(&(&1), [queue: {:join, queue}, lambda: &Api.AmqpBiz.fetcher/3, chan: chan]) # , name: queue
  end

  def sub_existing(chan) do
    resp = HTTPotion.get "http://localhost:15672/api/bindings", [basic_auth: {"test", "test"}]
    %HTTPotion.Response{body: body, status_code: 200} = resp
    Poison.decode!(body)
    |> Enum.filter_map(
      fn(x) -> Map.get(x, "source") == "urls" end,
      fn(x) -> Map.get(x, "destination") end
    )
    |> Enum.each fn(queue) -> make_fetcher(chan, queue) end
  end

  # converts headers back from their AMQP format (tuples of name/type/value) to keyword lists.
  def headers_to_keywords(list) do
    Enum.map(list, fn(
      {name, type, value}) -> {String.to_atom(name), value}
    end )
  end

  # sub

  # direct exchange, process where we left off; or assume time-out and make new queue?
  def responder(chan, msg, %{routing_key: route, reply_to: addr, headers: headers}) do
    Logger.debug "responder: msg: #{String.valid?(msg)}}"
    name = String.to_atom(addr)  # alt: route
    ws_chan = Api.Socket.get(name)
    send(ws_chan, {:resp, msg, headers_to_keywords(headers)})
    # AMQP.Basic.ack chan, tag
    # Basic.reject chan, tag, requeue: not redelivered
  end

  def creator(chan, _msg, tag) do
    Logger.debug "creator"
    queue = get_header(tag.headers, "name")
    make_fetcher(chan, queue)
  end

  # def deleter(_chan, _msg, tag) do
  #   _queue = get_header(tag.headers, "name")
  #   # TODO: kill queue fetcher with this name
  # end

  # ^ How to deal with shared distributed queues if I'm gonna be making new private queues?

  # from the start; topic; many different queues
  def fetcher(chan, msg, %{routing_key: route, reply_to: addr, headers: headers}) do
    Logger.debug "fetcher"
    domain = route
    pid = :erlang.whereis(Api.Throttler)
    :ok = Api.Throttler.get(pid, domain)
    url = msg
    head = [] # str |> Poison.decode! |> Enum.map(fn({k, v}) -> {String.to_atom(k), v} end)
    resp = HTTPotion.get url, [headers: head]
    %HTTPotion.Response{body: body, headers: headers, status_code: status} = resp
    Logger.debug "fetcher: status: #{status}; headers: #{inspect(headers)}; body: #{String.valid?(body)};}"
    case status do
      x when x in 200..299 -> # OK
      # x when x in 300..399 -> # redirect
      # x when x >= 400      -> # error
    end
    # TODO: can I do manual acking here to ensure unhandled messages will return to the todo queue?
    # Logger.debug "fetched page #{url} for #{addr}, posting to responses!"
    AMQP.Basic.publish chan, "responses", addr, body, [reply_to: addr, headers: headers]
    # part = 0
    # KafkaEx.produce("dumps", part, body)
  end

end
