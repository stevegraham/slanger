require 'eventmachine'
require 'em-websocket'

module Slanger
  module WebSocketServer
    def run
      case
      when EM.epoll?  then EM.epoll
      when EM.kqueue? then EM.kqueue
      end

      EM.run do
        options = {
          host:    Slanger::Config[:websocket_host],
          port:    Slanger::Config[:websocket_port],
          debug:   Slanger::Config[:debug],
          app_key: Slanger::Config[:app_key]
        }

        if Slanger::Config[:tls_options]
          options.merge! secure: true,
                         tls_options: Slanger::Config[:tls_options]
        end

        EM::WebSocket.start options do |ws|
          # Keep track of handler instance in instance of EM::Connection to ensure a unique handler instance is used per connection.
          ws.class_eval    { attr_accessor :connection_handler }
          # Delegate connection management to handler instance.
          ws.onopen        { |handshake| ws.connection_handler = Slanger::Config.socket_handler.new ws, handshake }
          ws.onmessage     { |msg| ws.connection_handler.onmessage msg }
          ws.onclose       { ws.connection_handler.onclose }
        end
      end
    end
    extend self
  end
end
