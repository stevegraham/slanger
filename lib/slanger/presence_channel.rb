require 'glamazon'
require 'eventmachine'
require 'forwardable'

module Slanger
  class PresenceChannel < Channel
    def_delegators :channel, :push

    Slanger::Redis.on(:message) { |channel, message| find_or_create_by_channel_id(channel).push message }

    def subscribe(msg, &blk)
      data = JSON.parse msg['data']['channel_data']
      # Don't tell the channel subscriptions a new member has been added if the subscriber data
      # is already present in the subscriptions hash, i.e. multiple browser windows open.
      unless subscriptions.has_value? data
        push payload('pusher_internal:member_added', data)
      end
      subscription = channel.subscribe &blk
      subscriptions[subscription] = data
      subscription
    end

    def ids
      subscriptions.map { |k,v| v['user_id'] }
    end

    def subscribers
      Hash[subscriptions.map { |k,v| [v['user_id'], v['user_info']] }]
    end

    def unsubscribe(id)
      channel.unsubscribe(id)
      subscriber = subscriptions.delete(id)
      # Don't tell the channel subscriptions the member has been removed if the subscriber data
      # still remains in the subscriptions hash, i.e. multiple browser windows open.
      unless subscriptions.has_value? subscriber
        push payload('pusher_internal:member_removed', {
          user_id: subscriber['user_id']
        })
      end
    end

    private

    def subscriptions
      @subscriptions ||= {}
    end

    def payload(event_name, payload = {}, channel_name=nil)
      { channel: channel_id, event: event_name, data: payload }.to_json
    end
  end
end
