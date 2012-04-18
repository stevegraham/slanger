module Slanger
  class PresenceSubscription < Subscription
    def handle
      if invalid_signature?
        handle_invalid_signature

      elsif !channel_data?
        handle_error( {
          message: "presence-channel is a presence channel and subscription must include channel_data"
        })
      else
        channel.subscribe(@msg, callback) { |m| send_message m }
      end
    end

    private

    def channel_data?
      @msg['data']['channel_data']
    end

    def callback
      Proc.new {
        send_payload(channel_id, 'pusher_internal:subscription_succeeded', {
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
