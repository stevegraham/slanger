defmodule Slanger.WebSocket do
  @behaviour :cowboy_websocket_handler

  alias Slanger.Error
  alias Slanger.Protocol
  alias Slanger.Time


  defmodule State do
    defstruct [:socket_id, :timestamp]
  end

  def init(_transport, _request, _options) do
    { :upgrade, :protocol, :cowboy_websocket }
  end

  def websocket_init(_transport, request, _options) do
    { app_key,  _ } = :cowboy_req.binding :app_key,   request
    { protocol, _ } = :cowboy_req.qs_val  "protocol", request

    request
      |> start_connection(app_key, protocol)
  end

  defp start_connection(request, app_key, protocol) do
    uuid = UUID.uuid4

    case Protocol.establish_connection(app_key, protocol, uuid) do
      { :ok,    message } ->
        send self, :start
        { :ok, request, { message, uuid } }

      { :error, message } ->
        send self, :error
        { :ok, request, message }
    end
  end

  def websocket_info(:start, request, { message, uuid })  do
    { :reply, { :text, message }, request, %State{ socket_id: uuid, timestamp: Time.stamp } }
  end

  def websocket_info(:error, request, { code, message }) do
    { :reply, { :close, code, message }, request, nil }
  end

  def websocket_info({ _pid, message }, request, state) do
    { :reply, { :text, message }, request, state }
  end

  def websocket_info(_, request, state), do: { :ok, request, state }

  def websocket_handle({ :text, json }, request, state) do
    case JSEX.decode(json) do
      { :ok, data } ->
        dispatch_event(data, request, state)
      { :error, _ } ->
        { code, message } = Error.malformed_json
        { :reply, { :close, code, message }, request, nil }
    end
  end

  def dispatch_event(data, request, state) do
    dispatch_event data["event"], data, request, state
  end

  defp dispatch_event("pusher:" <> event, data, request, state) do
    case function_exported?(Protocol, event, 1) do
      true ->
        { :reply, { :text, apply(Protocol, event, [JSEX.decode!(data["data"])]) }, request, state }

      false ->
        { code, message } = Error.unknown_event
        { :reply, { :close, code, message }, request, nil }
    end
  end
end
