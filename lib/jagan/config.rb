# Config singleton holding the configuration.
require 'singleton'

module Jagan
  class ConfigSingleton
    include Singleton
    def load(opts={})
      options.update opts
    end

    def [](key)
      options[key]
    end

    def options
      @options ||= {
        api_host: '0.0.0.0', api_port: '4567', websocket_host: '0.0.0.0',
        websocket_port: '8080', debug: false, redis_address: 'redis://0.0.0.0:6379/0'
      }
    end

    def method_missing(meth, *args, &blk)
      options[meth]
    end
  end
  
  Config = ConfigSingleton.instance
end
