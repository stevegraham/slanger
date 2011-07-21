require 'eventmachine'
require 'em-websocket'

module Slanger
  module WebSocketServer
    def run(opts)
      EM.run do
        EM::WebSocket.start opts do |ws|
          ws.onopen    { @handler = Slanger::Handler.new ws, opts[:app_key] }
          ws.onmessage { |msg| @handler.onmessage msg }
          ws.onclose   { @handler.onclose }
        end
      end
    end
    extend self
  end
end
