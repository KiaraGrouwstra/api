defmodule Chat do
  use Application
  # OTP: http://elixir-lang.org/docs/stable/elixir/Application.html
  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      supervisor(Chat.Endpoint, []),
      worker(Chat.AmqpPub, [Chat.Endpoint, []]),
      worker(Chat.AmqpSub, [Chat.Endpoint, [queue: {:join, "responses"}, lambda: &Chat.AmqpBiz.responder/3]], id: :responder),
      worker(Chat.AmqpSub, [Chat.Endpoint, [queue: {:make, "amq.rabbitmq.event", "queue.created"}, lambda: &Chat.AmqpBiz.creator/3]], id: :creator),
      # worker(Chat.AmqpSub, [Chat.Endpoint, [queue: {:make, "amq.rabbitmq.event", "queue.deleted"}, lambda: &Chat.AmqpBiz.deleter/3]], id: :deleter),
      worker(Chat.Throttler, [Chat.Endpoint, []]),
      worker(Chat.Repo, [])
    ]
    # strategies: http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    opts = [strategy: :one_for_one, name: Chat.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration whenever the application is updated.
  def config_change(changed, _new, removed) do
    Chat.Endpoint.config_change(changed, removed)
    :ok
  end
end
