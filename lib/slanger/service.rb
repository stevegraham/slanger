module Slanger
  module Service
    def run(opts={})
      defaults = { 
        api_host: '0.0.0.0', api_port: '4567', websocket_host: '0.0.0.0',
        websocket_port: '8080', debug: false, redis_address: 'redis://0.0.0.0:6379/0'
      }

      opts = defaults.merge opts

      Rack::Handler::Thin.run Slanger::APIServer, Host: opts[:api_host], Port: opts[:api_port]
      Slanger::WebSocketServer.run host: opts[:websocket_host], port: opts[:websocket_port],
        debug: opts[:debug], app_key: opts[:app_key]
    end

    def stop
      EM.stop if EM.reactor_running?
    end

    extend self
    Signal.trap('HUP') { Slanger::Service.stop }
  end
end