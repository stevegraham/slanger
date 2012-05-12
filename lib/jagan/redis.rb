# Redis class.
# Interface with Redis.

require 'forwardable'
require 'singleton'

module Jagan
  class RedisSingleton
    extend Forwardable
    include Singleton

    def initialize 
      # Dispatch messages received from Redis to their destination channel.
      on(:message) do |channel, message|
        on_message(channel, message)
      end
    end

    def_delegator  :publisher, :publish
    def_delegators :subscriber, :on, :subscribe
    def_delegators :regular_connection, :hgetall, :hdel, :hset

    private

    def on_message(channel, message)
      message = JSON.parse message
      app_id = message.delete('app_id')
      # Retrieve application
      application = Applications.by_id(app_id)
      unless application.nil?
        # Dispatch to application's destination channel
        if message['channel'] =~ /^presence-/
          application.find_or_create_presence_channel(message['channel']).dispatch message, channel
        else
          application.find_or_create_channel(message['channel']).dispatch message, channel
        end
      end
    end

    def regular_connection
      @regular_connection ||= new_write_connection
    end

    def publisher
      @publisher ||= new_write_connection
    end

    def subscriber
      @subscriber ||= new_connection
    end

    def new_connection
      # Redis read only connection
      EM::Hiredis.connect Jagan::Config.redis_address
    end

    def new_write_connection
      # Redis write connection
      EM::Hiredis.connect (Jagan::Config.redis_write_address || Jagan::Config.redis_address)
    end
  end

  Redis = RedisSingleton.instance
end
