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

    def_delegators :channel, :subscribe, :unsubscribe, :push

    def initialize(attrs)
      super
      # Subscribe to the redis channel, prefixed by the app_id so that two
      # applications don't get each other's messages.
      Slanger::Redis.subscribe application.id + ":" + channel_id
      Logger.debug log_message("app_id: " + application.id + " Subscribed to Redis channel: " + channel_id)
    end

    def channel
      @channel ||= EM::Channel.new
    end

    # Send a client event to the EventMachine channel.
    # Only events to channels requiring authentication (private or presence)
    # are accepted. Public channels only get events from the API.
    def send_client_message(message)
      push message.to_json if authenticated?
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
      end
    end

    def authenticated?
      channel_id =~ /^private-/ || channel_id =~ /^presence-/
    end

    def log_message(msg)
      msg + " app_id: " + application.id + " channel_id: " + channel_id
    end
  end
end
