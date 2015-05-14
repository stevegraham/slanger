module Slanger
  module Api
    class Event < Struct.new :name, :data, :socket_id
      def payload(channel_id)
        {
          event:     name,
          data:      data,
          channel:   channel_id,
          socket_id: socket_id
        }.select { |_,v| v }.to_json
      end
    end
  end
end

