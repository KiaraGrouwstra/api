# Since everything in `web` is reloaded for each request the `web` directory is the perfect
# place to put anything that needs to manage state only for the duration of that request.

defmodule Api.Web do

  def view do
    quote do
      use Phoenix.View, root: "web/templates"

      # Import URL helpers from the router
      import Api.Router.Helpers

      # Import all HTML functions (forms, tags, etc)
      use Phoenix.HTML
    end
  end

  def controller do
    quote do
      use Phoenix.Controller

      # Alias the data repository as a convenience
      alias Api.Repo

      # Import URL helpers from the router
      import Api.Router.Helpers
    end
  end

  def model do
    quote do
      use Ecto.Model
    end
  end

  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end

end
