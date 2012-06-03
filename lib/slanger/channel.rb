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

    def_delegators :em_channel, :subscribe, :unsubscribe, :push

    class << self
      def from channel_id
        klass = channel_id[/^presence-/] ? PresenceChannel : Channel
        klass.find_or_create_by_channel_id channel_id
      end

      def unsubscribe channel_id, subscription_id
        from(channel_id).try :unsubscribe, subscription_id
      end

      def send_client_message msg
        from(msg['channel']).try :send_client_message, msg
      end
    end

    def initialize(attrs)
      super
      Slanger.subscribe channel_id
    end

    def em_channel
      @em_channel ||= EM::Channel.new
    end

    # Send a client event to the EventMachine channel.
    # Only events to channels requiring authentication (private or presence)
    # are accepted. Public channels only get events from the API.
    def send_client_message(message)
      Slanger.publish(message['channel'], message.to_json) if authenticated?
    end

    # Send an event received from Redis to the EventMachine channel
    # which will send it to subscribed clients.
    def dispatch(message, channel_id)
      push(message.to_json) unless channel_id =~ /^slanger:/
    end

    def authenticated?
      channel_id =~ /^private-/ || channel_id =~ /^presence-/
    end
  end
end
