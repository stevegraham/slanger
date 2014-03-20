# Config singleton holding the configuration.

module Slanger
  module Config
    def load(opts={})
      options.update opts
    end

    def [](key)
      options[key]
    end

    def options
      @options ||= {
        api_host: '0.0.0.0', api_port: '4567', websocket_host: '0.0.0.0',
        websocket_port: '8080', debug: false, redis_address: 'redis://0.0.0.0:6379/0',
        socket_handler: Slanger::Handler, require: [], activity_timeout: 120
      }
    end

    def method_missing(meth, *args, &blk)
      options[meth]
    end

    extend self
  end
end
