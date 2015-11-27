defmodule Api.Support.Helpers do
  def launch_api do
    # set up config for serving
    endpoint_config =
      Application.get_env(:api, Api.Endpoint)
      |> Keyword.put(:server, true)
    :ok = Application.put_env(:api, Api.Endpoint, endpoint_config)

    # restart our application with serving enabled
    :ok = Application.stop(:api)
    :ok = Application.start(:api)
  end
end
