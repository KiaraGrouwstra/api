Code.require_file "./support/helpers.ex", __DIR__
Code.require_file "./support/websocket_client.exs", __DIR__

defmodule IntegrationTest do
  use ExUnit.Case, async: false
  import Api.RoomChannel
  import Elins
  alias Phoenix.Integration.WebsocketClient

  @port 8080 #34055 #80 #8080 #5807
  @room "rooms:lobby"
  @msg %{"body" => "", "id" => 1, "headers" => %{}}
  @url "http://www.baidu.com/"

  setup_all do
    # Application.put_env(:phoenix, Endpoint, [
    #   https: false,
    #   http: [port: @port],
    #   secret_key_base: String.duplicate("abcdefgh", 8),
    #   debug_errors: false,
    #   server: true,
    #   pubsub: [adapter: Phoenix.PubSub.PG2, name: __MODULE__]
    # ])

    Api.Support.Helpers.launch_api
    # capture_log fn ->
      Api.Endpoint.start_link()
    # end
    :ok
  end

  test "/urls" do
    socket_send(@msg |> set(["body"], @url), "/urls").()
    assert_receive :foo # %Message{event: "phx_reply", payload: %{"response" => %{}, "status" => "ok"}, ref: "1", topic: "rooms:lobby1"}
  end

  defp socket_send(msg \\ @msg, route \\ "", room \\ @room) do
    {:ok, sock} = WebsocketClient.start_link(self, "ws://127.0.0.1:8080/socket/websocket") #"ws://localhost:#{@port}/socket") # 127.0.0.1  #ws_url()
    WebsocketClient.join(sock, @room, %{"user" => "tycho"})
    WebsocketClient.send_event(sock, @room, route, msg)
    # WebsocketClient.close(sock)
  end

  # API url helper - will work in any env
  # defp ws_url(path \\ "/socket") do
  #   endpoint_config = Application.get_env(:api, Api.Endpoint)
  #   host = Keyword.get(endpoint_config, :url) |> Keyword.get(:host)
  #   port = Keyword.get(endpoint_config, :http) |> Keyword.get(:port)
  #   url = "ws://#{host}:#{port}#{path}"
  #   IO.puts url
  #   url
  # end

end
