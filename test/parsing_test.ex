defmodule ParsingTest do
  ExUnit.configure(exclude: [traffic: true])
  use ExUnit.Case, async: false
  import Api.Utils
  import Elins

  @url "https://www.baidu.com/"
  @html "<html><head><title>hi</title></head><body></body></html>"
  @parselet "{\"header\":\"title\"}"

  test "parse - simple" do
    # %Porcelain.Result{status: 0, out: out}
    out = parse(@html, @parselet)
    assert out |> to_atoms() == %{header: "hi"} # %{"header" => "hi"} # |> Poison.decode!()
  end

  @tag :traffic
  test "parse - baidu" do
    body = decode(fetch(@url, [])).body
    # %Porcelain.Result{status: 0, out: _out}
    out = parse(body, @parselet)
    # assert String.length(out) > 0
    assert out["header"] |> String.length() > 0
  end

  @tag :traffic
  test "parse - taobao" do
    body = decode(fetch("https://www.taobao.com/", [])).body
    # %Porcelain.Result{status: 0, out: _out}
    out = parse(body, @parselet)
    # assert String.length(out) > 0
    assert out["header"] |> String.length() > 0
  end

end
