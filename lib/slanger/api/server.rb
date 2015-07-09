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
require 'oj'

module Slanger
  module Api
    class Server < Sinatra::Base
      use Rack::FiberPool
      set :raise_errors, lambda { false }
      set :show_exceptions, false

      error(Signature::AuthenticationError) { |e| halt 401, "401 UNAUTHORIZED" }
      error(Slanger::Api::InvalidRequest)   { |c| halt 400, "400 Bad Request" }

      before do
        valid_request
      end

      post '/apps/:app_id/events' do
        socket_id = valid_request.socket_id
        body = valid_request.body

        event = Slanger::Api::Event.new(body["name"], body["data"], socket_id)
        EventPublisher.publish(valid_request.channels, event)

        status 202
        return Oj.dump({}, mode: :compat)
      end

      post '/apps/:app_id/channels/:channel_id/events' do
        params = valid_request.params

        event = Event.new(params["name"], valid_request.body, valid_request.socket_id)
        EventPublisher.publish(valid_request.channels, event)

        status 202
        return Oj.dump({}, mode: :compat)
      end

      def valid_request
        @valid_request ||=
          begin
            request_body ||= request.body.read.tap{|s| s.force_encoding("utf-8")}
            RequestValidation.new(request_body, params, env["PATH_INFO"])
          end
      end
    end
  end
end
