require 'glamazon'
require 'eventmachine'
require 'forwardable'

module Slanger
  class Channel
    include Glamazon::Base
    extend  Forwardable

    def_delegators :channel, :subscribe, :unsubscribe, :push

    Slanger::Redis.on(:message) { |channel, message| find_or_create_by_channel_id(channel).first.push message }

    def initialize(attrs)
      super
      Slanger::Redis.subscribe channel_id
    end

    def channel
      @channel ||= EM::Channel.new
    end    
  end
end