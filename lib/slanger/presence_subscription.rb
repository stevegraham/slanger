module Slanger
  class PresenceSubscription < Subscription
    def subscribe
      if invalid_signature?
        Logger.error log_message("channel_id: " + channel_id.to_s + " Invalid signature.")
        return handle_invalid_signature
      end

      unless channel_data?
        Logger.error log_message("channel_id: " + channel_id.to_s + " Missing channel_data for subscription to the presence channel.")
        return connection.error({
          message: "presence-channel is a presence channel and subscription must include channel_data"
        })
      end

      channel.subscribe(@msg, callback) { |m| connection.send_message m }
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
        Logger.debug log_message("channel_id: " + channel_id.to_s + " Sent presence information.")
      }
    end
  end
end
