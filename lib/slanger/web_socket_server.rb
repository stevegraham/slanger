require 'eventmachine'
require 'em-websocket'

module Slanger
  module WebSocketServer
    def run
      EM.run do
        EM::WebSocket.start host:  Slanger::Config[:websocket_host], port:  Slanger::Config[:websocket_port], debug: Slanger::Config[:debug], app_key:  Slanger::Config[:app_key] do |ws|
          ws.class_eval    { attr_accessor :connection_handler }
          ws.onopen        { ws.connection_handler = Slanger::Handler.new ws, Slanger::Config.app_key }
          ws.onmessage     { |msg| ws.connection_handler.onmessage msg }
          ws.onclose       { ws.connection_handler.onclose }
        end
      end
    end
    extend self
  end
end
