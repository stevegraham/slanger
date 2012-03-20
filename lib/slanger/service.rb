require 'thin'
require 'rack'

module Slanger
  module Service
    def run
      Logger.info "Starting."
      Thin::Logging.silent = true
      Rack::Handler::Thin.run Slanger::ApiServer, Host: Slanger::Config.api_host, Port: Slanger::Config.api_port
      Slanger::WebSocketServer.run
    end

    def stop
      EM.stop if EM.reactor_running?
      Logger.info "Stopping."
    end

    extend self
    Signal.trap('HUP') {
      Logger.info "HUP signal received."
      Slanger::Service.stop
    }
  end
end
