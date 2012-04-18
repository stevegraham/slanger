module Slanger
  class PrivateSubscription < Subscription
    def subscribe
      if @msg['data']['auth'] && invalid_signature?
        handle_invalid_signature
      else
        Subscription.new(connection.socket, connection.socket_id, @msg).subscribe
      end
    end
  end
end
