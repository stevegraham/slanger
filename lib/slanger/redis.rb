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
        app_id = message.delete('app_id').to_i
        # Retrieve application
        application = Application.find_by_app_id(app_id)
        unless application.nil?
          # Dispatch to application's destination channel
          c = application.channel_from_id message['channel']
          c.dispatch message, channel
        else
          raise "Application not found: " + channel.to_s + " " + message.to_s
        end
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
