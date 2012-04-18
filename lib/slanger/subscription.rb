module Slanger
  class Subscription
    attr_accessor :connection, :socket

    delegate :send_message, to: :connection

    def self.from socket, socket_id, msg
      connection = Connection.new socket, socket_id
      new connection, msg
    end

    def initialize connection, msg
      @connection = connection
      @msg       = msg
    end

    def handle
      connection.send_payload channel_id, 'pusher_internal:subscription_succeeded'

      channel.subscribe { |m| send_message m }
    end

    private

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
      message << "#{connection.socket_id}:#{channel_id}, but got #{auth}"

      connection.error({ message: message})
    end
  end
end
