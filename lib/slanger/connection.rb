module Slanger
  class Connection
    attr_accessor :socket, :socket_id

    def initialize socket, socket_id=nil
      @socket, @socket_id = socket, socket_id
    end

    def send_message m
      msg = JSON.parse m
      s = msg.delete 'socket_id'
      socket.send msg.to_json unless s == socket_id
    end

    def send_payload *args
      socket.send format(*args)
    end

    def error e
      begin
        send_payload nil, 'pusher:error', e
      rescue EventMachine::WebSocket::WebSocketError
        # Raised if connecection already closed. Only seen with Thor load testing tool
      end
    end

    def establish
      @socket_id = "%d.%d" % [Process.pid, SecureRandom.random_number(10 ** 6)]
      send_payload nil, 'pusher:connection_established', {
        socket_id: @socket_id,
        activity_timeout: Slanger::Config.activity_timeout
      }
    end

    private

    def format(channel_id, event_name, payload = {})
      body = { event: event_name, data: payload.to_json }
      body[:channel] = channel_id if channel_id
      body.to_json
    end
  end
end
