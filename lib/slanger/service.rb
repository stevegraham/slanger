require 'thin'
require 'rack'

module Slanger
  module Service
    def run
      Logger.info "Starting."
      Slanger::Config[:require].each { |f| require f }
      Thin::Logging.silent = true
      Rack::Handler::Thin.run Slanger::ApiServer, Host: Slanger::Config.api_host, Port: Slanger::Config.api_port
      Slanger::WebSocketServer.run
      # Enter cluster
      Cluster.enter
    end

    def stop
      # Leave the cluster
      Cluster.leave
      # Stop EM
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
