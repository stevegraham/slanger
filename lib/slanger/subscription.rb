module Slanger
  class Subscription
    attr_reader :handler

    #not too keen on all this delegation and instance_eval stuff, but as part
    #of an initial refactor to break the Handler into multiple classes I think it
    #makes sense as an intermediate step

    def initialize handler
      @handler = handler
    end

    def handle msg
      channel_id = msg['data']['channel']

      channel = Channel.from channel_id

      send_payload channel_id, 'pusher_internal:subscription_succeeded'

      # Subscribe to the channel and have the events received from it
      # sent to the client's socket.
      subscription_id = channel.subscribe do |msg|
        msg       = JSON.parse(msg)
        # Don't send the event if it was sent by the client
        s = msg.delete 'socket_id'
        socket.send msg.to_json unless s == socket_id
      end
    end
    private

    delegate :handle_error, :send_payload, to: :handler

    def socket_id
      handler.instance_eval{@socket_id}
    end

    def socket
      handler.instance_eval{@socket}
    end

    # HMAC token validation
    def token(channel_id, params=nil)
      string_to_sign = [socket_id, channel_id, params].compact.join ':'
      HMAC::SHA256.hexdigest(Slanger::Config.secret, string_to_sign)
    end

    def invalid_signature? msg, channel_id
      token(channel_id, msg['data']['channel_data']) != msg['data']['auth'].split(':')[1]
    end

    def handle_invalid_signature msg
      handle_error({ message: "Invalid signature: Expected HMAC SHA256 hex digest of #{socket_id}:#{msg['data']['channel']}, but got #{msg['data']['auth']}" })
    end
  end
end
