# Mongodb class.
# Interface with Mongodb.

#if Config.mongo
  require 'em-mongo'
  require 'forwardable'
  require 'singleton'

  module Jagan
    class MongoSingleton
      extend Forwardable
      include Singleton

      def_delegators :mongo_db, :collection_names, :collection

      private

      def mongo_db
        @mongo_db ||= new_db
      end

      def new_db
        EM::Mongo::Connection.new(Config.mongo_host, Config.mongo_port).db(Config.mongo_db)
      end
    end

    Mongo = MongoSingleton.instance
  end
#end
