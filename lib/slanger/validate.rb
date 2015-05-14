module Slanger
  module Validate
    def socket_id(socket_id)
      if socket_id !~ /\A\d+\.\d+\z/
        raise ArgumentError, "Invalid socket_id #{socket_id.inspect}"
      end
    end

    def channel_name(name)
      if name !~ /\A[\w@\-;]+\z/
        raise ArgumentError, "Invalid channel #{name.inspect}"
      end
    end

    extend self
  end
end
