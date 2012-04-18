module Slanger
  class Subscription
    attr_accessor :connection, :socket

    def initialize socket, socket_id, msg
      @connection = Connection.new socket, socket_id
      @msg       = msg
    end

    def handle
      connection.send_payload channel_id, 'pusher_internal:subscription_succeeded'

      channel.subscribe { |m| send_message m }
    end

    private

    def send_message m
      msg = JSON.parse(m)
      s = msg.delete 'socket_id'
      connection.socket.send msg.to_json unless s == connection.socket_id
    end

    def channel
      Channel.from channel_id
    end

    def channel_id
      @msg['data']['channel']
    end

    def token(channel_id, params=nil)
      string_to_sign = [connection.socket_id, channel_id, params].compact.join ':'
      HMAC::SHA256.hexdigest(Slanger::Config.secret, string_to_sign)
    end

    def invalid_signature?
      token(channel_id, @msg['data']['channel_data']) != @msg['data']['auth'].split(':')[1]
    end

    def handle_invalid_signature
      message = "Invalid signature: Expected HMAC SHA256 hex digest of "
      message << "#{connection.socket_id}:#{@msg['data']['channel']}, but got #{@msg['data']['auth']}"

      connection.error({ message: message})
    end
  end
end
