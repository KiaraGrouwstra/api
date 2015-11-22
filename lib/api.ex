defmodule Api do
  use Application
  # OTP: http://elixir-lang.org/docs/stable/elixir/Application.html
  @manager Api.Endpoint
  import Supervisor.Spec, warn: false

  def start(_type, _args) do
    children = [
      supervisor(@manager, []),
      worker(Api.AmqpPub, [@manager, []]),
      worker(Api.AmqpSub, [@manager, [queue: {:join, "responses"}, lambda: &Api.AmqpBiz.responder/3]], id: :responder),
      worker(Api.AmqpSub, [@manager, [queue: {:make, "amq.rabbitmq.event", "queue.created"}, lambda: &Api.AmqpBiz.creator/3]], id: :creator),
      # worker(Api.AmqpSub, [@manager, [queue: {:make, "amq.rabbitmq.event", "queue.deleted"}, lambda: &Api.AmqpBiz.deleter/3]], id: :deleter),
      worker(Api.ThrottlerPool, [@manager, [name: :throttlers]]),
      # worker(Api.QueueStore, [@manager, [name: :queues]]),
      worker(Api.Repo, [])
    ]
    # strategies: http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    opts = [strategy: :one_for_one, name: Api.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration whenever the application is updated.
  def config_change(changed, _new, removed) do
    Api.Endpoint.config_change(changed, removed)
    :ok
  end
end
