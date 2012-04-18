module Slanger
  module Payload
    def self.included base
      base.class_eval do
        attr_accessor :socket, :socket_id
      end
    end

    def send_payload *args
      socket.send to_pusher_payload(*args)
    end

    def to_pusher_payload(channel_id, event_name, payload = {})
      { channel: channel_id, event: event_name, data: payload }.to_json
    end

    def handle_error(error)
      send_payload nil, 'pusher:error', error
    end
  end
end
