defmodule Slanger.Event do
  def connection_established(uuid) do
    encode "pusher:connection_established", %{ socket_id: uuid, activity_timeout: 120 }
  end

  def subscription_succeeded("presence-" <> channel, subscribers) do
    encode "presence-" <> channel, "pusher_internal:subscription_succeeded",
      %{ ids: Map.keys(subscribers), hash: subscribers, count: Enum.count(subscribers) }
  end

  def subscription_succeeded(channel) do
    encode channel, "pusher_internal:subscription_succeeded", nil
  end

  def pong do
    encode "pusher:pong", %{}
  end

  defp encode(event, data) do
    JSEX.encode! %{ event: event, data: JSEX.encode!(data) }
  end

  defp encode(channel, event, data) do
    JSEX.encode! %{ channel: channel, event: event, data: JSEX.encode!(data) }
  end


end
