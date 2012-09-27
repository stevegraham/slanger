# Redis class.
# Interface with Redis.

require 'forwardable'

module Slanger
  module Redis
    extend Forwardable

    def_delegator  :publisher, :publish
    def_delegators :subscriber, :on, :subscribe
    def_delegators :regular_connection, :hgetall, :hdel, :hset, :hincrby

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

    extend self

    # Dispatch messages received from Redis to their destination channel.
    on(:message) do |channel, message|
      message = JSON.parse message
      c = Channel.from message['channel']
      c.dispatch message, channel
    end
  end
end
