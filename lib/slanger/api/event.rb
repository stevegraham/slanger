require 'oj'

module Slanger
  module Api
    class Event < Struct.new :name, :data, :socket_id
      def payload(channel_id)
        Oj.dump({
          event:     name,
          data:      data,
          channel:   channel_id,
          socket_id: socket_id
        }.select { |_,v| v }, mode: :compat)
      end
    end
  end
end

