defmodule Slanger do
  alias Slanger.API
  alias Slanger.Websocket

  def start(_type, _args) do
    Plug.Adapters.Cowboy.http API, [], dispatch: [{ :_, routeset }]
  end

  defp routeset do
    [
      { "/app/:app_key", Websocket, [] },
      { :_, Plug.Adapters.Cowboy.Handler, { API, [] } }
    ]
  end
end
