require 'thin'
require 'rack'
require 'singleton'

module Slanger
  class ServiceSingleton
    include Singleton

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

    Signal.trap('HUP') {
      Logger.info "HUP signal received."
      stop
    }
  end

  Service = ServiceSingleton.instance
end

