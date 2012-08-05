# Application class backed by Mongodb

module Slanger
  class ApplicationMongo
    include Application::Methods

    attr_reader :app_id
    attr_accessor :key
    attr_accessor :secret
    attr_accessor :webhook_url

    def initialize(attrs)
      @app_id = attrs[:app_id]
      @key = attrs[:key]
      @secret = attrs[:secret]
      @webhook_url = attrs[:webhook_url]
    end

    def save()
      f = Fiber.current
      resp = self.class.applications.safe_update(
        {'_id' => app_id},
        {'_id' => app_id, key: key, secret: secret, webhook_url: webhook_url},
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

    def destroy()
      unless self.class.applications.remove({'_id' => app_id}, {safe: true})
        # Error during removal
        Logger.error "Error when destroying application " + app_id.to_s + " in database: " + err.to_s
      end
      Logger.info "Destroyed application " + app_id.to_s
      Logger.audit "Destroyed application " + app_id.to_s
      self.class.delete_from_cache(self)
    end

    # Class methods

    def self.all
     self.find({}) 
    end

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
 
    def self.delete_from_cache(app)
      return if app.nil?
      application_cache.delete(app.app_id)
    end
    
    # Get a new unique integer id for an application
    def self.new_id
      f = Fiber.current
      # Retrieve the next id
      resp = applications_id_sequence.find_and_modify(
        query: {'_id' => "application_id"}, # Get the application_id doc representing the sequence 
        update: {'$inc' => {seq: 1}},
        new: true, # Return incremented doc
        upsert: true # create doc if absent          
      )
      resp.callback do |doc|
        f.resume doc
      end
      resp.errback do |err|
        raise *err
      end
      Fiber.yield['seq']
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
        secret: doc['secret'],
        webhook_url: doc['webhook_url']
      })
      self.cache(app)
      app
    end

    # Retrieve several applications from mongodb
    def self.find(conditions)
      f = Fiber.current
      result = self.applications.find(conditions).defer_as_a
      result.callback do |docs|
        # The applications were found
        f.resume docs
      end
      result.errback do |err|
        # Error
        Logger.error "Error when retrieving applications from database: " + err.to_s
        f.resume nil
      end
      docs = Fiber.yield
      docs.collect do |doc| 
        ApplicationMongo.new({
          app_id: doc['_id'],
          key:    doc['key'],
          secret: doc['secret'],
          webhook_url: doc['webhook_url']
        })
      end
    end

    # Application id sequence collection in Mongodb
    def self.applications_id_sequence
      @applications_id_sequence ||= Mongo.collection("slanger.sequences")
    end

    # Application collection in Mongodb
    def self.applications
      @applications ||= Mongo.collection("slanger.applications")
    end
  end
end
