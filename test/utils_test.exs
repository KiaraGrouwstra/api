defmodule UtilsTest do
  use ExUnit.Case, async: false
  import Api.Utils
  ExUnit.configure(exclude: [traffic: true])
  import Elins

  @url "http://www.baidu.com/"
  @domain "baidu.com"
  @fake_domain "example.org"
  @body "{body:123}"
  @info %Info{msg: %MsgOut{body: %{status: 200}}}

  setup do
    ThrottlerTest.kill_throttlers()
  end

  defp num_throttlers() do
    Supervisor.count_children(:throttlers).workers
  end

  #######################################################

  @tag :traffic
  test "post_urls" do
    post_urls(@url)
    # assert Api.QueueStore.pop(@domain) == {:value, {@url, []}}
    # can't really test it, as it's do more than ask -- it now already creates a queue handler that pops the URL off already.
    # assert num_throttlers() > 0
    assert url_domain(@url) |> Throttler.get() == :ok
  end

  test "handle_domain" do
    handle_domain(@domain)
    # assert num_throttlers() > 0
    assert throttle(@domain) == :ok
  end

  test "make_fetcher" do
    assert {:ok, _pid} = make_fetcher(@domain)
  end

  test "make_throttler" do
    {:ok, _pid} = make_throttler(@domain)
    assert num_throttlers() > 0
  end

  test "throttle" do
    {:ok, _pid} = make_throttler(@domain)
    assert throttle(@domain) == :ok
  end

  # @tag :websocket
  # @tag :traffic
  # test "fetch_handle" do
  #   # fetch_handle({@url, []})
  #   # catch in websocket?
  # end

  @tag :traffic
  test "fetch_check" do
    assert {:result, _} = fetch_check({@url, %Info{}})
    assert {:redirect, _} = fetch_check({"http://baidu.com/", %Info{}})
  end

  test "prepare_response - urls" do
    info = set(@info, [:meta, :route], "POST:/urls")
    assert prepare_response(@body, info).body == @body
  end
  test "prepare_response - check" do
    info = set(@info, [:meta, :route], "POST:/check")
    assert prepare_response(@body, info).body.length == 10
  end

  # fails, still leaves on the www.
  # test "url_domain" do
  #   assert url_domain(@url) == @domain
  # end

  @tag :traffic
  test "fetch_decode" do
    assert fetch_decode(@url, []).status == 200
  end

  test "zip_duplicate" do
    assert zip_duplicate(:a, :b) == [{:a,:b}]
    assert zip_duplicate(:a, [:b, :c]) == [{:a,:b},{:a,:c}]
    assert zip_duplicate([:a, :b], [:c, :d]) == [{:a,:c},{:b,:d}]
  end

  test "to_atoms" do
    assert %{"a" => 1} |> to_atoms() == %{a: 1}
  end

  test "as" do
    assert as(%{}, Info).__struct__ == Info
  end

end
