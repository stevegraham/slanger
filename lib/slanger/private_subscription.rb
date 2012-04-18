module Slanger
  class PrivateSubscription < Subscription
    def handle
      if @msg['data']['auth'] && invalid_signature?
        handle_invalid_signature
      else
        Subscription.new(connection, @msg).handle
      end
    end
  end
end
