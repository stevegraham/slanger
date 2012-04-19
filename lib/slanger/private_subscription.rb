module Slanger
  class PrivateSubscription < Subscription
    def subscribe
      return handle_invalid_signature if auth && invalid_signature?

      Subscription.new(connection.socket, connection.socket_id, @msg).subscribe
    end
  end
end
