use Mix.Config

# For development, we disable any cache and enable
# debugging and code reloading.
#
# The watchers configuration can be used to run external
# watchers to your application. For example, we use it
# with brunch.io to recompile .js and .css sources.
config :api, Api.Endpoint,
  http: [port: System.get_env("PORT") || 8080],
  debug_errors: true,
  # cache_static_lookup: false,
  # watchers: [node: ["node_modules/brunch/bin/brunch", "watch"]],
  code_reloader: true

# Watch static and templates for browser reloading.
# config :api, Api.Endpoint,
#   live_reload: [
#     patterns: [
#       ~r{priv/static/.*(js|css|png|jpeg|jpg|gif)$},
#       ~r{web/views/.*(ex)$},
#       ~r{web/templates/.*(eex)$}
#     ]
#   ]

# Do not include metadata nor timestamps in development logs
config :logger, :console, format: "[$level] $message\n"

# Configure your database
config :api, Api.Repo,
  adapter: Ecto.Adapters.Postgres,
  username: "postgres",
  password: "postgres",
  database: "api_dev"
