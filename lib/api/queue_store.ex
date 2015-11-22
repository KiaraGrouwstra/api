# Erlang queue per domain on Amnesia
defmodule Api.QueueStore do
  use Amnesia
  # use ExActor.GenServer
  # def start_link(args \\ nil, opts \\ [name: __MODULE__]), do: GenServer.start_link(__MODULE__, args, opts)

  # Api.QueueStore.push(domain, item)
  # Api.QueueStore.push(:queues, item)
  @doc "push an item to the stack"
  # defcast push(item), state: domain do
  def push(item, domain) do
    queue = get_queue(domain)
    q2 = :queue.in(item, queue)
    set_queue(domain, q2)
    # new_state q2
    :ok
  end

  # item = Api.QueueStore.pop(domain)
  # item = Api.QueueStore.pop(:queues)
  @doc "try popping an item off the stack"
  # defcall pop, state: domain do
  def pop(domain) do
    queue = get_queue(domain)
    {out, q2} = :queue.out(queue) # either :empty or {:value, item}
    set_queue(domain, q2)
    # set_and_reply(q2, out)
    out
  end

  defp get_queue(domain) do
    Amnesia.transaction do
      Queues.read(domain).queue
    end
  end

  defp set_queue(domain, queue) do
    Amnesia.transaction do
      Queues.write(%{ domain: domain, queue: queue }) # %Queue
    end
  end

end
