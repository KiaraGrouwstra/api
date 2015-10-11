defmodule Chat.Mixfile do
  use Mix.Project

  def project do
    [app: :chat,
     version: "0.0.1",
     elixir: "~> 1.0",
     elixirc_paths: ["lib", "web"],
     compilers: [:phoenix] ++ Mix.compilers,
     deps: deps]
  end

  # Configuration for the OTP application
  #
  # Type `mix help compile.app` for more information
  def application do
    [
      mod: {Chat, []},
      applications: [:phoenix, :phoenix_html, :cowboy, :logger, :amqp, :httpotion] # , :kafka_ex, :snappy
   ]
  end

  # Specifies your project dependencies
  #
  # Type `mix help deps` for examples and options
  defp deps do
    [
     {:phoenix, ">= 1.0.0"},
     {:phoenix_html, ">= 2.1.0"},
     {:phoenix_live_reload, ">= 1.0.0", only: :dev},
     {:phoenix_ecto, ">= 1.1.0"},
     {:postgrex, ">= 0.0.0"},
     {:cowboy, ">= 1.0.0"},
    #  https://github.com/pma/amqp
     {:amqp, ">= 0.1.3"},
     {:exactor, ">= 2.2.0"},
    #  {:httpoison, ">= 0.7.2"},
     {:ibrowse, github: "cmullaparthi/ibrowse", tag: "v4.1.2"},
     {:httpotion, ">= 2.1.0"},
     {:kafka_ex, "~> 0.2.0"},
     {:snappy, git: "https://github.com/ricecake/snappy-erlang-nif", tag: "270fa36bee692c97f00c3f18a5fb81c5275b83a3"}
    ]
  end
end
