require 'eventmachine'
require 'em-websocket'
require 'singleton'

module Jagan
  class WebSocketServerSingleton
    include Singleton
    def run
      EM.run do
        EM::WebSocket.start host:  Jagan::Config[:websocket_host], port:  Jagan::Config[:websocket_port], debug: Jagan::Config[:debug] do |ws|
          # Keep track of handler instance in instance of EM::Connection to ensure a unique handler instance is used per connection.
          ws.class_eval    { attr_accessor :connection_handler }
          # Delegate connection management to handler instance.
          ws.onopen do
            Fiber.new do
              ws.connection_handler = Jagan::Handler.new ws
            end.resume
          end
          ws.onmessage do |msg|
            Fiber.new do
              ws.connection_handler.onmessage msg
            end.resume
          end
          ws.onclose do
            Fiber.new do
              ws.connection_handler.onclose
            end.resume
          end
          ws.onerror do |message|
            Logger.error("Websocket error: " + message)
          end
        end
      end
    end
  end

  WebSocketServer = WebSocketServerSingleton.instance
end
