defmodule Api.Router do
  use Phoenix.Router

  # pipeline :browser do
  #   plug :accepts, ["html"]
  #   plug :fetch_session
  #   plug :fetch_flash
  #   plug :protect_from_forgery
  # end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", Api do
    # pipe_through :browser # Use the default browser stack
    pipe_through :api

    get "/", PageController, :index
  end
end
