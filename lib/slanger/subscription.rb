module Slanger
  class Subscription
    attr_accessor :payload, :socket

    def initialize socket, socket_id, msg
      @payload = Payload.new socket, socket_id
      @msg       = msg
    end

    def handle
      payload.send channel_id, 'pusher_internal:subscription_succeeded'

      channel.subscribe { |m| send_message m }
    end

    private

    def send_message m
      msg = JSON.parse(m)
      s = msg.delete 'socket_id'
      payload.socket.send msg.to_json unless s == payload.socket_id
    end

    def channel
      Channel.from channel_id
    end

    def channel_id
      @msg['data']['channel']
    end

    def token
      to_sign = [connection.socket_id, channel_id].compact.join ':'
      HMAC::SHA256.hexdigest(Slanger::Config.secret, to_sign)
    end

    def invalid_signature?
      token != auth.split(':')[1]
    end

    def auth
      @msg['data']['auth']
    end

    def handle_invalid_signature
      message = "Invalid signature: Expected HMAC SHA256 hex digest of "
      message << "#{payload.socket_id}:#{@msg['data']['channel']}, but got #{@msg['data']['auth']}"

      payload.error({ message: message})
    end
  end
end
