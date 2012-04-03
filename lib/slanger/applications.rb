require 'singleton'

module Slanger
  class ApplicationsSingleton
    extend  Forwardable
    include Singleton
   
    def_delegators :apps, :[], :[]=

    def apps
      @applications ||= {"bob2" => Application.new("bob2", "91e1c10e7583bee5d236", "3856be38afd611bf37a7") }
    end
    
    def by_id(id)
      apps[id]
    end

    def by_key(key)
      apps.each{|k, application| return application if application.key == key}
      nil
    end

    def add(id, key, secret)
      apps[id] = Application.new(id, key, secret)
      Logger.info("Created application " + id)
      Logger.audit("Created application " + id)
    end
  end

  Applications = ApplicationsSingleton.instance
end
