module Slanger
  class Subscription
    attr_reader :handler

    #not too keen on all this delegation and instance_eval stuff, but as part
    #of an initial refactor to break the Handler into multiple classes I think it
    #makes sense as an intermediate step

    def initialize handler
      @handler = handler
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
