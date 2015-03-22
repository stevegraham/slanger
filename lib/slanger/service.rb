require 'thin'
require 'rack'

module Slanger
  module Service
    def run
      Slanger::Config[:require].each { |f| require f }
      Thin::Logging.silent = true

      start_api_server!
      start_websocket_server!
    end

    def start_api_server!
      graceful_start(:api) do
        Rack::Handler::Thin.run Slanger::ApiServer, Host: Slanger::Config.api_host, Port: Slanger::Config.api_port
      end
    end

    def start_websocket_server!
      graceful_start(:websocket) do
        Slanger::WebSocketServer.run
      end
    end

    def graceful_start(type)
      yield
    rescue  RuntimeError => e
      if e.message =~ /port is in use/
        graceful_exit!(type, Slanger::Config.send("#{type}_host"), Slanger::Config.send("#{type}_port"))
      end
      raise e
    end


    def graceful_exit!(type, host, port)
      $stdout.puts "Can't start #{type.to_s.capitalize} Server, #{host}:#{port} is in use\n\nPlease stop the other process or change the --#{type}_host option"

      exit -1
    end

    def stop
      EM.stop if EM.reactor_running?
    end

    extend self
    Signal.trap('HUP') { Slanger::Service.stop }
  end
end
