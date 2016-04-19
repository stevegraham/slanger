# Channel class.
#
# Uses an EventMachine channel to let clients interact with the
# Pusher channel. Relay events received from Redis into the
# EM channel.
#

require 'eventmachine'
require 'forwardable'
require 'oj'

module Slanger
  class Channel
    extend  Forwardable

    def_delegators :channel, :push
    attr_reader :channel_id

    class << self
      def from channel_id
        klass = channel_id[/\Apresence-/] ? PresenceChannel : Channel

        klass.lookup(channel_id) || klass.create(channel_id: channel_id)
      end

      def lookup(channel_id)
        all.detect { |o| o.channel_id == channel_id }
      end

      def create(params = {})
        new(params).tap { |r| all << r }
      end

      def all
        @all ||= []
      end

      def unsubscribe channel_id, subscription_id
        from(channel_id).try :unsubscribe, subscription_id
      end

      def send_client_message msg
        from(msg['channel']).try :send_client_message, msg
      end
    end

    def initialize(attrs)
      @channel_id = attrs.with_indifferent_access[:channel_id]
      Slanger::Redis.subscribe channel_id
    end

    def channel
      @channel ||= EM::Channel.new
    end

    def subscribe *a, &blk
      Slanger::Redis.hincrby('channel_subscriber_count', channel_id, 1).
        callback do |value|
          Slanger::Webhook.post name: 'channel_occupied', channel: channel_id if value == 1
        end

      channel.subscribe *a, &blk
    end

    def unsubscribe *a, &blk
      Slanger::Redis.hincrby('channel_subscriber_count', channel_id, -1).
        callback do |value|
          Slanger::Webhook.post name: 'channel_vacated', channel: channel_id if value == 0
        end

      channel.unsubscribe *a, &blk
    end


    # Send a client event to the EventMachine channel.
    # Only events to channels requiring authentication (private or presence)
    # are accepted. Public channels only get events from the API.
    def send_client_message(message)
      Slanger::Redis.publish(message['channel'], Oj.dump(message, mode: :compat)) if authenticated?
    end

    # Send an event received from Redis to the EventMachine channel
    # which will send it to subscribed clients.
    def dispatch(message, channel)
      push(Oj.dump(message, mode: :compat)) unless channel =~ /\Aslanger:/

      perform_client_webhook!(message)
    end

    def authenticated?
      channel_id =~ /\Aprivate-/ || channel_id =~ /\Apresence-/
    end

    private

    def perform_client_webhook!(message)
      if (message['event'].start_with?('client-')) then

        event = message.merge({'name' => 'client_event'})
        event['data'] = Oj.dump(event['data'])

        Slanger::Webhook.post(event)
      end
    end
  end
end
