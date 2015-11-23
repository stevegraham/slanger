defmodule Slanger.Protocol do
  @protocol_range "5".."7"

  alias Slanger.Event
  alias Slanger.Error

  def establish_connection(app_key, protocol, uuid) when protocol in @protocol_range do
    case Application.get_env(:slanger, :app_key) do
      { :ok, ^app_key } -> { :ok,    Error.establish_connection uuid }
      _                 -> { :error, Error.unknown_application  }
    end
  end

  def establish_connection(_app_key, nil) do
    { :error, Error.missing_protocol }
  end

  def establish_connection(_app_key, _protocol) do
    { :error, Error.unsupported_protocol }
  end

  def ping(_data), do: Event.pong


  def subscribe(data) do
    Channel.subscribe data["channel"]
  end

  def unsubscribe(data) do
    Channel.unsubscribe data["channel"]
  end
end
