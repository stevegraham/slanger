module Slanger
  class Application

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

    def self.all()
      ApplicationImpl.all
    end

    def self.find_by_app_id(id)
      ApplicationImpl.find_by_app_id(id)
    end

    def self.find_by_key(key)
      ApplicationImpl.find_by_key(key)
    end

    def self.create_new()
      app_id = new_id
      app = ApplicationImpl.new({app_id: app_id, key: nil, secret: nil})
      app.generate_new_token!
      Logger.info "Created new application: " + app.app_id.to_s
      Logger.audit "Created new application: " + app.app_id.to_s
      app
    end

    def self.new_id()
      ApplicationImpl.new_id()
    end

    module Methods
      def to_json(options=nil)
        {app_id: app_id, key: key, secret: secret}.to_json(options)
      end

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

      def generate_new_token!()
        # Generate key and secret
        self.key = SecureRandom.uuid.gsub('-', '')
        self.secret = SecureRandom.uuid.gsub('-', '')
        self.save
        Logger.debug "Generated new token for app: " + self.app_id.to_s
        Logger.audit "Generated new token for app: " + self.app_id.to_s
        self
      end

      def post_to_webhook payload
        # Posts event to configured webhook url, if any.
        return unless webhook_url

        payload = {
          time_ms: Time.now.strftime('%s%L'), events: [payload]
        }.to_json

        digest   = OpenSSL::Digest::SHA256.new
        hmac     = OpenSSL::HMAC.hexdigest(digest, secret, payload)

        Fiber.new do
          f = Fiber.current
        
          EM::HttpRequest.new(webhook_url).
            post(body: payload, head: { "X-Pusher-Key" => app_key, "X-Pusher-Secret" => hmac }).
            callback { f.resume }
            # TODO: Exponentially backed off retries for errors
          Fiber.yield
        end.resume
      end
    end
  end
end

if Slanger::Config.mongo
  require 'lib/slanger/application_mongo'
else
  require 'lib/slanger/application_poro'
end
