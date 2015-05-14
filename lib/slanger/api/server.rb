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

      # Respond with HTTP 401 Unauthorized if request cannot be authenticated.
      error(Signature::AuthenticationError) { |e| halt 401, "401 UNAUTHORIZED: #{e}" }

      before do
        validate_request!
      end

      post '/apps/:app_id/events' do
        socket_id = validated_request.socket_id
        data = validated_request.data

        # Event and channel data are now serialized in the JSON data
        # So, extract and use it
        # Send event to each channel
        data["channels"].each { |channel| publish(channel, data['name'], data['data'], socket_id) }

        status 202
        return {}.to_json
      end

      post '/apps/:app_id/channels/:channel_id/events' do
        params = validated_request.params

        publish(params[:channel_id], params['name'],  request_body)

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

      def payload(channel, event, data, socket_id)
        {
          event:     event,
          data:      data,
          channel:   channel,
          socket_id: socket_id
        }.select { |_,v| v }.to_json
      end


      def publish(channel, event, data, socket_id)
        Slanger::Redis.publish(channel, payload(channel, event, data, socket_id))
      end
    end
  end
end
