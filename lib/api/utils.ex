defmodule Api.Utils do
  require Logger

  def get_header(lst,k) do
    Enum.find(lst, nil, fn(x) -> elem(x, 0) == k end) |> elem(2)
  end

  @doc "subscribe to the existing URL queues (before monitoring for newly created ones)"
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

  @doc "create queue monitor with this name plus a given throttling rate"
  def make_fetcher(chan, queue) do
    {:ok, _pid} = Api.AmqpSub.start_link(&(&1), [queue: {:join, queue}, lambda: &Api.AmqpBiz.fetcher/3, chan: chan]) # , name: queue
  end

  @doc "converts headers back from their AMQP format (tuples of name/type/value) to keyword lists."
  def amqp_unheader(list) do
    Enum.map(list, fn
      {name, _type, val} -> {String.to_atom(name), val} # |> Enum.into(%{})
    end)
  end

  def url_domain(url) do
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

  def fetch_decode(url, req_headers) do
    resp = HTTPotion.get url, [headers: req_headers]
    %HTTPotion.Response{body: enc_body, headers: resp_headers, status_code: status} = resp
    Logger.debug "fetcher: url: #{url}; req_headers: #{inspect(req_headers)}; status: #{status}; resp_headers: #{inspect(resp_headers)}; body: #{String.length(enc_body)} (#{String.valid?(enc_body)});}"
    body = try do
      [encoding] = Regex.run(~r/(?<=charset=)[\w-]+/, resp_headers[:"Content-Type"])
      if encoding == "utf-8", do: enc_body, else: :iconverl.conv("utf-8", encoding, enc_body)
    rescue
      _e in ArgumentError -> enc_body  # placeholder -- first figure out what to fix, when to use fallback
    end
    %HTTPotion.Response{body: body, headers: resp_headers, status_code: status}
  end

  @doc """
  duplicates non-lists then zips -- used as a zip alternative cuz regular zip only takes n:n pairs; this addresses n:1/1:n too.
  """
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

  def to_atoms(map) do
    map |> Enum.into(%{}, fn
      {k,v} when is_map(v) -> {String.to_atom(k), to_atoms(v)}
      {k,v}                -> {String.to_atom(k), v}
    end)
  end

  def as(map, struc) do
    struct(struc, map)
  end

end
