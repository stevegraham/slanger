module Slanger
  class Payload
    attr_accessor :socket, :socket_id

    def initialize socket, socket_id=nil
      @socket, @socket_id = socket, socket_id
    end

    def send *args
    def send_message m
      msg = JSON.parse(m)
      s = msg.delete 'socket_id'
      socket.send msg.to_json unless s == socket_id
    end

      socket.send format(*args)
    end

    def establish_connection
      @socket_id = SecureRandom.uuid
      send nil, 'pusher:connection_established', { socket_id: @socket_id }
    end

    def format(channel_id, event_name, payload = {})
      { channel: channel_id, event: event_name, data: payload }.to_json
    end

    def error e
      send nil, 'pusher:error', e
    end
  end
end
