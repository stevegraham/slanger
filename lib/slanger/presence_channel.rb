# PresenceChannel class.
#
# Uses an EventMachine channel to let handlers interact with the
# Pusher channel. Relay events received from Redis into the
# EM channel. Keeps data on the subscribers to send it to clients.
#

require 'glamazon'
require 'eventmachine'
require 'forwardable'
require 'fiber'

module Slanger
  class PresenceChannel < Channel
    def_delegators :channel, :push

    # Send an event received from Redis to the EventMachine channel
    def dispatch(message, channel)
      if channel =~ /^slanger:/
        # Messages received from the Redis channel slanger:*  carry info on
        # subscriptions. Update our subscribers accordingly.
        update_subscribers message
      else
        push message.to_json
      end
    end

    def initialize(attrs)
      super
      # Also subscribe the slanger daemon to a Redis channel used for events concerning subscriptions.
      Slanger::Redis.subscribe 'slanger:connection_notification'
    end

    def subscribe(msg, callback, &blk)
      channel_data = JSON.parse msg['data']['channel_data']
      public_subscription_id = SecureRandom.uuid

      # Send event about the new subscription to the Redis slanger:connection_notification Channel.
      publisher = publish_connection_notification subscription_id: public_subscription_id, online: true,
        channel_data: channel_data, channel: channel_id

      # Associate the subscription data to the public id in Redis.
      roster.add public_subscription_id, channel_data

      # fuuuuuuuuuccccccck!
      publisher.callback do
        EM.next_tick do
          # The Subscription event has been sent to Redis successfully.
          # Call the provided callback.
          callback.call
          # Add the subscription to our table.
          internal_subscription_table[public_subscription_id] = channel.subscribe &blk
        end
      end

      public_subscription_id
    end

    def ids
      subscriptions.map { |_,v| v['user_id'] }
    end

    def subscribers
      Hash[subscriptions.map { |_,v| [v['user_id'], v['user_info']] }]
    end

    def unsubscribe(public_subscription_id)
      # Unsubcribe from EM::Channel
      channel.unsubscribe(internal_subscription_table.delete(public_subscription_id)) # if internal_subscription_table[public_subscription_id]

      # Remove subscription data from Redis
      roster.remove public_subscription_id

      # Notify all instances
      publish_connection_notification subscription_id: public_subscription_id,
                                      online: false,
                                      channel: channel_id
    end

    private

    def roster
      @roster ||= Roster.new channel_id
    end

    def publish_connection_notification(payload, retry_count=0)
      # Send a subscription notification to the global slanger:connection_notification
      # channel.
      Slanger::Redis.publish('slanger:connection_notification', payload.to_json).
        tap { |r| r.errback { publish_connection_notification payload, retry_count.succ unless retry_count == 5 } }
    end

    # This is the state of the presence channel across the system. kept in sync
    # with redis pubsub
    def subscriptions
      @subscriptions ||= roster.get || {}
    end

    # This is used map public subscription ids to em channel subscription ids.
    # em channel subscription ids are incremented integers, so they cannot
    # be used as keys in distributed system because they will not be unique
    def internal_subscription_table
      @internal_subscription_table ||= {}
    end

    def update_subscribers(message)
      if message['online']
        # Don't tell the channel subscriptions a new member has been added if the subscriber data
        # is already present in the subscriptions hash, i.e. multiple browser windows open.
        unless subscriptions.has_value? message['channel_data']
          push payload('pusher_internal:member_added', message['channel_data'])
        end
        subscriptions[message['subscription_id']] = message['channel_data']
      else
        # Don't tell the channel subscriptions the member has been removed if the subscriber data
        # still remains in the subscriptions hash, i.e. multiple browser windows open.
        subscriber = subscriptions.delete message['subscription_id']
        unless subscriptions.has_value? subscriber
          push payload('pusher_internal:member_removed', {
            user_id: subscriber['user_id']
          })
        end
      end
    end

    def payload(event_name, payload = {})
      { channel: channel_id, event: event_name, data: payload }.to_json
    end
  end
end
