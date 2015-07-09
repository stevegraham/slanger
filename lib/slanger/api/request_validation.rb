require 'oj'

module Slanger
  module Api
    class RequestValidation < Struct.new :raw_body, :raw_params, :path_info
      def initialize(*args)
        super(*args)

        validate!
        authenticate!
        parse_body!
      end

      def data
        @data ||= Oj.load(body["data"] || params["data"])
      end

      def body
        @body ||= validate_body!
      end

      def auth_params
        params.except('channel_id', 'app_id')
      end

      def socket_id
        @socket_id ||= determine_valid_socket_id
      end

      def params
        @params ||= validate_raw_params!
      end

      def channels
        @channels ||= Array(body["channels"] || params["channels"])
      end

      private

      def validate_body!
        @body ||= assert_valid_json!(raw_body.tap{ |s| s.force_encoding('utf-8')})
      end

      def validate!
        raise InvalidRequest.new "no body"        unless raw_body.present?
        raise InvalidRequest.new "invalid params" unless raw_params.is_a? Hash
        raise InvalidRequest.new "invalid path"   unless path_info.is_a? String

        determine_valid_socket_id
        channels.each{|id| validate_channel_id!(id)}
      end

      def validate_socket_id!(socket_id)
        validate_with_regex!(/\A\d+\.\d+\z/, socket_id, "socket_id")
      end

      def validate_channel_id!(channel_id)
        validate_with_regex!(/\A[\w@\-;_.=,]{1,164}\z/, channel_id, "channel_id")
      end

      def validate_with_regex!(regex, value, name)
        raise InvalidRequest, "Invalid #{name} #{value.inspect}" unless value =~ regex

        value
      end

      def validate_raw_params!
        restricted =  user_params.slice "body_md5", "auth_version", "auth_key", "auth_timestamp", "auth_signature", "app_id"

        invalid_keys = restricted.keys - user_params.keys

        if invalid_keys.any?
          raise Slanger::InvalidRequest.new "Invalid params: #{invalid_keys}"
        end

        restricted
      end

      def authenticate!
        # Raises Signature::AuthenticationError if request does not authenticate.
        Signature::Request.new('POST', path_info, auth_params).
          authenticate { |key| Signature::Token.new key, Slanger::Config.secret }
      end

      def parse_body!
        assert_valid_json!(raw_body)
      end

      def assert_valid_json!(string)
        Oj.load(string)
      rescue Oj::ParserError
        raise Slanger::InvalidRequest.new("Invalid request body: #{raw_body}")
      end

      def determine_valid_socket_id
        return validate_socket_id!(body["socket_id"])   if body["socket_id"]
        return validate_socket_id!(params["socket_id"]) if params["socket_id"]
      end

      def user_params
        raw_params.reject{|k,_| %w(splat captures).include?(k)}
      end
    end
  end
end
