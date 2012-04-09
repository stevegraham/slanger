module Slanger
  class Application
    attr_accessor :id, :key, :secret, :channels

    def initialize(id, key, secret)
      @id = id
      @key = key
      @secret = secret
      @channels = {}
    end

    def find_presence_channel(channel_id)
      find_channel(channel_id)
    end

    def find_channel(channel_id, channel_class=Channel)
      channels[channel_id] 
    end

    def find_or_create_presence_channel(channel_id)
      find_or_create_channel(channel_id, PresenceChannel)
    end

    def find_or_create_channel(channel_id, channel_class=Channel)
      if not channels.has_key?(channel_id)
        channels[channel_id] = channel_class.new application: self, channel_id: channel_id
        Logger.debug("app_id: " + @id + ". Created channel: " + channel_id)
        Logger.audit("Created channel " + channel_id + " in app " + @id)
      end      
      find_channel(channel_id)
    end   

    def to_json
      # Do not serialize channels, or we risk an infinite recusion
      {id: id, key: key, secret: secret}.to_json
    end
  end
end
