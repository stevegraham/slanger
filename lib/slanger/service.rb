require 'thin'
require 'rack'

module Slanger
  module Service
    def run
      Logger.info "Starting."
      Slanger::Config[:require].each { |f| require f }
      # Enter cluster
      Cluster.enter
      # Start metrics
      Metrics
      # Start network services
      Thin::Logging.silent = true
      api_app = Rack::Chunked.new(Rack::ContentLength.new(Slanger::ApiServer))
      thin_server = ::Thin::Server.new(Slanger::Config.api_host, Slanger::Config.api_port, api_app)
      if Slanger::Config[:tls_options]
        # Set up SLL for the API server
        thin_server.ssl = true
        thin_server.ssl_options = Slanger::Config[:tls_options]
      end
      thin_server.start
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
      Fiber.new do
        # Leave the cluster
        Cluster.leave
        # Stop metrics cleanly
        Metrics.stop
        # Stop EM
        EM.stop if EM.reactor_running?
        Logger.info "Stopping."
      end.resume
    end

    extend self
  end
end
