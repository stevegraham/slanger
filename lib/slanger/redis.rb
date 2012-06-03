# Redis class.
# Interface with Redis.

require 'forwardable'

module Slanger
  class Redis < Slanger::Storage
    extend Forwardable

    def_delegator  :publisher, :publish
    def_delegators :subscriber, :on, :subscribe

    def read_all *args
      regular_connection.hgetall *args
    end

    def delete *args
      regular_connection.hdel *args
    end

    def set *args
      regular_connection.hset *args
    end

    private

    def regular_connection
      @regular_connection ||= new_connection
    end

    def publisher
      @publisher ||= new_connection
    end

    def subscriber
      @subscriber ||= new_connection
    end

    def new_connection
      EM::Hiredis.connect Slanger::Config.redis_address
    end
  end
end
