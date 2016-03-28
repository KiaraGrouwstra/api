defmodule Api.Parsing do
  require Logger

  defmodule SelectorError do
    defexception message: "Floki selector failed!"  # #{sel}
  end

  @doc "parse the DOM of a response body based on the given parselet (JSON string), returning a JSON result of extracted content"
  def parse(body, parselet) do
    # Logger.info "body: #{body}"
    # Logger.info "parselet: #{parselet}"
    # IO.puts "body: #{body}"
    # IO.puts "parselet: #{parselet}"
    # Logger.debug
    # Floki.find(body, "title") |> Floki.raw_html
    # parselet |> Poison.decode!() |> floki(body, &1)
    map = Poison.decode!(parselet)
    floki(body, map) #|> Poison.encode!()
    # html |> Floki.find(".pages a") |> Floki.attribute("href") |> Enum.map(fn(url) -> HTTPoison.get!(url) end)
    # %Result{out: out, status: 0} = Porcelain.exec("parsley", [parselet, body])
    # Logger.debug out
    # ^ to store the compiled parselet objects I should probably go the NIF route: https://github.com/elixir-lang/elixir/wiki/Interoperability-with-C
    # alt: parsleyc -r in_file -w out_file... or instead just return it as a string and pass it on as a parameter.
    # out
  end

  @doc "parse an HTML body/element based on a Parsley parselet value using Floki"
  # map
  def floki(body, map) when is_map(map) do
    map
    |> Enum.map(fn({k,v}) -> floki_element_prep({k,v}, body) end)
    |> Enum.filter(fn(x) -> x end)
    |> Enum.into(%{})
  end
  # string
  def floki(body, str, is_arr \\ false) do # when is_string(selector)
    if String.contains?(str, "@") do
      case String.split(str, "@", [parts: 2]) do
        # @ (empty attribute): get the inner html
        [sel, ""] ->
          floki_match(body, sel, fn(el) -> Floki.inner_html(el) end, is_arr)
        # @@: get the outer html
        [sel, "@"] ->
          floki_match(body, sel, fn(el) -> Floki.raw_html(el) end, is_arr)
        # otherwise get the @attribute
        [sel, attr] ->
          [match] = Floki.attribute(body, sel, attr)
          match
      end
    else
      # by default just grab the element text
      floki_match body, str, fn(el) -> Floki.text(el) end, is_arr
    end
  end

  @doc "get/transform the match for a selector"
  def floki_match(el, sel, fun \\ &(&1), is_arr \\ false) do
    res = Floki.find(el, sel)
    if is_arr do
      res |> Enum.map(fun.())
    else
      case res do
        # [] -> nil # if optional # nope, I'm handling this in floki_element_prep, since rescuing at an intermediate level allows bubbling it up
        # [] -> throw "floki selector #{sel} failed!"
        [] -> raise SelectorError, message: "floki selector #{sel} failed!\n\n#{el}\n\nfloki selector #{sel} failed!"
        list -> List.first(list) |> fun.()
      end
    end
  end

  @doc "handles optionality for parselet keys ending in '?'."
  def floki_element_prep({k, v}, body) do
    case Regex.run(~r/^([\w_]+)\?$/, k) do
      [_k, optional] ->
        try do
          floki_element({optional, v}, body)
        rescue
          e in SelectorError ->
            nil
        end
      _ ->
        floki_element({k, v}, body)
    end
  end

  @doc "transform a key-value pair into its extracted result"
  # map
  def floki_element({k, [map]}, body) when is_map(map) do  # when is_list(v)
    {arr_name, selector} = case Regex.run(~r/([\w_]+)\((.+)\)/, k) do
      [_k, a, b] -> {a, b}
      _ -> throw "bad array key #{k}!"
    end
    arr = Floki.find(body, selector)
      |> Enum.map(fn(elem) ->
        elem |> Floki.raw_html |> floki(map)
      end)
    {arr_name, arr}
  end
  # array
  def floki_element({k,[v]}, body) do
    {k, floki(body, v, true)}
  end
  # string
  def floki_element({k,v}, body) do # when is_string(v)
    {k, floki(body, v, false)}
  end

end
