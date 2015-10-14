defmodule Api do
  use Application
  # OTP: http://elixir-lang.org/docs/stable/elixir/Application.html
  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      supervisor(Api.Endpoint, []),
      worker(Api.AmqpPub, [Api.Endpoint, []]),
      worker(Api.AmqpSub, [Api.Endpoint, [queue: {:join, "responses"}, lambda: &Api.AmqpBiz.responder/3]], id: :responder),
      worker(Api.AmqpSub, [Api.Endpoint, [queue: {:make, "amq.rabbitmq.event", "queue.created"}, lambda: &Api.AmqpBiz.creator/3]], id: :creator),
      # worker(Api.AmqpSub, [Api.Endpoint, [queue: {:make, "amq.rabbitmq.event", "queue.deleted"}, lambda: &Api.AmqpBiz.deleter/3]], id: :deleter),
      worker(Api.Throttler, [Api.Endpoint, []]),
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
