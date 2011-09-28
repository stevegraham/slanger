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
      Slanger::Redis.subscribe channel_id
    end

    def channel
      @channel ||= EM::Channel.new
    end

    def dispatch(message, channel)
      push(message.to_json) unless channel =~ /^slanger:/
    end
  end
end
