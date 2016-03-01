defmodule Api.Utils do
  require Logger
  # alias Porcelain.Result
  import Elins

  ########## SIDE-EFFECTS ###############################

  @doc "for arrays of URLs and options, posts each pair to the fetching queue."
  def post_urls(urls, opts \\ []) do
    Logger.debug "post_urls"
    Api.Utils.zip_duplicate(urls, opts) |> Enum.each(fn({url, opt}) ->
    # for url <- urls, opt <- opts do  # does a cartesian, ok for 1:n/n:1 but for n:n I need zip instead...
      domain = url_domain(url)
      opt_ = opt |> set([:misc, :domain], domain).()
      status = Api.QueueStore.push({url, opt_}, domain)
      case status do
        :created -> handle_domain(domain)
        :ok -> :noop
      end
    end)
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
    # Logger.debug "fetch_handle(#{inspect({url, info})})"
    domain = info.misc.domain
    throttle(domain)
    res = url
    |> fetch(info.req.headers)
    |> decode()
    case res.status_code do
      x when x in 300..399 -> # redirect
        url = res.resp_headers[:Location]
        Api.QueueStore.push(domain, {url, info})
        # retry count?
      x ->
        Api.RoomChannel.respond(info.route, info, res)
        |> send_resp(info.user)
    end
  end

  @doc "send message to a user"
  def send_resp(msg, user_) do
    user = String.to_atom(user_)
    # sockets may be forgotten throughout restarts (they'd be disconnected anyway)
    # no error to catch (it just quits) so must check manually instead...
    case Process.whereis(user) do
      :nil ->
        Logger.debug "user #{user} lost, discarding..."
      _pid ->
        Logger.debug "posting to #{user}!"
        socket = Api.Socket.get(user) # pid
        send socket, {:resp, msg}
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

  @utf8 "utf-8"
  @doc "decode a response to UTF-8"
  def decode(%HTTPotion.Response{body: enc_body, headers: resp_headers} = resp) do
    # Logger.debug "fetcher: url: #{url}; req_headers: #{inspect(req_headers)}; status: #{status}; resp_headers: #{inspect(resp_headers)}; body: #{byte_size(enc_body)} (#{String.valid?(enc_body)});}"
    body = try do
      type = resp_headers[:"Content-Type"]
      Logger.debug type
      encoding = case Regex.run(~r/(?<=charset=)[\w-]+/, type) do
        [enc] -> enc
        _ -> @utf8
      end
      Logger.debug "encoding: #{encoding}"
      case encoding do
        @utf8 -> enc_body
        _ -> case :iconverl.conv(@utf8, encoding, enc_body) do
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
    resp |> Elins.set([:body], body).()
  end

  @doc "fetch a page, retrying on failure..."
  def fetch(url, req_headers, opts \\ []) do
    try do
      HTTPotion.get url, Keyword.merge([headers: req_headers, timeout: 5_000], opts)
    rescue
      e in HTTPotion.HTTPError ->
        Logger.info "httppotion error: #{e.message}"
        Logger.info "retrying fetch for #{url}..."
        :timer.sleep 1_000
        fetch(url, req_headers)
    end
  end

  @doc "extract the domain from a URL"
  def url_domain(url) do
    # Logger.debug "url_domain(#{url})"
    uri = URI.parse(url)
    host = uri.host
    # TODO: strip off www(2?) and subdomains, i.e. just get the "\w+\.\w+$"...?
    # but assumes 1 TLD, failing for dual ones like .co.uk
    # and for none (IP-based, localhost), though those should lack subs too...
    # dual TLDs to pattern-match against: https://en.wikipedia.org/wiki/Second-level_domain
    # https://github.com/publicsuffix/list/blob/master/public_suffix_list.dat
    # ^ if I get the first match given current order it may just match just the final part instead of both; resort?
    # http://stackoverflow.com/a/14662475/1502035
    # on that topic I'll wanna block having people use my scraper on its own localhost, 127.0.0.1, 192.168.*.*...
    domain = host
    domain
  end

  def de_jsonp(str) do
    # case Regex.run(~r/^\s*([\w_]*)\s*\("(.+)\s*"\)\;?\s*$/, str) do
    case Regex.run(~r/^\s*([\w_]*)\s*\((.*)\)\;?\s*$/, str) do
      [_snip, function, val] ->
        # String.replace(html, "\\\"", "\"")
        Poison.decode!(val)
      _ -> throw "[#{str}] did not match JSONP pattern!"
    end
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
  # map
  def to_atoms(map) when is_map(map) do
    map |> Enum.into(%{}, fn
      {k,v} -> {String.to_atom(k), to_atoms(v)}
    end)
  end
  # list
  def to_atoms(list) when is_list(list) do
    Enum.map(list, fn (x) -> to_atoms(x) end)
  end
  # scalar
  def to_atoms(x) do
    x
  end

  @doc "convert a map to a given struct"
  def as(map, struc) do
    struct struc, map
  end

end
