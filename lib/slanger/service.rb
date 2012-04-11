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

      # em-websocket installs its own trap handler which stop eventmachine
      # we need to install ours in next tick to be sure to use ours
      EM.next_tick do
        Signal.trap('HUP') {
          Logger.info "HUP signal received."
          stop
        }

        Signal.trap('INT') {
          Logger.info "INT signal received."
          stop
        }

        Signal.trap('TERM') {
          Logger.info "TERM signal received."
          stop
        }
      end
    end

    def stop
      EM.stop if EM.reactor_running?
      Logger.info "Stopping."
    end

  end

  Service = ServiceSingleton.instance
end

