defmodule Api.ThrottlerPool do
  import Api.GenSupervisor
  @mod Api.Throttler
  def start_link(_args \\ nil, opts \\ []), do: start_link(@mod, __MODULE__, opts)
  def init(:ok), do: init(:ok, @mod)
end
