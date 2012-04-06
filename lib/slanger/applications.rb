require 'singleton'

module Slanger
  class ApplicationsSingleton
    extend  Forwardable
    include Singleton
   
    def_delegators :apps, :[], :[]=

    def apps
      # In memory database of applications
      @applications ||= {}
    end
    
    def apps_by_key
      @applications_by_key ||= {}
    end

    def by_id(id)
      apps[id]
    end

    def by_key(key)
      apps_by_key[key]
    end

    def add(id, key, secret)
      app = Application.new(id, key, secret)
      apps[id] = app
      apps_by_key[app.key] = app
      Logger.info("Created application " + id)
      Logger.audit("Created application " + id)
    end
  end

  Applications = ApplicationsSingleton.instance

  if Config.mongo
    # Use mongo db to store and retrieve applications
    module ApplicationsMongoDBAspect
      include Aquarium::DSL

      around :calls_to => :by_id, :for_object => Slanger::Applications do |join_point, applicationssingleton, *args|
        # Get result
        Fiber.new do
          result = join_point.proceed
          if result.nil?
            # No result, try looking into the Database
            app_id = args[0]
            result = get(_id: app_id)
          end
          # Add to memory db
          unless result.nil?
            Applications.apps[result.id] = result
            Applications.apps_by_key[result.key] = result
          end
          result
        end.resume
      end

      around :calls_to => :by_key, :for_object => Slanger::Applications do |join_point, applicationssingleton, *args|
        # Get result
        Fiber.new do
          result = join_point.proceed
          if result.nil?
            # No result, try looking into the Database
            app_key = args[0]
            result = get(key: app_key)
          end
          # Add to memory db
          unless result.nil?
            Applications.apps[result.id] = result
            Applications.apps_by_key[result.key] = result
          end
          result
        end.resume
      end

      # Retrieve an application from the database
      def get(conditions)
        f = Fiber.current
        result = applications.find_one(conditions)
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
        doc && Application.new(doc['_id'], doc['key'], doc['secret'])
      end

      # Application collection in Mongodb
      def applications
        @applications ||= Mongo.collection("slanger.applications")
      end
      extend self
    end
  end
end


