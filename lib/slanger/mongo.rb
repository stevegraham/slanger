# Mongodb class.
# Interface with Mongodb.

require 'mongo'
require 'forwardable'

module Slanger
  module Mongo
    extend Forwardable

    def_delegators :mongo_db, :collection_names, :collection

    private

    def mongo_db
      @mongo_db ||= new_db
    end

    def new_db
      ::Mongo::Connection.new(Config.mongo_host, Config.mongo_port).db(Config.mongo_db)
    end

    extend self
  end
end
