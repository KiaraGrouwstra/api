defmodule ParsingTest do
  ExUnit.configure(exclude: [traffic: true])
  use ExUnit.Case, async: false
  import Api.Utils
  import Api.Parsing
  import Elins

  @url "https://www.baidu.com/"
  @html "<html><head><title>hi</title></head><body><p class=\"text\">foo</p></body></html>"
  # @parselet "{\"header\":\"title\"}"
  @simple %{header: "title"} |> Poison.encode!
  @parselet %{header: "title", p: "p"} |> Poison.encode!
  @will_throw %{header: "title", p: "p", "img": "not_there"} |> Poison.encode!
  @optional %{header: "title", p: "p", "img?": "not_there"} |> Poison.encode!
  @table %{"words(body)": [ %{ p: "p" } ] } |> Poison.encode!
  @table_optional %{"words(body)": [ %{ p: "p", "img?": "not_there" } ] } |> Poison.encode!
  @table_empty %{"words(body)": [ %{ "pic?": "img" } ] } |> Poison.encode!
  @html_sel "<html><body><table><td>foo</td><tr><td>bar</td><td>baz</td></tr><tr><td>cow</td></tr><tr></tr></table></body></html>"
  @json_sel %{ "words(tr)": [ %{ "item?": "td" } ] } |> Poison.encode!()
  @outer %{header: "title@@"} |> Poison.encode!
  @inner %{header: "head@"} |> Poison.encode!
  @attr %{attr: "p@class"} |> Poison.encode!

  test "parse - simple" do
    # %Porcelain.Result{status: 0, out: out}
    out = parse(@html, @simple)
    assert out |> to_atoms() == %{ header: "hi"}
  end

  test "parse - failure" do
    assert_raise Api.Parsing.SelectorError, fn -> parse(@html, @will_throw) end
  end

  test "parse - optional" do
    out = parse(@html, @optional)
    assert out |> to_atoms() == %{ header: "hi", p: "foo" }
  end

  test "parse - table" do
    out = parse(@html, @table)
    assert out |> to_atoms() == %{ words: [ %{ p: "foo" } ] }
  end

  test "parse - table with optional entry" do
    out = parse(@html, @table_optional)
    assert out |> to_atoms() == %{ words: [ %{ p: "foo" } ] }
  end

  test "parse - table with empty entry" do
    out = parse(@html, @table_empty)
    assert out |> to_atoms() == %{ words: [ %{} ] }
  end

  test "parse - complex" do
    out = parse(@html_sel, @json_sel)
    assert out |> to_atoms() == %{ words: [ %{item: "bar"}, %{item: "cow"}, %{} ] }
  end

  test "parse - outer" do
    out = parse(@html, @outer)
    assert out |> to_atoms() == %{ header: "<title>hi</title>" }
  end

  test "parse - inner" do
    out = parse(@html, @inner)
    assert out |> to_atoms() == %{ header: "<title>hi</title>" }
  end

  test "parse - attr" do
    out = parse(@html, @attr)
    assert out |> to_atoms() == %{ attr: "text" }
  end

  @tag :traffic
  test "parse - baidu" do
    body = decode(fetch!(@url, [])).body
    # %Porcelain.Result{status: 0, out: _out}
    out = parse(body, @parselet)
    # assert String.length(out) > 0
    assert out["header"] |> String.length() > 0
  end

  @tag :traffic
  test "parse - taobao" do
    body = decode(fetch!("https://www.taobao.com/", [])).body
    # %Porcelain.Result{status: 0, out: _out}
    out = parse(body, @parselet)
    # assert String.length(out) > 0
    assert out["header"] |> String.length() > 0
  end

end
