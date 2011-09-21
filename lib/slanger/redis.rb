require 'forwardable'

module Slanger
  module Redis
    extend Forwardable

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
