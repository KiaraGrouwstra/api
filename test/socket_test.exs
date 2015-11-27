defmodule SocketTest do
  use ExUnit.Case, async: false
  import Api.Socket

  @user "dummy_user"

  setup do
    # pid =
    start_link(self(), @user)
    # on_exit fn ->
    #   Supervisor.terminate_child(self(), pid)
    # end
    {:ok, []}
  end

  test "get" do
    assert get(@user |> String.to_atom()) |> is_pid()
  end

end
