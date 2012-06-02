module Slanger
  class Application

    def channels
      @channels ||= {}
    end

    def channel_from_id(channel_id)
      if channels[channel_id].nil?
        klass = channel_id[/^presence-/] ? PresenceChannel : Channel
        channels[channel_id] = klass.new({
          application: self,
          channel_id: channel_id
        })
        Logger.debug("app_id: " + app_id.to_s + ". Created channel: " + channel_id.to_s)
        Logger.audit("Created channel " + channel_id.to_s + " in app " + app_id.to_s)
      end
      channels[channel_id]
    end

    def self.create(attrs)
      if (attrs.keys.sort <=> [:app_id, :key, :secret]) != 0
        # Invalid arguments
        raise(ArgumentError, "Hash must contain only :app_id, :key and :secret. Hash was: " + attrs.to_s)
      end
      app = ApplicationImpl.create(attrs)
      Logger.info("Created application " + app.app_id.to_s)
      Logger.audit("Created application " + app.app_id.to_s)
      app
    end

    # Try calling missing methods on the implementation class
    def self.method_missing(method_name, *args, &block)
      ApplicationImpl.send(method_name, *args, &block)
    end
  end
end

require 'lib/slanger/application_poro'