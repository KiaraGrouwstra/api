# Erlang queue per domain on Amnesia
defmodule Api.QueueStore do
  import Logger
  use Amnesia
  use QueueDB

  # add acks
  # check performance

  # Api.QueueStore.push(domain, item)
  @doc "push an item to the stack"
  def push(item, domain) do
    Logger.debug "push(#{inspect({domain})})" # item,
    {status, queue} = get_queue(domain)
    q2 = :queue.in(item, queue)
    set_queue(domain, q2)
    status
  end

  # item = Api.QueueStore.pop(domain)
  @doc "try popping an item off the stack"
  def pop(domain) do
    # Logger.debug "pop(#{domain})"
    {_status, queue} = get_queue(domain)
    {out, q2} = :queue.out(queue)
    set_queue(domain, q2)
    out # either :empty or {:value, item}
  end

  @doc "initializes a (new or existing) domain to an empty queue"
  def init(domain) do
    queue = :queue.new()
    Amnesia.transaction do
      Queue.write(%Queue{ domain: domain, queue: queue })
    end
    queue
  end

  @doc "deletes the queue for a domain"
  def delete(domain) do
    Amnesia.transaction do
      Queue.delete(domain)
    end
  end

  @doc "iterate with a lambda"
  def iterate(fun) do
    Amnesia.transaction do
      Queue.where(true, select: domain)
      |> Amnesia.Selection.values
      |> Enum.each fun
    end
  end

  defp get_queue(domain) do
    # Logger.debug "get_queue(#{domain})"
    Amnesia.transaction do
      res = Queue.read(domain)
      case res do
        nil -> # new domain!
          {:created, init(domain)}
        %QueueDB.Queue{queue: queue} ->
          {:ok, queue}
      end
    end
  end

  defp set_queue(domain, queue) do
    # Logger.debug "set_queue(#{inspect({domain})})" # , queue
    Amnesia.transaction do
      %Queue{ domain: domain, queue: queue }
      |> Queue.write()
    end
  end

  @doc "consume a queue and handle it"
  def consume_queue(domain, fun) do
    case pop(domain) do
      :empty ->
        # Logger.debug "empty: #{domain}"
        :timer.sleep(1_000)
        # arbitrary; alternative: ditch domain at say x credits
      {:value, item} ->
        # Logger.debug "consuming: #{inspect(item)}"
        fun.(item)
    end
    consume_queue(domain, fun)
  end

end
