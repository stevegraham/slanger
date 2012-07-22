module Slanger
  class PresenceSubscription < Subscription
    def subscribe
      return handle_invalid_signature if invalid_signature?

      unless channel_data?
        return connection.error({
          message: "presence-channel is a presence channel and subscription must include channel_data"
        })
      end

      channel.subscribe(@msg, callback) { |m| send_message m }
    end

    private

    def channel_data?
      @msg['data']['channel_data']
    end

    def callback
      Proc.new {
        connection.send_payload(channel_id, 'pusher_internal:subscription_succeeded', {
          presence: {
            count: channel.subscribers.size,
            ids:   channel.ids,
            hash:  channel.subscribers
          }
        })
      }
    end
  end
end
