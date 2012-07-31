# Channel class.
#
# Uses an EventMachine channel to let clients interact with the
# Pusher channel. Relay events received from Redis into the
# EM channel.
#

require 'glamazon'
require 'eventmachine'
require 'forwardable'

module Slanger
  class Channel
    include Glamazon::Base
    extend  Forwardable

    def_delegators :channel, :push

    def initialize(attrs)
      super
      Slanger::Redis.subscribe redis_channel
      Logger.debug log_message("app_id: " + application.app_id.to_s + " Subscribed to Redis channel: " + redis_channel.to_s)
    end

    def channel
      @channel ||= EM::Channel.new
    end

    def subscribe *a, &blk
      Slanger::Redis.hincrby(redis_channel + ':channel_subscriber_count', channel_id, 1).
        callback do |value|
          application.post_to_webhook name: 'channel_occupied', channel: channel_id if value == 1
        end

      channel.subscribe *a, &blk
    end

    def unsubscribe *a, &blk
      Slanger::Redis.hincrby(redis_channel + ':channel_subscriber_count', channel_id, -1).
        callback do |value|
          application.post_to_webhook name: 'channel_vacated', channel: channel_id if value == 0
        end

      channel.unsubscribe *a, &blk
    end

    # Send a client event to the EventMachine channel.
    # Only events to channels requiring authentication (private or presence)
    # are accepted. Public channels only get events from the API.
    def send_client_message(message)
      message['app_id'] = application.app_id
      Slanger::Redis.publish(redis_channel, message.to_json) if authenticated?
      Logger.debug log_message("Sent a client message: " + message.to_s)
      Logger.audit log_message("Client message: " + message.to_s)
    end

    # Send an event received from Redis to the EventMachine channel
    # which will send it to subscribed clients.
    def dispatch(message, channel)
      unless channel =~ /^slanger:/
        push(message.to_json)
        Logger.debug log_message("Message: " + message.to_s)
        Logger.audit log_message("Message: " + message.to_s)
        Metrics.sent_message(application)
      end
    end

    def authenticated?
      channel_id =~ /^private-/ || channel_id =~ /^presence-/
    end

    def redis_channel
      # Prefixes the channel_id with the application id in Redis so that two
      # applications don't get each other's messages.
      application.app_id.to_s + ":" + channel_id
    end

    def log_message(msg)
      msg + " app_id: " + application.app_id.to_s + " channel_id: " + channel_id.to_s
    end
  end
end
