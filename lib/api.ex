defmodule Api do
  use Application
  # OTP: http://elixir-lang.org/docs/stable/elixir/Application.html
  @manager Api.Endpoint
  import Supervisor.Spec, warn: false

  def start(_type, _args) do
    children = [
      supervisor(@manager, []),
      worker(Api.ThrottlerPool, [@manager, [name: :throttlers]]),
      worker(Api.Repo, [])
    ]
    # strategies: http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    opts = [strategy: :one_for_one, name: Api.Supervisor]
    sup = Supervisor.start_link(children, opts)
    init()  # is this the right place?
    sup
  end

  def init() do
    # delete folder Mnesia.nonode@nohost? wait, no longer disk, so all good.
    # Mix.Task.run "amnesia.drop", ["-db QueueDB"]
    # Mix.Task.run "amnesia.create", ["-db QueueDB", "--disk"]
    Api.QueueStore.iterate &Api.Utils.handle_domain/1
    Api.QueueStore.iterate &IO.puts(&1)
  end

  # Tell Phoenix to update the endpoint configuration whenever the application is updated.
  def config_change(changed, _new, removed) do
    Api.Endpoint.config_change(changed, removed)
    :ok
  end
end
