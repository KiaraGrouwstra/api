defmodule Calculator do
  use ExActor.GenServer
  defstart start_link, do: initial_state(0)
  # def start_link, do: GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  # def init(_), do: {:ok, 0}
  defcall get, state: state, do: reply(state)
  # def get(pid), do: GenServer.call(pid, :get)
  # def handle_call(:get, _, state), do: {:reply, state, state}
end
