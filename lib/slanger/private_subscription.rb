module Slanger
  class PrivateSubscription < Subscription
    def handle msg
      channel_id = msg['data']['channel']

      if msg['data']['auth'] && invalid_signature?(msg, channel_id)
        handle_invalid_signature msg
      else
        Subscription.new(handler).handle channel_id
      end
    end
  end
end
