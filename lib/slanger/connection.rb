module Slanger
  class Connection
    attr_accessor :socket, :socket_id

    def initialize socket, socket_id=nil
      @socket, @socket_id = socket, socket_id
    end

    def send_message m
      msg = JSON.parse(m)
      s = msg.delete 'socket_id'
      socket.send msg.to_json unless s == socket_id
    end

    def send_payload *args
      socket.send format(*args)
    end

    def establish
      @socket_id = SecureRandom.uuid
      send_payload nil, 'pusher:connection_established', { socket_id: @socket_id }
    end

    def format(channel_id, event_name, payload = {})
      { channel: channel_id, event: event_name, data: payload }.to_json
    end

    def error e
      send_payload nil, 'pusher:error', e
    end
  end
end
