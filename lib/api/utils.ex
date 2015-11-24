defmodule Api.Utils do
  require Logger
  # alias Porcelain.Result
  import Elins

  ########## SIDE-EFFECTS ###############################

  @doc "for arrays of URLs and options, posts each pair to the fetching queue."
  def post_urls(urls, opts \\ []) do
    Logger.debug "post_urls"
    Api.Utils.zip_duplicate(urls, opts) |> Enum.each fn({url, opt}) ->
    # for url <- urls, opt <- opts do  # does a cartesian, ok for 1:n/n:1 but for n:n I need zip instead...
      domain = url_domain(url)
      opt_ = opt |> set [:meta, :misc], %{domain: domain} #, :domain], domain
      # ^ TODO: fix Elins to take non-existent keys into account
      status = Api.QueueStore.push({url, opt_}, domain)
      # if status == :created, do: handle_domain(domain)
      case status do
        :created -> handle_domain(domain)
        :ok -> :noop
      end
    end
  end

  @doc "create fetcher/throttler for this domain"
  def handle_domain(domain) do
    Logger.debug "handle_domain(#{domain})"
    make_fetcher(domain)
    make_throttler(domain)
  end

  @doc "create fetcher for this domain"
  def make_fetcher(domain) do
    Logger.debug "make_fetcher(#{domain})"
    Task.start_link fn() -> Api.QueueStore.consume_queue(domain, &fetch_handle/1) end
  end

  @doc "create throttler for this domain"
  def make_throttler(domain) do
    Logger.debug "make_throttler(#{domain})"
    opts = [name: domain |> String.to_atom() ]
    {:ok, _pid} = Supervisor.start_child(:throttlers, [nil, opts])
  end

  @doc "fetch url and handle result"
  def fetch_handle({url, info}) do
    Logger.debug "fetch_handle(#{inspect({url, info})})"
    domain = info.meta.misc.domain
    throttle(domain)
    case fetch_check({url, info}) do
      {:redirect, url_info} ->
        Api.QueueStore.push(domain, url_info)
      {:result, {body, info}} ->
        msg = prepare_response(body, info)
        Logger.debug "response ready!"
        try do
          socket = info.meta.user |> Api.Socket.get()
          # sockets may be forgotten throughout restarts (they'd be disconnected anyway)
          send socket, {:resp, msg, info.meta}
        rescue
          _e in ArgumentError -> :noop  # not actually catching anything...
        end
    end
  end

  ########## FUNCTIONAL ###############################

  @doc "throttle a fetch request for the given domain"
  def throttle(domain) do
    Logger.debug "throttle(#{domain})"
    # :ok = Api.Throttler.get(domain |> String.to_atom())
    :ok = GenServer.call(domain |> String.to_atom(), :get, 5_000)
    # ^ might need to set the timeout to inf...
  end

  @doc "fetch url, check status"
  def fetch_check({url, info_}) do
    Logger.debug "fetch_check(#{inspect({url, info_})})"
    %HTTPotion.Response{body: body, headers: resp_headers, status_code: status} = fetch_decode(url, info_.meta.req.headers) # [:meta][:req][:headers]
    info = info_ |> set [:msg, :status], status
    # Logger.debug Floki.find(body, "title") |> Floki.raw_html
    # html |> Floki.find(".pages a") |> Floki.attribute("href") |> Enum.map(fn(url) -> HTTPoison.get!(url) end)
    # parselet = "{\"header\":\"h1\"}"
    # %Result{out: output, status: 0} = Porcelain.exec("parsley", [parselet, body])
    # Logger.debug output
    # ^ to store the compiled parselet objects I should probably go the NIF route: https://github.com/elixir-lang/elixir/wiki/Interoperability-with-C
    # alt: parsleyc -r in_file -w out_file... or instead just return it as a string and pass it on as a parameter.
    case status do
      x when x in 200..299 -> # OK
        Logger.debug "fetched page #{url}, posting to responses!"
        {:result, {body, info}}
        # part = 0
        # KafkaEx.produce("dumps", part, body)
      x when x in 300..399 -> # redirect
        location = resp_headers[:Location]
        Logger.info "Redirecting from #{url} to #{location}"
        {:redirect, {location, info}}
        # use tries/redirects flag to prevent infinite loops?
      x when x >= 400 -> # error
        Logger.warn "Page #{url} resulted in error #{x}!"
        {:result, {body, info}}
    end
  end

  @doc "prepare message for response to the websocket"
  def prepare_response(val, %{msg: msg_, meta: meta}) do
    Logger.debug "responder: #{String.valid?(val)}"
    msg = msg_ |> set([:cb_id], meta.req.cb_id)
    case meta.route do
      "POST:/urls" ->
        msg |> set([:body], val)
      "POST:/check" ->
        # msg |> set([:body, :status], msg.status)
        #     |> set([:body, :length], byte_size(val) })
        msg |> set([:body], %{status: msg.status, length: byte_size(val)})
        # TODO: fix Elins for non-existing map keys; this approach is over-writing existing keys.
    end
  end

  @doc "extract the domain from a URL"
  def url_domain(url) do
    Logger.debug "url_domain(#{url})"
    uri = URI.parse(url)
    host = uri.host
    # TODO: strip off www(2?) and subdomains, i.e. just get the "\w+\.\w+$"...?
    # but assumes 1 TLD, failing for dual ones like .co.uk
    # and for none (IP-based, localhost), though those should lack subs too...
    # dual TLDs to pattern-match against: https://en.wikipedia.org/wiki/Second-level_domain
    # http://stackoverflow.com/a/14662475/1502035
    # on that topic I'll wanna block having people use my scraper on its own localhost, 127.0.0.1, 192.168.*.*...
    domain = host
    domain
  end

  @doc "fetch a URL and normalize its encoding to UTF-8"
  def fetch_decode(url, req_headers) do
    resp = HTTPotion.get url, [headers: req_headers]
    %{body: enc_body, headers: resp_headers, status_code: status} = resp # %HTTPotion.Response #
    Logger.debug "fetcher: url: #{url}; req_headers: #{inspect(req_headers)}; status: #{status}; resp_headers: #{inspect(resp_headers)}; body: #{byte_size(enc_body)} (#{String.valid?(enc_body)});}"
    body = try do
      [encoding] = Regex.run(~r/(?<=charset=)[\w-]+/, resp_headers[:"Content-Type"])
      Logger.debug "encoding: #{encoding}"
      case encoding do
        "utf-8" -> enc_body
        _ -> case :iconverl.conv("utf-8", encoding, enc_body) do
          {:error, :eilseq} ->
            Logger.warn "DECODING ERROR"
            enc_body
          {:ok, b} -> b
        end
      end
    rescue
      _e in ArgumentError -> enc_body  # placeholder -- first figure out what to fix, when to use fallback
    end
    Logger.debug "decoded: #{byte_size(body)} (#{String.valid?(body)})"
    # %HTTPotion.Response{body: body, headers: resp_headers, status_code: status}
    resp |> Elins.set [:body], body
  end

  @doc "duplicates non-lists then zips -- zip only does n:n; '<-' cartesians lists so n:1/1:n; this does both."
  # does this beat using <- to duplicate non-lists in the room_channel functions?
  def zip_duplicate(a, b) when is_list(a) and is_list(b) do
    Enum.zip(a,b)
  end
  def zip_duplicate(a, b) when is_list(a) do
    b_ = List.duplicate(b, Enum.count(a))
    zip_duplicate(a, b_)
  end
  def zip_duplicate(a, b) when is_list(b) do
    a_ = List.duplicate(a, Enum.count(b))
    zip_duplicate(a_, b)
  end
  def zip_duplicate(a, b) do
    [{a,b}]
  end

  @doc "convert a map's string keys to atoms"
  def to_atoms(map) do
    map |> Enum.into(%{}, fn
      {k,v} when is_map(v) -> {String.to_atom(k), to_atoms(v)}
      {k,v}                -> {String.to_atom(k), v}
    end)
  end

  @doc "convert a map to a given struct"
  def as(map, struc) do
    struct(struc, map)
  end

end
