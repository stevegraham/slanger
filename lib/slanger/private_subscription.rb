module Slanger
  class PrivateSubscription < Subscription
    delegate :subscribe_channel, to: :handler

    def handle msg
      channel_id = msg['data']['channel']

      if msg['data']['auth'] && invalid_signature?(msg, channel_id)
        handle_invalid_signature msg
      else
        subscribe_channel channel_id
      end
    end
  end
end
