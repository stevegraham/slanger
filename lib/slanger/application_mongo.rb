# Application class backed by Mongodb

module Slanger
  class ApplicationMongo
    include Application::Methods

    attr_reader :app_id
    attr_reader :key
    attr_reader :secret

    def initialize(attrs)
      @app_id = attrs[:app_id]
      @key = attrs[:key]
      @secret = attrs[:secret]
    end

    def save()
      f = Fiber.current
      resp = self.class.applications.safe_update(
        {'_id' => app_id},
        {'_id' => app_id, key: key, secret: secret},
        {upsert: true}
      )
      resp.callback do |doc|
        f.resume doc
      end
      resp.errback do |err|
        # Error during save
        Logger.error "Error when saving application " + app_id.to_s + " to database: " + err.to_s
        f.resume nil
      end
      Fiber.yield
      self.class.cache(self)
    end

    # Class methods

    def self.find_by_app_id(app_id)
      self.application_cache[app_id] || self.get(_id: app_id)
    end

    def self.find_by_key(key)
      self.application_cache_by_key[key] || self.get(key: key)
    end

    def self.create(attrs)
      app = ApplicationMongo.new(attrs)
      app.save
      app
    end

    def self.cache(app)
      return if app.nil?
      application_cache[app.app_id] = app
      application_cache_by_key[app.key] = app
    end
    
    private

    # Keeps application in memory so that their transient
    # @channel property isn't lost
    def self.application_cache
      @application_cache ||= {}
    end
    def self.application_cache_by_key
      @application_cache_by_key ||= {}
    end

    # Retrieve an application from mongodb
    def self.get(conditions)
      f = Fiber.current
      result = self.applications.find_one(conditions)
      result.callback do |doc|
        # The application was found
        f.resume doc
      end
      result.errback do |err|
        # Error
        Logger.error "Error when retrieving application from database: " + err.to_s
        f.resume nil
      end
      doc = Fiber.yield
      app = doc && ApplicationMongo.new({
        app_id: doc['_id'],
        key:    doc['key'],
        secret: doc['secret']
      })
      self.cache(app)
      app
    end

    # Application collection in Mongodb
    def self.applications
      @applications ||= Mongo.collection("slanger.applications")
    end
  end
end

ApplicationImpl = Slanger::ApplicationMongo
