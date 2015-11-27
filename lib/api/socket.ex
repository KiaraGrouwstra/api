# should I like use that (D)ETS for storing stuff?

defmodule Api.Socket do

  @doc "store the socket of a user"
  def start_link(ws, user) do
    name = String.to_atom(user)
    Agent.start_link(fn -> ws end, name: name)
  end

  @doc "get the socket for this user"
  def get(name) do
    Agent.get(name, &(&1))
  end

end
