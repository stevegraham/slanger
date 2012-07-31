# Redis class.
# Interface with Redis.

require 'forwardable'

module Slanger
  module Redis
    extend Forwardable

    def self.extended base
      # Dispatch messages received from Redis to their destination channel.
      base.on(:message) do |channel, message|
        if channel == 'slanger:cluster'
          # Process cluster message
          Cluster.process_message(message)
        else
          Fiber.new do
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
          end.resume
        end
      end
    end

    def_delegator  :publisher, :publish
    def_delegators :subscriber, :on, :subscribe
    def_delegators :regular_connection, :hgetall, :hdel, :hset, :hincrby

    private

    def regular_connection
      @regular_connection ||= new_master_connection
    end

    def publisher
      @publisher ||= new_master_connection
    end

    def subscriber
      @subscriber ||= new_connection
    end

    def new_connection
      EM::Hiredis.connect Slanger::Config.redis_address
    end

    def new_master_connection
      # Redis connection for writes and publications.
      EM::Hiredis.connect (Slanger::Config.redis_master_address || Slanger::Config.redis_address)
    end

    extend self
  end
end
