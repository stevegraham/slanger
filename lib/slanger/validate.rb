module Slanger
  InvalidRequest = Class.new ArgumentError

  module Validate
    def socket_id(socket_id)
      if socket_id !~ /\A\d+\.\d+\z/
        raise InvalidRequest, "Invalid socket_id #{socket_id.inspect}"
      end

      socket_id
    end

    def channel_id(channel_id)
      if channel_id !~ /\A[\w@\-;]+\z/
        raise InvalidRequest, "Invalid channel_id #{channel_id.inspect}"
      end

      channel_id
    end

    extend self
  end
end
