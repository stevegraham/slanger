require 'forwardable'

module Slanger
  module Redis
    extend Forwardable

    def self.extended base
      base.on(:message) do |channel, message|
        message = JSON.parse message
        const = message['channel'] =~ /^presence-/ ? 'PresenceChannel' : 'Channel'
        Slanger.const_get(const).find_or_create_by_channel_id(message['channel']).dispatch message, channel
      end
    end

    def_delegator  :publisher, :publish
    def_delegators :subscriber, :on, :subscribe

    private
    def publisher
      @publisher ||= EM::Hiredis.connect
    end

    def subscriber
      @subscriber ||= EM::Hiredis.connect
    end

    extend self
  end
end
