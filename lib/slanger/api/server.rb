# encoding: utf-8
require 'sinatra/base'
require 'signature'
require 'json'
require 'active_support/core_ext/hash'
require 'eventmachine'
require 'em-hiredis'
require 'rack'
require 'fiber'
require 'rack/fiber_pool'

module Slanger
  module Api
    class Server < Sinatra::Base
      use Rack::FiberPool
      set :raise_errors, lambda { false }
      set :show_exceptions, false


      Slanger::Validate#force autoload

      # Respond with HTTP 401 Unauthorized if request cannot be authenticated.
      error(Signature::AuthenticationError) { |e| halt 401, "401 UNAUTHORIZED\n#{e}" }
      error(Slanger::InvalidRequest) { |c| halt 400, "Bad Request\n" }


      before do
        validate_request!
      end

      post '/apps/:app_id/events' do
        socket_id = validated_request.socket_id
        data = validated_request.data

        event = Slanger::Api::Event.new(data["name"], data["data"], socket_id)
        EventPublisher.publish(data["channels"], event)

        status 202
        return {}.to_json
      end

      post '/apps/:app_id/channels/:channel_id/events' do
        params = validated_request.params

        event = Event.new(params["name"], validated_request.body, validated_request.socket_id)
        EventPublisher.publish(validated_request.data["channels"], event)

        status 202
        return {}.to_json
      end

      def validate_request!
        validated_request
      end

      def validated_request
        @validated_reqest ||= RequestValidation.new(request_body, params, env["PATH_INFO"])
      end

      def request_body
        @request_body ||= request.body.read.tap{|s| s.force_encoding("utf-8")}
      end
    end
  end
end
