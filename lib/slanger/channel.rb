require 'glamazon'
require 'eventmachine'
require 'forwardable'

module Slanger
  class Channel
    include Glamazon::Base
    extend  Forwardable

    def_delegators :channel, :subscribe, :unsubscribe, :push

    Slanger::Redis.on(:message) do |channel, message|
      message = JSON.parse message
      find_or_create_by_channel_id(message['channel']).dispatch message, channel
    end

    def initialize(attrs)
      super
      Slanger::Redis.subscribe channel_id
    end

    def channel
      @channel ||= EM::Channel.new
    end

    def dispatch(message, channel)
      push message.to_json
    end
  end
end
