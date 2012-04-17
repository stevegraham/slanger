# Redis class.
# Interface with Redis.

require 'forwardable'

module Slanger
  module Redis
    extend Forwardable

    def self.extended base
      # Dispatch messages received from Redis to their destination channel.
      base.on(:message) do |channel, message|
        message = JSON.parse message
        klass = Channel.from message['channel']
        klass.find_or_create_by_channel_id(message['channel']).dispatch message, channel
      end
    end

    def_delegator  :publisher, :publish
    def_delegators :subscriber, :on, :subscribe
    def_delegators :regular_connection, :hgetall, :hdel, :hset

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
  end
end
