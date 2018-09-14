# mix test --include traffic:true
defmodule UtilsTest do
  ExUnit.configure(exclude: [traffic: true])
  use ExUnit.Case, async: false
  import Api.Utils
  # import Elins

  @url "https://www.baidu.com/"
  @domain "baidu.com"
  @body "{body:123}"
  # @resp %HTTPotion.Response{body: @body, headers: %{}, status_code: 200}

  setup do
    ThrottlerTest.kill_throttlers()
  end

  defp num_throttlers() do
    Supervisor.count_children(:throttlers).workers
  end

  #######################################################

  # @tag :traffic
  # test "post_urls" do
  #   post_urls(@url, [])
  #   assert Api.QueueStore.pop(@domain) == {:value, {@url, []}}
  #   # can't really test it, as it does more than ask -- it now already creates a queue handler that pops the URL off already.
  #   # uh, if the queues already existed it gets an :ok and doesn't create them. in this case test by popping back off instead?
  #   # assert num_throttlers() > 0
  #   # assert url_domain(@url) |> String.to_atom() |> Api.Throttler.get() == :ok
  # end

  test "handle_domain" do
    handle_domain(@domain)
    # assert num_throttlers() > 0
    assert throttle({ :str, @domain }) == :ok
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
    assert throttle({ :str, @domain }) == :ok
  end

  # @tag :websocket
  # @tag :traffic
  # test "fetch_handle" do
  #   # fetch_handle({@url, []})
  #   # catch in websocket?
  # end

  # fails, still leaves on the www.
  # test "url_domain" do
  #   assert url_domain(@url) == @domain
  # end

  # test "decode" do
  #   assert decode() == :foo
  # end

  @tag :traffic
  test "fetch" do
    assert {:ok, %HTTPotion.Response{}} = fetch(@url, [])
    assert %HTTPotion.Response{} = fetch!(@url, [])
  end

  test "zip_duplicate" do
    assert zip_duplicate(:a, :b) == [{:a,:b}]
    assert zip_duplicate(:a, [:b, :c]) == [{:a,:b},{:a,:c}]
    assert zip_duplicate([:a, :b], [:c, :d]) == [{:a,:c},{:b,:d}]
  end

  test "to_atoms" do
    assert %{"a" => 1} |> to_atoms() == %{a: 1}
  end

  test "to_atoms - recursive" do
    assert %{"a" => %{ "b" => "c" }} |> to_atoms() == %{a: %{ b: "c" }}
  end

  test "to_atoms - recursive through lists" do
    assert %{"a" => [ %{ "b" => "c" } ] } |> to_atoms() == %{a: [ %{ b: "c" } ] }
  end

  test "as" do
    assert as(%{}, Info).__struct__ == Info
  end

  test "de_jsonp" do
    html = "fn(\"<p src=\\\"lol\\\" />\")"
    assert de_jsonp(html) == "<p src=\"lol\" />"
  end

end
