defmodule Api.GenSupervisor do
  use Supervisor

  @doc "make a general supervisor for a group of distinct workers of the same class"
  def start_link(mod, name, opts \\ []) do
    Supervisor.start_link(name, :ok, opts)
  end

  def init(:ok, mod) do
    children = [
      worker(mod, [])
    ]
    opts = [strategy: :simple_one_for_one, name: mod]
    supervise(children, opts)
  end

end
