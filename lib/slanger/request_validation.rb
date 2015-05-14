module Slanger
  class RequestValidation < Struct.new :body
    def socket_id
      validate_socket_id!(data["socket_id"])
    end

    def data
      @data ||= JSON.parse(body.tap{ |s| s.force_encoding('utf-8')})
    end

    private

    def validate_socket_id!(socket_id)
      unless valid_socket_id?(socket_id)
        raise Signature::AuthenticationError.new("Invalid socket_id: #{socket_id}")
      end

      socket_id
    end

    def valid_socket_id?(socket_id)
      socket_id =~ /\A[\da-fA-F]{8}\-[\da-fA-F]{4}-[\da-fA-F]{4}-[\da-fA-F]{4}-[\da-fA-F]{12}\z/
    end
  end
end
