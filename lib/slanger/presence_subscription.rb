module Slanger
  class PresenceSubscription < Subscription
    # Validate authentication token and check channel_data. Add connection to channel subscribers if it checks out
    def handle(msg)
      channel_id = msg['data']['channel']

      if invalid_signature? msg, channel_id
        handle_invalid_signature msg

      elsif !msg['data']['channel_data']
        handle_error( {
          message: "presence-channel is a presence channel and subscription must include channel_data"
        })
      else
        channel = Slanger::PresenceChannel.find_or_create_by_channel_id(channel_id)
        callback = Proc.new {
          send_payload(channel_id, 'pusher_internal:subscription_succeeded', {
            presence: {
              count: channel.subscribers.size,
              ids:   channel.ids,
              hash:  channel.subscribers
            }
          })
        }
        # Subscribe to channel, call callback when done to send a
        # subscription_succeeded event to the client.
        channel.subscribe(msg, callback) do |msg|
          # Send channel messages to the client, unless it is the
          # sender of the event.
          msg       = JSON.parse(msg)
          s = msg.delete 'socket_id'

          socket.send msg.to_json unless s == socket_id
        end
      end
    end
  end
end
