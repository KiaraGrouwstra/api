defmodule Chat.Socket do

  def start_link(ws, name) do
    Agent.start_link(fn -> ws end, name: String.to_atom(name))
  end

  def get(name) do
    Agent.get(name, &(&1))
  end

end
