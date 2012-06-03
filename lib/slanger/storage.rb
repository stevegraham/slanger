module Slanger
  class Storage
    extend Forwardable

    def backend
      Slanger.storage
    end

    def_delegators :backend, :on, :read_all, :delete, :set, :publish, :subscribe

    def initialize
      on(:message) do |channel, message|
        message = JSON.parse message
        c = Channel.from message['channel']
        c.dispatch message, channel
      end
    end
  end
end
