require 'thin'
require 'rack'

module Slanger
  module Service
    def run
      Slanger::Config[:require].each { |f| require f }
      Thin::Logging.silent = true
      Rack::Handler::Thin.run Slanger::Api::Server, Host: Slanger::Config.api_host, Port: Slanger::Config.api_port
      Slanger::WebSocketServer.run
    end

    def stop
      EM.stop if EM.reactor_running?
    end

    extend self
    Signal.trap('HUP') { Slanger::Service.stop }
  end
end
