defmodule Chat.AmqpBiz do
  require Logger

  # pub

  def post_urls(msg, options \\ []) do
    Logger.debug "post_urls"
    chan = Chat.AmqpPub.get_chan()
    # chan = Chat.AmqpSub.get_chan()
    # splits on and trims whitespace
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
      # Chat.AmqpPub.make_queue(chan, domain)
      AMQP.Queue.declare chan, domain
      AMQP.Queue.bind chan, domain, exchange, [routing_key: domain]
      # Chat.AmqpPub.publish(chan, url, domain, options)
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

  def make_fetcher(chan, queue) do
    # create queue monitor with this name plus a given throttling rate
    {:ok, _pid} = Chat.AmqpSub.start_link(&(&1), [queue: {:join, queue}, lambda: &Chat.AmqpBiz.fetcher/3, chan: chan]) # , name: queue
  end

  def sub_existing(chan) do
    # poll http://localhost:15672/api/bindings with auth test:test; filter results by "source":"urls"; grab resulting `destination` or `routing_key`
    resp = HTTPotion.get "http://localhost:15672/api/bindings", [basic_auth: {"test", "test"}]
    %HTTPotion.Response{body: body, status_code: 200} = resp
    Poison.decode!(body)
    |> Enum.filter_map(
      fn(x) -> Map.get(x, "source") == "urls" end,
      fn(x) -> Map.get(x, "destination") end
    )
    |> Enum.each fn(queue) -> make_fetcher(chan, queue) end
  end

  # tag: %{consumer_tag: consumer_tag, delivery_tag: delivery_tag, redelivered: redelivered, exchange_name: exchange, shortstr: routing_key} = tag
  # relevant: %{routing_key: route, reply_to: reply_to, headers: headers}

  # sub

  # direct; from the start? or assume we can ignore since old connections are probably timed out already and continue instead from now?
  def responder(chan, msg, tag) do
    Logger.debug "responder"
    name = String.to_atom(tag.reply_to)  # alt: routing_key
    ws_chan = Chat.Socket.get(name)
    # Phoenix.Channel.push(socket, "resp", %{data: msg})
    send(ws_chan, {:resp, msg})
    AMQP.Basic.ack chan, tag
    # Basic.reject chan, tag, requeue: not redelivered
    Logger.debug "tried sending response #{msg} to user #{tag.reply_to}!"
  end

  # from now (new queue); topic; make new private queue attached to `amq.rabbitmq.event` by routing key `queue.created`?
  def creator(chan, _msg, tag) do
    Logger.debug "creator"
    queue = get_header(tag.headers, "name")
    make_fetcher(chan, queue)
  end

  # from now (new queue); topic
  # def deleter(_chan, _msg, tag) do
  #   _queue = get_header(tag.headers, "name")
  #   # TODO: kill queue fetcher with this name
  # end

  # ^ are all those exchanges fanout? How to deal with shared distributed queues if I'm gonna be making new private queues?

  # from the start; topic; many different queues
  def fetcher(chan, msg, %{routing_key: route, reply_to: addr, headers: _headers}) do
    Logger.debug "fetcher"
    domain = route
    # Logger.debug "testing..."
    # :ok = Chat.Throttler.test()
    # Logger.debug "test ok!"
    # Logger.debug "gonna ask permission"
    pid = :erlang.whereis(Chat.Throttler)
    :ok = Chat.Throttler.get(pid, domain)
    Logger.debug "got permission!"
    url = msg
    head = [] # str |> Poison.decode! |> Enum.map(fn({k, v}) -> {String.to_atom(k), v} end)
    resp = HTTPotion.get url, [headers: head]
    %HTTPotion.Response{body: body, headers: _headers, status_code: status} = resp
    Logger.debug "status: #{status}"
    case status do
      x when x in 200..299 -> # OK
      # x when x in 300..399 -> # redirect
      # x when x >= 400      -> # error
    end
    # TODO: can I do manual acking here to ensure unhandled messages will return to the todo queue?
    Logger.debug "fetched page #{url} for #{addr}, posting to responses!"
    AMQP.Basic.publish chan, "responses", addr, body, [reply_to: addr]
    # part = 0
    # KafkaEx.produce("dumps", part, body)
  end

end
