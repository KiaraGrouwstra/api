defmodule Api.Parsing do
  require Logger

  @doc "parse the DOM of a response body based on the given parselet, returning a JSON result of extracted content"
  def parse(body, parselet) do
    # Logger.info "body: #{body}"
    Logger.info "parselet: #{parselet}"
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

  @doc "parse an HTML body/element based on a Parsley parslet using Floki"
  def floki(body, map) when is_map(map) do  #, is_array \\ false
    map |> Enum.into %{}, fn({k,v}) -> floki_element({k,v}, body) end
    # for {k, v} <- map, into: %{}, do
    #   {k, floki(body,v)}
    # end
  end
  def floki(body, str) do # when is_string(selector)
    # Floki.find(body, selector) |> List.first() |> Floki.raw_html
    # selector = str
    el = case String.contains?(str, "@") do
      false ->
        # case Floki.find(body, str) do
        #   [] -> nil
        #   list -> List.first(list) |> Floki.text
        # end
        floki_first body, str, fn(el) -> Floki.text(el) end
      true ->
        case String.split(str, "@") do
          [sel, attr] ->
            Floki.attribute(body, sel, attr)
          [sel] ->
            # Floki.find(body, sel) |> List.first() |> Floki.raw_html
            floki_first body, sel, fn(el) -> Floki.raw_html(el) end
          # TODO: if I can implement inner_html on Floki, can I use a final @ for inner, @@ for outer html?
        end
    end
    el
  end
  def floki_first(body, sel, fun) do
    case Floki.find(body, sel) do
      # [] -> nil # only if optional
      [] -> throw "floki selector #{sel} failed!"
      list -> List.first(list) |> fun.()
    end
  end
  def floki_element({ k, [map] }, body) when is_map(map) do  # when is_list(v)
    # "#{arr_name}(#{selector})" = k
    # arr_name <> "(" <> selector <> ")" = k
    {arr_name, selector} = case Regex.run(~r/([\w_]+)\((.+)\)/, k) do
      [_k, a, b] -> {a, b}
      _ -> throw "bad array key #{k}!"
    end
    arr = Floki.find(body, selector)
      |> Enum.map fn(elem) ->
        elem |> Floki.raw_html |> floki(map)
      end
    {arr_name, arr}
  end
  def floki_element({k,v}, body) do # when is_string(v)
    {k, floki(body,v)}
  end

end
