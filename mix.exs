defmodule Api.Mixfile do
  use Mix.Project

  def project do
    [app: :api,
     version: "0.0.1",
     elixir: ">= 1.1.0",
     elixirc_paths: ["lib", "web"],
     compilers: [:phoenix] ++ Mix.compilers,
     deps: deps]
  end

  # Configuration for the OTP application
  #
  # Type `mix help compile.app` for more information
  def application do
    [
      mod: {Api, []},
      applications: [:phoenix, :phoenix_html, :cowboy, :logger, :httpotion, :iconverl, :elins, :floki, :porcelain, :amnesia, :fun] # , :lens, :kafka_ex, :snappy, :amqp
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
    #  {:amqp, ">= 0.1.3"},
    #  {:amqp, github: "tycho01/amqp", tag: "patch-1"},
     {:exactor, ">= 2.2.0"},
    #  {:httpoison, ">= 0.7.2"},
     {:ibrowse, github: "cmullaparthi/ibrowse", tag: "v4.1.2"},
     {:httpotion, ">= 2.1.0"},
     {:iconverl, github: "edescourtis/iconverl", tag: "master"},
    #  {:lens, github: "tycho01/erl-lenses", tag: "master"},   # shortening name, hax
     {:elins, github: "tycho01/elins", tag: "master"},
     {:fun, github: "tycho01/fun", tag: "master"},
     {:floki, github: "philss/floki", tag: "master"}, # marianoguerra/qrly
     {:porcelain, ">= 2.0.0"},
     {:kafka_ex, ">= 0.2.0"},
     {:amnesia, github: "meh/amnesia", tag: "master"},
     {:snappy, github: "ricecake/snappy-erlang-nif", tag: "270fa36bee692c97f00c3f18a5fb81c5275b83a3"},
     {:websocket_client, github: "jeremyong/websocket_client", only: :test},
     {:exrm, "~> 1.0.0-rc8"}
    ]
  end
end
