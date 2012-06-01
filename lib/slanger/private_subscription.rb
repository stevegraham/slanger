module Slanger
  class PrivateSubscription < Subscription
    def subscribe
      if auth && invalid_signature?
        Logger.error log_message("channel_id: " + channel_id + " Invalid signature.")
        handle_invalid_signature
      end

      Subscription.new(@application, connection.socket, connection.socket_id, @msg).subscribe
    end
  end
end
